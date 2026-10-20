# napi-mbt

[English](README.md)

用 MoonBit 编写原生 Node.js addon。独立原生 CLI 通过 Tree-sitter 解析源码，
校验单一类型 IR，再生成 MoonBit adapter、C glue、TypeScript 声明和独立的
CJS/ESM loader。项目仍在开发中，通过 Mooncakes 分发。

导出支持严格数值、bigint、保留 UTF-16 的字符串、拥有/借用 Buffer、嵌套
Option/Array、struct/enum、显式 class、callback，以及返回可取消 Promise 的
`async fn`。错误会终止当前调用，已有 JavaScript 异常保留原始身份。

## 从 Mooncakes 安装

安装 MoonBit 和原生 C 工具链，已验证版本和 Node 策略见[支持矩阵](docs/zh/support.md)。
构建需要 CMake、GCC/Clang，或 Visual Studio C++ Build Tools、MSBuild 和 Windows SDK。

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
napi-mbt-cli init my-addon
cd my-addon
napi-mbt-cli doctor --json
napi-mbt-cli build --release
node -e "console.log(require('./index.cjs').mbt_add(2, 3))"
```

原生 CLI 的所有命令（包括 addon 编译）均不依赖 Node/npm。
Node 用于加载 addon，pnpm 用于包安装和验证。解析器、头文件、runtime 模板和
带版本的 async 补丁均已内嵌。

开发者可 clone 仓库后执行 `moon install ./cmd/napi-mbt-cli`。
根 npm 包标记为 private，仅用于安装开发工具；用户生成的 addon 继续通过
`prepublish` 准备 npm 主包和平台二进制包。工具发布版本以 `moon.mod` 为准。

在 `pub fn` 或 `pub async fn` 上添加 `#export_name("name")`；注解决定 JS 导出名。
生成的声明包含源码文档和错误说明。详见[使用指南](docs/zh/usage.md)、
[类型](docs/zh/types.md)、[class/callback](docs/zh/classes-callbacks.md)和
[异步](docs/zh/async.md)。
六个[独立样例](examples/README.md)涵盖基础导出、结构化值、class、callback、
异步文件和 Buffer；CI 使用打包安装的 CLI 验证真实运行与 TypeScript 消费方式。

## 常用命令

```sh
napi-mbt-cli generate --check
napi-mbt-cli build --watch --verbose --output-dir "native output"
napi-mbt-cli prepublish --target win32-x64-msvc
```

`generate --check` 只检查、不写文件。`doctor` 和 `build` 共用真实 compile/link probe。
构建在隔离工作区补充配置，保留用户 flags、exports、依赖和原生输入。Watch 合并连续
变更、串行构建；失败时保留最后成功的二进制与声明。详见[构建行为](docs/zh/build.md)。

新项目默认 N-API 4，与 napi-rs 对齐，**不统一要求 Node 22 起**。
生成的 `engines.node` 按 N-API 和 loader 功能推导。主 CI 覆盖 Node 22/24/26，
另测最低版本。Bytes/BufferView 要求 N-API 7；异步宿主要求 N-API 8 和
`moonbitlang/async@0.22.4`。

CJS/ESM 默认同时启用，也可独立启用。未知配置字段、不支持的功能、不满足的 N-API
要求会报错。Loader 优先加载存在的本地构件；构件损坏时保留原始 cause。
平台包的版本和元数据必须匹配。

## 验证与分发

```sh
moon build --target native --release cmd/napi-mbt-cli
moon run --target native --release cmd/napi-mbt-cli -- build --release
pnpm install --frozen-lockfile --ignore-scripts
moon run scripts/ci-regression-test.mbtx
moon run scripts/ci-consumers.mbtx
moon run scripts/sanitizer-test.mbtx
```

发布门禁会打包、dry-run，在干净目录安装主包/平台包，再验证 CJS/ESM 和已安装的
类型声明。CLI 归档面向 Windows x64、Linux x64 glibc 和 macOS ARM64；测试不向
registry 发布。详见[工程化](docs/zh/development.md)、[实际验证记录](docs/validation.md)、
[性能](docs/zh/performance.md)和[路线图](docs/zh/roadmap.md)。

项目采用 MIT 许可证；分发归档包含 parser、Unicode、Node-API、async 和 libuv
的许可证。见 [LICENSE](LICENSE)。
