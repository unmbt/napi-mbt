# 低层 JS 与 N-API 扩展

本页面向需要手写 JavaScript 互操作的同步绑定。`NapiEnv` 不会出现在生成的 JS/TS
参数中；它只作为 MoonBit 导出函数的隐藏直接参数。

可直接运行[高级 API 示例](../../examples/advanced-api/README.md)：在仓库根目录执行
`moon install ./cmd/napi-mbt-cli`，再执行
`moon run examples/setup.mbtx examples/advanced-api ../advanced-api`。
示例启用 N-API 10，需要 Node 22.14+ 或 Node 24/26。

## 环境绑定值

```moonbit
///|
#export_name("readName")
pub fn read_name(env : NapiEnv, object : NapiObject) -> String raise {
  get_String(env, object.get(env, "name"))
}
```

JS 签名是 `readName(object: object): string`。`NapiObject`、`NapiFunction`、
`NapiArray`、`NapiValue` 和 `NapiExternal` 只能作为直接参数或返回值，不能嵌套在
owned struct、Promise、stream、worker payload 中，也不能跨 async 边界。需要长期保存
的 JS 值使用 `NapiReference`。

`NapiObject` 提供 `get`、`set`、`has`、`define_property`、`keys`、`prototype`、
`is_instance_of`；`NapiFunction` 提供 `call`、`new_instance`；`NapiArray` 提供
`new`、`length`、`get`、`set`。`napi_value_type`、`napi_strict_equal`、
`napi_global`、`napi_undefined` 用于通用值操作。HandleScope guard 必须在环境线程
关闭。

`keys` 包含原型链上的可枚举字符串键；只要自有键时使用 `napi_object_keys`。
`prototype` 当前只接受对象原型，遇到 null 原型会报错。命名属性 helper 使用 NUL
结尾的名称，含内嵌 NUL 时使用值键 API。嵌套 scope 关闭后其中的 handle 失效；
先 escape 要返回的值，并用 `errdefer` 清理错误路径，参考示例 `escapeValue`。

TypeScript 中 `NapiValue`/`NapiExternal` 是 `unknown`，`NapiObject` 是 `object`，
`NapiArray` 是 `unknown[]`。调用方用 `Buffer.isBuffer`、`instanceof` 等收窄；
需要精确对象字段声明时使用拥有型 struct，生成器不会分析低层函数体推断对象形状。

## External 与零拷贝内存

`NapiExternal::new(env, pointer)` 包装调用方管理的 `UnmanagedBuffer`，不会释放指针。
以下 helper 会持有传入 Bytes，直到 JS GC 回收：

```moonbit
let buffer = napi_external_buffer(env, bytes)
let arraybuffer = napi_external_arraybuffer(env, bytes)
let (latin1, copied) = napi_external_string_latin1(env, bytes)
```

对于 Buffer/ArrayBuffer，动态分配的 Bytes（例如 `@utf8.encode` 的结果）会共享，
JavaScript 可以修改它。静态 Bytes 字面量会先复制到可写内存。保留下来的动态 Bytes
必须按共享存储使用，不能当作不可变快照或交给后台 MoonBit 线程。需要拷贝时使用拥有型
`NapiUint8Array`、`NapiArrayBuffer` 或 `NapiDataView`。`napi_buffer_from_arraybuffer`
在 N-API 10 上创建 ArrayBuffer-backed Buffer view，并在 C 层检查 offset/length。

External string 按 Latin-1 解释每个字节，`b"caf\xe9"` 才是 `café`，不能用 UTF-8
编码冒充 Latin-1；不可通过其他别名修改字符串 backing。Node 可能复制字符串并设置
`copied`，两条路径都通过 finalizer 释放保留的引用。不允许 external buffer 的宿主
会返回错误，此时应使用拥有型包装。

[原生 token 示例](../../examples/advanced-api/native.c) 使用静态存储期指针。
`NapiExternal::new` 不会安装资源清理逻辑；instance-data helper 同样只存储调用方
管理的指针，不注册 finalizer。必须明确占用 addon 自己的槽，不能覆盖其他组件的指针
或 finalizer；堆资源需要额外设计释放责任。

`NapiDataView` 是拥有型字节快照：

```moonbit
let view = get_NapiDataView(env, input)
let output = set_NapiDataView(env, view)
```

拥有型 `NapiBigInt64Array`、`NapiBigUint64Array` 与其他 TypedArray 一样提供 `new`、
`length`、`to_array`。所有拥有型二进制转换都会拒绝 detached ArrayBuffer 和
SharedArrayBuffer backing。

## N-API 8/9/10 helper

- N-API 8：`napi_object_freeze`、`napi_object_seal`、`napi_type_tag_object`、
  `napi_check_object_type_tag`。
- N-API 6：`napi_set_instance_data`、`napi_get_instance_data`。
- N-API 9：`napi_symbol_for`、`napi_syntax_error`、`napi_throw_syntax_error`、
  `napi_module_file_name`。
- N-API 10：`napi_property_key`、`napi_external_string_latin1`、
  `napi_buffer_from_arraybuffer`。
- 运行时检查：`napi_version`、`napi_adjust_external_memory`、
  `napi_detach_arraybuffer`、`napi_is_detached_arraybuffer`。

签名类型会自动推导，但生成器不会扫描函数体中的 helper 调用。因此应在
`napi-mbt.json` 显式声明 feature，让 CLI 在生成前检查最低版本；否则不支持的 C stub
只能在调用时返回错误：

```json
{
  "napiVersion": 10,
  "features": ["external_string", "property_key", "buffer_from_arraybuffer"]
}
```

## 高层 typed TSFN

`NapiTypedThreadsafeFunction[T]` 在调用它的 MoonBit 所属线程同步运行编码器，然后把
返回的 Bytes 复制到 C-owned 队列载荷，稍后的 JS callback 收到 Buffer。
不能把该包装或编码闭包交给任意原生线程；真正的后台生产者使用[低层 C TSFN](tsfn.md)：

```moonbit
let tsfn = NapiTypedThreadsafeFunction::new(
  env,
  callback,
  32,
  fn(value : Int32) { b"payload" },
)
errdefer (ignore(tsfn.abort()) catch { _ => () })
let status = tsfn.try_call(42)
ignore(tsfn.release())
// 最后一次 release 后只处理 status，不再使用 tsfn。
ignore(status)
```

创建时已有一个 producer count，每次成功 `acquire` 都需要配对 `release`。
`abort` 停止投递并减少一个计数，不会一次清空所有 producer。release/abort 或收到
`Closing` 后，该生产者不能再次使用句柄，也不应再次 release；包装不会自动防止这些误用。

在所属线程优先用 `try_call`/`Nonblocking`；满队列上 Blocking 可能让消费线程死锁。
`Accepted` 表示已入队，不代表 JS callback 已完成；`QueueFull`/`Closing` 的重试或丢弃
策略由调用方决定，所有未入队载荷都会释放。abort/shutdown 可能以空环境清理队列，
此时只释放 C 载荷。示例 `boundedTsfn` 演示容量为一的队列在同步导出返回前变满。

## 错误与验证

所有 C status 都转换为 `NapiError`，并保留 pending JS exception 的原身份。生成器在
写出文件前拒绝嵌套或跨 async/worker 的低层句柄。完整所有权、版本门槛和测试命令见
[SDD](sdd.md)。
`moon run scripts/advanced-api-test.mbtx <cli-path>` 覆盖可运行示例、GC/worker 退出及
NodeNext/Bundler 消费者；内存检查使用
`moon run scripts/sanitizer-test.mbtx <cli-path> --fixture advanced-api`。
