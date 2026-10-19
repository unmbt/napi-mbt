# 使用指南

从仓库执行 `moon install ./cmd/napi-mbt-cli` 安装。
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

基础新工程用 N-API 4；bigint 用 6；带分离检查的 Buffer 用 7；异步导出用 8。
签名需要的 feature 会自动推导和检查。`targets` 仅限制宿主目标，不启用交叉编译。
不能同时关闭 CJS 和 ESM。[支持策略](support.md)说明 Node 最低版本和发布平台。

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
