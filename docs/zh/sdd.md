# 软件设计说明（SDD）

本文记录 `napi-mbt` 新增低层 JS 与高级 Node-API 的设计契约。根目录运行时源码
是唯一事实来源，CLI 通过 `scripts/sync-runtime.mbtx` 将其嵌入生成模板。

## 目标与边界

本次扩展有四个目标：提供通用 JavaScript 值操作；明确 External 与二进制数据的
所有权；在不改变默认 N-API 4 基线的前提下提供 N-API 8/9/10；以及让后台生产者
通过 typed TSFN 传递数据而不跨线程传递 MoonBit 对象或闭包。

生成器仍拒绝泛型导出、嵌套借用句柄、跨线程 JS 句柄，以及拥有型二进制背后的
SharedArrayBuffer。这些限制属于安全契约。

## 生成管线

```text
MoonBit 源码 + napi-mbt.json
          |
          v
语法解析 -> 类型 IR -> 全包校验
          |
   MoonBit 适配器 / C stub / C glue / TS / loader / manifest/schema
```

`NapiEnv` 只能作为直接参数。C callback 提供环境，生成的 JS/TS 参数列表隐藏它。
生成适配器先转换参数，调用 MoonBit 函数，再转换返回值；async/worker 边界使用同一
IR 校验借用类型。修改 `napi_low_level.mbt`、`napi_advanced.mbt`、
`napi_typed_tsfn.mbt`、`stub.c` 或头文件后必须运行：

```sh
moon run scripts/sync-runtime.mbtx
moon info
moon fmt
```

## 所有权与生命周期

| 表面 | 表示 | 生命周期规则 |
| --- | --- | --- |
| `NapiValue`、`NapiObject`、`NapiFunction`、`NapiArray` | 绑定环境的 JS handle | 只在创建它的同步 callback 中有效；持久化使用 `NapiReference` |
| HandleScope guard | 原生 handle scope | 必须在同一环境线程打开和关闭；只可从 escapable scope escape |
| `NapiExternal` | 调用方管理的 `UnmanagedBuffer` 指针 | N-API 保存指针，`new` 不释放裸指针 |
| external Buffer/ArrayBuffer/string | `Bytes` 加 GC finalizer | C 增加 Bytes 引用，JS 回收时恰好减少一次 |
| `NapiDataView` 与拥有型 TypedArray | MoonBit 拷贝 | 转换后不保留 JS handle/backing pointer，可跨 async/worker |
| typed TSFN payload | 含拷贝 Bytes 的 C 堆对象 | JS callback 或队列拒绝时释放 |

External Buffer/ArrayBuffer 允许 JS 修改 backing store，因此调用方必须将传入 Bytes
视为共享外部存储；需要 MoonBit 不可变语义或异步持久化时使用拥有型二进制包装。

## 通用低层 JS API

`NapiObject`、`NapiFunction`、`NapiArray` 是 `NapiValue` 的薄类型包装，提供属性读写、
属性描述符、own keys、调用、构造、原型、`instanceof`、严格相等和类型检查。同步与
escapable HandleScope 使用显式 guard，关闭责任在 MoonBit 代码中可见。

这些包装不会隐藏环境；方法调用显式接收 `NapiEnv`，便于审查线程和生命周期边界。
生成器只允许它们作为直接参数或返回值，禁止嵌入数组、map、struct、Promise、stream、
async 函数或 worker 任务。

## External 与二进制

拥有型转换在输入和输出两侧都拷贝，并校验确切 TypedArray/DataView 类型。detached
ArrayBuffer 与 SharedArrayBuffer backing 会被拒绝，因为无法安全取得快照。扩展类型
包括 `NapiBigInt64Array`、`NapiBigUint64Array` 和 `NapiDataView`。

高级 API 还提供 external Buffer/ArrayBuffer、external Latin-1 string，以及 N-API 10
ArrayBuffer-backed Buffer view。`NapiDataView` 是拥有型字节快照，与 external helper
明确分开。

## N-API 版本门槛

默认 addon 仍使用 N-API 4。`napi-mbt.json` 的 `features` 会在写文件前校验版本：

| 功能 | 最低版本 |
| --- | ---: |
| External 指针 | 1 |
| BigInt64/BigUint64、DataView、带检查的二进制 view | 7 |
| instance data | 6 |
| freeze/seal、type tag | 8 |
| `Symbol.for`、SyntaxError、module filename | 9 |
| property key、external Latin-1、ArrayBuffer-backed Buffer | 10 |
| typed TSFN | 4 |

C stub 也使用对应 `NAPI_VERSION` 条件编译。旧版本项目保持 ABI 基线；调用未启用的
高级 API 时得到明确的运行时错误。

## typed TSFN 数据流

```text
后台线程 -- encode(T) --> 拷贝的 C payload -- queue --> JS callback(Buffer)
```

`NapiTypedThreadsafeFunction[T]` 只保存原始 TSFN handle 和编码器。`call`/`try_call`
在生产者侧编码并复制 bytes，返回 `Accepted`、`QueueFull` 或 `Closing`。JS 线程
callback 创建 Buffer 并调用 JS；`acquire`、`release`、`abort` 对应 N-API producer
计数生命周期。没有 MoonBit 闭包、GC 对象或 `NapiValue` 跨线程。

## 错误和验证契约

每个 C status 都转换为 `NapiError`，并保留原有 pending JS exception。类型和范围错误
在调用业务函数前发生。生成器快照验证公开 TypeScript 表面，native consumer 覆盖
detached/shared buffer、External、TypedArray、队列状态和异步拒绝。

运行时改动至少执行：

```sh
moon check --target native --warn-list +73 --deny-warn
moon test --target native
moon run scripts/sync-runtime.mbtx --check
moon run scripts/generator-snapshot-test.mbtx <cli-path>
moon run scripts/owned-binary-test.mbtx <cli-path>
moon run scripts/sanitizer-test.mbtx <release-cli-path>
```

托管 CI 还会构建七个 native profile、Node 22/24/26、最低 Node consumer 和
Linux/Windows 内存门禁。
