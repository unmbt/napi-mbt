# 使用指南

通过 `moon install unmbt/napi-mbt/cmd/napi-mbt-cli` 从 Mooncakes 安装。
开发者在源码仓库中也可执行 `moon install ./cmd/napi-mbt-cli`。
`napi-mbt-cli --help` 和各子命令的 `--help` 列出实际接受的参数。

| 命令 | 行为 |
| --- | --- |
| `init <directory> --name <name>` | 创建工程；覆盖已有文件必须显式指定 `--force` |
| `doctor [directory] --json` | 发现并探测实际编译器、链接器和 SDK |
| `generate [directory] --check` | 解析、类型校验、检查全部生成物，不写文件 |
| `build [directory] --release` | 隔离生成和编译，成功后安装产物 |
| `build --watch --verbose --output-dir <path>` | 监听输入，输出命令/计时并指定构件目录 |
| `targets` | 列出已识别的宿主目标配置 |
| `prepublish [directory] --target <target>` | 校验发布构件，准备 npm 平台包元数据 |

不加 `--check` 时，生成器先校验整个包，再替换管理的文件。`napi-mbt.json` 使用严格
JSON，生成的 `napi-mbt.schema.json` 提供编辑器校验。例如：

```json
{
  "$schema": "./napi-mbt.schema.json",
  "napiVersion": 8,
  "builder": "auto",
  "cjs": true,
  "esm": true
}
```

基础新工程用 N-API 4；bigint 用 6；带检查的 Buffer、DataView 与 BigInt TypedArray 用 7；
异步导出用 8。低层 JS handle 与 typed TSFN 使用 N-API 4；freeze/seal、type tag 用 8；
`Symbol.for` 与 SyntaxError helper 用 9；property key、external string、
ArrayBuffer-backed Buffer view 用 10。签名需要的 feature 会自动推导和检查。
`targets` 仅限制宿主目标，不启用交叉编译。
不能同时关闭 CJS 和 ESM。[支持策略](support.md)说明 Node 最低版本和发布平台。

需要手写低层绑定时阅读[低层 JS 与高级 API](advanced-api.md)，其中说明环境注入、
`NapiObject`/`NapiFunction`/`NapiArray`、External 生命周期、拥有型 DataView/BigInt
数组、版本门槛和编码型 typed TSFN。将相应名称加入 `features` 可让 schema 在生成前
拒绝过低的 `napiVersion`。

导出放在根 MoonBit 包中，解析器跨该包源码文件解析签名和引用的值类型。
泛型导出、未解析类型及不支持的签名会带文件名、行号报错。
导出函数、值类型前的 `///` 文档进入声明和 `napi_manifest.json`；错误说明也由同一
校验后的 IR 派生。

详见[类型](types.md)、[class/callback](classes-callbacks.md)、[异步](async.md)和
[构建/watch](build.md)。[完整示例源码](../../scripts/fixtures/documented-addon.mbt.txt)
在 CI 中实际编译和运行，覆盖基础类型、Buffer、错误、对象、callback、异步。
使用 Buffer 或异步声明的 TypeScript 项目需要 `@types/node`；声明会显式引用它。

本地通过 `require('./index.cjs')` 或 `import addon from './index.mjs'` 加载；
安装后使用包名。存在的本地二进制优先，损坏时不会悄悄回退。
Loader 错误包含目标、尝试路径、N-API 要求和原始 cause；平台包名称、版本、目标、
N-API 元数据必须匹配。

生成器管理根入口、engines 和自己的发布文件，保留其他元数据、scripts、依赖及
export 子路径。构建保留用户的 MoonBit manifests、原生 stubs、flags 和链接库。
准备分发包前请阅读[工程化与发布验收](development.md)。

工程文本必须使用 UTF-8。非法文本报告具体文件路径，文件不存在等 I/O 错误保留原始原因。
生成文件显式写为 UTF-8；外部编译器诊断允许包含非 UTF-8 字节，避免 Windows 代码页输出
中断已经成功的构建。

## 按场景选择并运行示例

[示例目录](../../examples/README.md) 提供十个独立 addon。试用当前源码新增能力时，
先安装本地 CLI，再复制到一个新目录；setup 本身会构建并运行一次 JS 测试：

```sh
moon install ./cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/structured-data ../structured-demo
cd ../structured-demo
pnpm test
```

前两条命令在本仓库根目录执行，目标目录必须尚不存在；运行全套示例推荐
Node 22.14+ 或 Node 24/26（高级示例需要 N-API 10）。替换示例名即可切换场景：

| 需求 | 示例与说明 |
| --- | --- |
| 标量参数、CJS/ESM 加载 | [hello-addon](../../examples/hello-addon/README.md) |
| 可选字段、enum、Map/JSON/元组、Date/Set/Symbol/同步迭代器 | [structured-data](../../examples/structured-data/README.md)、[类型契约](types.md) |
| 持久原生状态与显式释放 | [native-class](../../examples/native-class/README.md)、[class 文档](classes-callbacks.md) |
| 调 JS、保存回调、返回可释放闭包 | [callbacks](../../examples/callbacks/README.md) |
| 异步 I/O、取消与传入 JS Promise | [async-file](../../examples/async-file/README.md)、[Promise 生命周期](js-promises.md) |
| 二进制复制或同步借用 Buffer | [binary-processing](../../examples/binary-processing/README.md) |
| C 线程计算或隔离进程执行 MoonBit CPU 任务 | [native-tasks](../../examples/native-tasks/README.md)、[worker-tasks](../../examples/worker-tasks/README.md) |
| AsyncIterable/Web stream 与背压 | [streams](../../examples/streams/README.md) |
| 低层 handle、External、DataView/BigInt、高级版本、typed 队列 | [advanced-api](../../examples/advanced-api/README.md)、[所有权指南](advanced-api.md) |
| 真正的原生线程 TSFN 生产者 | [TSFN 指南与 C fixture](tsfn.md) |

每个项目有 `lib.mbt`、`test.mjs`（实际调用和错误边界）和 `consumer.mts`（TS 正反例）。
`consumer.mts` 含 `@ts-expect-error` 保护的故意错误调用，只用于类型检查，不要当 JS
执行。在仓库中运行 `moon run scripts/examples-test.mbtx`，会用临时打包安装的 CLI
构建全部示例，并分别检查 NodeNext、Bundler 类型声明。

需要精确 TS 对象形状或独立数据时选拥有型 struct/Map/TypedArray；`NapiBufferView`
只在一个同步调用中有效。External 的动态 Bytes 与 JS 共享内存；低层 handle 必须
留在所属环境线程。typed TSFN 从 MoonBit 所属线程编码入队，原生生产者使用低层 C API。
这些边界都有对应示例，不应从 `unknown` 返回类型推断其所有权。
