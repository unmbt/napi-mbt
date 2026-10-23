<div align="center">

[English](README.md) | [简体中文](README.zh.md)

# ⚡ napi-mbt

*面向 MoonBit 的原生 Node-API (N-API) 工具链、绑定生成器与异步运行时*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-f97316?style=flat-square)](https://www.moonbitlang.com/)
[![Mooncakes](https://img.shields.io/badge/mooncakes.io-unmbt%2Fnapi--mbt-7c3aed?style=flat-square)](https://mooncakes.io/docs/unmbt/napi-mbt)
[![CI](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml/badge.svg?branch=master)](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square)](docs/zh/support.md)
[![Node-API](https://img.shields.io/badge/ABI-Node--API%20v4--v8-339933?style=flat-square)](docs/zh/support.md)

</div>

---

## 📖 项目简介

**`napi-mbt`** 是一套面向 [MoonBit](https://www.moonbitlang.com/) 的端到端原生 Node-API（N-API）工具链与运行时库，可将 MoonBit 原生包（`preferred_target = "native"`）直接编译为 ABI 稳定的 Node.js `.node` 原生扩展。

你无需手写繁琐的 C/C++ 胶水代码，`napi-mbt` 内置了基于 Tree-sitter 的 MoonBit 语法分析器，能够自动为你完成：

- **生成原生 Node-API C 胶水层**：内置严格的边界参数校验与确定性的资源生命周期管理
- **编译 `.node` 原生动态库**：驱动 `moon build --target native` 与 CMake，调用宿主 C 编译器（MSVC / GCC / Clang）完成构建
- **生成双模式 JS 加载器**：同时产出 CommonJS（`index.cjs`）与 ES Module（`index.mjs`）入口
- **生成严格 TypeScript 类型声明**：自动输出与 MoonBit 函数签名和类型定义一一对应的 `index.d.ts`
- **生成跨平台 npm 发布清单**：支持按平台拆分的 `optionalDependencies` 预编译二进制包结构

更重要的是，**`napi-mbt-cli` 本身是一个零 Node.js / npm 依赖的独立原生可执行程序**。你可以通过 Mooncakes（`moon install`）或 GitHub Releases 直接安装并运行它。

---

## ✨ 核心亮点

| 核心能力 | 特性说明 |
| :--- | :--- |
| 🎯 **零样板代码导出** | 直接分析 MoonBit 源码中的 `pub fn`、`pub async fn`、`pub struct` 与 `pub enum` 并生成绑定；仅具状态的原生类需要显式添加 `// napi:class` 标记。 |
| 🛡️ **严格边界校验** | 在进入 MoonBit 逻辑前的 C 边界层直接拦截 `NaN`、`±Infinity`、传给整数参数的小数、超出 32/64 位范围的数值以及非法 UTF-16 / Buffer 输入。 |
| ⚡ **全栈异步与并发能力** | 原生支持可取消的 `pub async fn` Promise（基于 `moonbitlang/async@0.22.4` + libuv）、C 线程池任务（`NapiTask`）、隔离的 MoonBit 进程池（`NapiWorker`）、等待 JS Promise（`NapiJsPromise`）以及按需拉取的异步流（`NapiAsyncIterator`）。 |
| 🧱 **安全的原生类与回调** | 原生类（`NapiClass[T]`）支持构造函数、静态工厂、读写属性、实例方法以及显式 `.dispose()` / `Symbol.dispose`；回调函数（`NapiCallback`）同时支持同步借用调用与跨线程安全持久化（Threadsafe Function）。 |
| 🔒 **非侵入式隔离构建** | 所有中间产物均在 `.napi-mbt/build/` 隔离目录中合成与编译，绝不污染用户源码树；内置内容哈希增量缓存、`watch` 监听模式与原生符号冲突检查（`nm` / `dumpbin`）。 |
| 📦 **精准 ABI 与引擎范围** | 默认面向 **N-API v4**，仅在使用 `BigInt`、`Bytes`/`BufferView` 或异步运行时等高阶特性时按需提升至对应 N-API 版本（最高 v8），并自动计算精确的 `package.json` `engines.node` 范围。 |

---

## 🖥️ 平台与 Node.js 支持矩阵

### 原生宿主构建目标

`napi-mbt` 支持在当前宿主架构与 C 运行时下直接构建原生扩展：

| 操作系统 | 架构 | C 运行时 / 编译工具链 | 平台包三元组 (Platform Triple) |
| :--- | :--- | :--- | :--- |
| **Windows** | `x64` | MSVC（`cl` / MSBuild + Windows SDK） | `win32-x64-msvc` |
| **Linux** | `x64`, `arm64` | `glibc`（`gcc` / `clang`） | `linux-x64-gnu`, `linux-arm64-gnu` |
| **Linux** | `x64`, `arm64` | `musl`（Alpine 原生工具链） | `linux-x64-musl`, `linux-arm64-musl` |
| **macOS** | `x64`, `arm64` | Apple Clang（Xcode / Command Line Tools） | `darwin-x64`, `darwin-arm64` |

> [!NOTE]
> 为保证二进制可靠性，CLI 默认要求在匹配的宿主工具链上构建，拒绝跨架构伪交叉编译。在 Linux（`gnu` 与 `musl`）平台上，CLI 会在安装产物前以及 `prepublish` 阶段自动校验编译器探针与 `.node` ELF 动态依赖（`PT_INTERP` / `DT_NEEDED`）。详见 [支持策略](docs/zh/support.md) 与 [平台验证](docs/platforms.md)。

### Node-API 特性最低要求

| 特性表面 | 最低 N-API | 最低 Node.js 消费端基线 |
| :--- | :---: | :--- |
| 标量（`Int`、`UInt`、`Double`、`Bool`）、UTF-16 `String`、拥有所有权的 `struct` / `enum` / `Array` / `Map` | **1** | Node 10.16.0 (CJS) / 12.20.0 (CJS+ESM 双模式) |
| 原生类（`NapiClass`）与回调生命周期管理 | **3** | Node 10.16.0 (CJS) / 12.20.0 (CJS+ESM 双模式) |
| 持久化 / 线程安全回调（`NapiCallback`，新项目默认基线） | **4** | `>=12.20.0 <13 \|\| >=14.13.1`（双模式默认范围） |
| 精确 64 位整数 `Int64` / `UInt64`（`bigint`） | **6** | Node 10.7.0+（与加载器要求取交集） |
| `Bytes`（`Buffer`）与同步零拷贝借用 `NapiBufferView` | **7** | Node 10.16.0+（与加载器要求取交集） |
| `pub async fn`、`NapiTask`、`NapiJsPromise`、`NapiAsyncIterator` 与异步宿主清理 | **8** | `>=12.22.0 <13 \|\| >=14.17.0 <15 \|\| >=15.12.0 <16 \|\| >=16.0.0` |
| Web `ReadableStream` 辅助包装器（`*Stream`） | **8** | **Node 18.0.0+** |

仓库 CI 持续在 **Node 22、24、26** 以及最低兼容版本消费端上运行完整门禁，并包含 Windows 与 Linux 原生内存泄漏检查。

---

## 📦 快速开始

### 1. 安装 CLI

使用 MoonBit 工具链从 [Mooncakes](https://mooncakes.io/docs/unmbt/napi-mbt) 直接安装 `napi-mbt-cli`：

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
```

安装完成后，可执行文件位于 `~/.moon/bin/napi-mbt-cli`（Windows 下为 `%USERPROFILE%\.moon\bin\napi-mbt-cli.exe`）。你也可以从 [GitHub Releases](https://github.com/unmbt/napi-mbt/releases) 下载包含 `SHA256SUMS.txt` 与构建溯源证明的预编译压缩包。

随时运行 `doctor` 检查本地 MoonBit、CMake 与宿主 C 编译器环境：

```bash
napi-mbt-cli doctor
```

### 2. 初始化并构建新扩展

```bash
napi-mbt-cli init my-addon
cd my-addon
moon update
moon check
napi-mbt-cli check
napi-mbt-cli build
```

新生成的项目会在 `moon.mod` 中声明 `"preferred_target": "native"` 并依赖 `unmbt/napi-mbt`，默认目标为 **N-API 4** 且同时开启 CommonJS 与 ESM 加载器。

### 3. 编写 MoonBit 并在 JS / TS 中调用

在 `lib.mbt` 中编写导出类型与函数：

```moonbit
///|
pub struct Summary {
  label : String
  total : Int
}

///|
pub fn summarize(label : String, values : Array[Int]) -> Summary raise {
  if label.is_empty() {
    raise @napi.NapiError::invalid_arg(
      message="label must not be empty",
      code="EMPTY_LABEL",
    )
  }
  let mut total = 0
  for v in values {
    total += v
  }
  { label, total }
}
```

执行 `napi-mbt-cli build` 后，即可在 ES Module、CommonJS 或 TypeScript 中直接调用：

```js
import { summarize } from './index.mjs';
// 或 CommonJS: const { summarize } = require('./index.cjs');

console.log(summarize('orders', [10, 20, 30]));
// => { label: 'orders', total: 60 }
```

---

## 🧬 类型系统与运行时能力

`napi-mbt` 在 MoonBit 与 Node.js 之间提供严格、可预测的类型映射：

| MoonBit 类型 | JavaScript / TypeScript | 语义与边界保证 |
| :--- | :--- | :--- |
| `Int`, `UInt` | `number` | 严格校验 32 位有符号（`[-2^31, 2^31 - 1]`）与无符号（`[0, 2^32 - 1]`）整数；拒绝 `NaN`、`±Infinity` 与小数。 |
| `Int64`, `UInt64` | `bigint` | 严格校验 64 位有符号/无符号 `BigInt`（`N-API 6`）；拒绝超出 64 位表示范围的值。 |
| `Double`, `Bool`, `Unit` | `number`, `boolean`, `void` | `Double` 要求有限 IEEE-754 浮点数（拒绝 `NaN` 与 `±Infinity`）。 |
| `String` | `string` | 直接在 UTF-16 字符串之间桥接，避免多余的 UTF-8 中间转码。 |
| `Bytes` | `Buffer` | 跨边界拥有所有权的字节拷贝（`N-API 7`），可安全持久化或在异步函数中返回。 |
| `@napi.NapiBufferView` | `Buffer \| Uint8Array` | 零拷贝同步只读借用（`N-API 7`），仅在当前同步调用栈帧内有效。 |
| `@napi.NapiUint8Array` / `NapiInt32Array` / `NapiFloat64Array` / `NapiArrayBuffer` | `Uint8Array` / `Int32Array` / `Float64Array` / `ArrayBuffer` | 拥有所有权的 TypedArray 与 `ArrayBuffer` 拷贝，完整保留元素长度。 |
| `T?`, `Array[T]`, `Map[String, T]`, `(A, B, ...)`, `Json` | `T \| null`, `Array<T>`, `Record<string, T>`, `[A, B, ...]`, `JsonValue` | 递归结构化校验；`Option::None` 输出为 `null`（输入同时接受 `null` 或 `undefined`）。 |
| `pub struct` / `pub enum` | Object / 判别联合类型 | 结构体映射为强类型 JS 对象；枚举映射为 `{ tag: "Variant", ... }` 判别联合。 |
| `// napi:class` + `@napi.NapiClass[T]` | 带 `dispose()` 与 `[Symbol.dispose]()` 的 `class` | 原生对象句柄封装，支持构造函数、静态工厂、属性读写、实例方法与确定性释放。 |
| `@napi.NapiCallback[Args, Ret]` | `(...args) => Ret` | 支持同步调用期借用以及通过 `.clone()` 持久化的线程安全函数（`N-API 4`）。 |
| `pub async fn(...) -> T raise` | `Promise<T>`（支持 `.cancel()` 与 `{ signal }`） | 运行于内嵌的 `moonbitlang/async@0.22.4` + libuv 事件循环桥接层（`N-API 8`），支持协作式取消。 |
| `@napi.NapiJsPromise[T]` | `Promise<T> \| PromiseLike<T>` | 在 MoonBit `async fn` 中直接等待 JavaScript Promise 或 thenable 并校验返回值类型。 |
| `@napi.NapiAsyncIterator[T]` | `AsyncIterableIterator<T>` 与 `ReadableStream<T>` | 按需驱动的异步流输入与输出，支持背压控制与消费端提前终止（`return()`）。 |
| `@napi.NapiTask` / `@napi.NapiWorker` | `Promise<T>` / Worker 进程池类 | 将 C 计算任务卸载至 libuv 线程池（`NapiTask`），或将纯 MoonBit 计算放入隔离的 Node 子进程池（`NapiWorker`）。 |

---

## 🛠️ CLI 命令参考

```text
napi-mbt-cli <command> [project-dir] [options]
```

| 子命令 | 功能说明 |
| :--- | :--- |
| `init <dir>` | 初始化新的 MoonBit 原生扩展项目（支持 `--name <pkg>`、`--napi-version <1..8>`、`--no-cjs`、`--no-esm`）。 |
| `check [dir]` | 在不执行完整编译的情况下校验 `napi-mbt.json`、MoonBit 导出签名、N-API 版本要求与宿主工具链。 |
| `generate [dir]` | 在项目根目录生成 `index.cjs`、`index.mjs`、`index.d.ts`，并在 `.napi-mbt/generated/` 下生成 C/MoonBit 胶水代码。 |
| `build [dir]` | 在 `.napi-mbt/build/` 隔离目录运行 `moon build --target native` 与 CMake，产出 `.node` 与加载器（`--debug`、`--release`、`--clean`）。 |
| `watch [dir]` | 监听源码与配置变更并自动增量重建（支持 `--once` 单次验证模式）。 |
| `doctor [dir]` | 诊断宿主 MoonBit、CMake、C/C++ 编译器、链接器及可选的 Node/npm 环境（支持 `--json`）。 |
| `npm-packages [dir]` | 生成多平台 npm 子包目录（`npm/<platform>/`）并更新根 `optionalDependencies`（支持 `--stage-prebuilds`）。 |
| `prepublish [dir]` | 校验已暂存的各平台二进制、ELF/PE/Mach-O 头部信息，并支持运行 `npm pack --dry-run`（`--verify-pack`）。 |
| `version` | 输出当前 `napi-mbt-cli` 版本信息（支持 `--json`）。 |

### 隔离构建流水线工作原理

1. **源码与导出分析**：`napi-mbt-cli` 解析项目 `.mbt` 源码与 `napi-mbt.json`，校验导出签名并推导所需的最低 N-API 版本。
2. **非侵入式工作区合成**：在 `.napi-mbt/build/` 下合成独立的构建工作区，绝不修改用户源码树。
3. **原生编译与链接**：调用 `moon build --target native` 生成原生静态库/目标产物，再由 CMake 将其与生成的 `napi_exports.c`、内嵌的 `node-api-headers` 以及（按需启用的）`moonbitlang/async` libuv 桥接层链接为 `.node` 动态库。
4. **符号检查与加载器输出**：使用 `nm` / `dumpbin` 检查导出符号以防止与 C 运行时符号冲突，随后将 `.node` 产物、`index.cjs`、`index.mjs` 与 `index.d.ts` 输出到项目目录。

---

## 📚 文档导航与独立示例

### 详细文档指南

| 主题分类 | 文档链接 |
| :--- | :--- |
| **快速上手与构建管线** | [使用指南](docs/zh/usage.md) · [构建、加载器与监听模式](docs/zh/build.md) |
| **平台与 ABI 策略** | [支持策略](docs/zh/support.md) · [平台验证 (EN)](docs/platforms.md) · [验证记录 (EN)](docs/validation.md) |
| **类型系统与对象生命周期** | [类型映射](docs/zh/types.md) · [类与回调](docs/zh/classes-callbacks.md) · [线程安全函数](docs/zh/tsfn.md) |
| **异步、流与多进程/多线程** | [异步函数](docs/zh/async.md) · [异步运行时适配器](docs/zh/async-adapter.md) · [JS Promise 输入](docs/zh/js-promises.md) · [异步流与 Web Streams](docs/zh/streams.md) · [原生后台任务](docs/zh/native-tasks.md) · [Worker 进程池](docs/zh/workers.md) |
| **工程实践、对比与路线图** | [性能基准](docs/zh/performance.md) · [开发流程](docs/zh/development.md) · [与 napi-rs 对比](docs/zh/napi-rs-comparison.md) · [路线图](docs/zh/roadmap.md) |

### 独立示例项目 (`examples/`)

[`examples/`](examples/README.md) 目录包含 9 个覆盖全部运行时特性的独立扩展项目：

| 示例项目 | 演示能力 |
| :--- | :--- |
| [`examples/hello-addon`](examples/hello-addon) | CJS/ESM 双模式导入与严格的标量边界校验 |
| [`examples/structured-data`](examples/structured-data) | 嵌套 `struct` / `enum` 结构、`Option`、`Array`、`Map` 与 `Json` |
| [`examples/native-class`](examples/native-class) | 具状态 `// napi:class` 原生类、属性读写、静态工厂与 `Symbol.dispose` |
| [`examples/callbacks`](examples/callbacks) | 同步借用回调、持久化线程安全回调与 JS 异常传播 |
| [`examples/async-file`](examples/async-file) | `pub async fn` 原生文件 I/O、`AbortSignal` 取消与异常恢复 |
| [`examples/binary-processing`](examples/binary-processing) | 拥有所有权的 `Bytes`（`Buffer`）对比零拷贝同步借用 `NapiBufferView` 与 TypedArray |
| [`examples/native-tasks`](examples/native-tasks) | C 线程池任务（`NapiTask`）、任务取消以及与 MoonBit `async fn` 组合调用 |
| [`examples/worker-tasks`](examples/worker-tasks) | 在隔离的 Node 子进程池中运行纯 MoonBit 密集计算任务（`NapiWorker`） |
| [`examples/streams`](examples/streams) | `NapiAsyncIterator` 异步流输入/输出、背压控制、提前取消与 Web `ReadableStream` |

你可以将任意示例一键物化到独立目录中构建并运行测试：

```bash
moon run examples/setup.mbtx examples/hello-addon ../my-hello-addon
cd ../my-hello-addon
pnpm test
```

---

## 🧪 本地开发与验证门禁

本仓库固定使用 **MoonBit `0.10.17+093cb8f9c`**、**CMake `4.4.4`** 与 **`moonbitlang/async@0.22.4`**。常用本地验证命令如下：

```bash
moon run scripts/toolchain-check.mbtx   # 校验固定的 MoonBit、CMake 与宿主编译器版本
moon check                              # 对所有 MoonBit 包执行类型检查
moon test                               # 运行单元、白盒与黑盒测试
moon run scripts/docs-check.mbtx        # 校验所有 Markdown 文档相对链接与门禁
moon run scripts/release-check.mbtx     # 校验模块版本号与开发锁文件规范
moon run scripts/examples-test.mbtx     # 打包当前 CLI 并完整构建/测试全部 9 个独立示例
```

更多工程验证细节请参阅 [开发流程](docs/zh/development.md) 与 [验证记录](docs/validation.md)。

---

## 📄 开源许可与第三方声明

### 项目许可证

`napi-mbt` 基于 **[MIT License](LICENSE)** 开源发布。

### 第三方组件与许可证声明

`napi-mbt` 在 [`internal/syntax/vendor/`](internal/syntax/VENDOR.md) 下内置了语法解析器源码，并在 [`internal/assets/data/resources.json`](internal/assets/data/resources.json) 中内嵌了编译扩展所需的 C 头文件与异步运行时桥接源码。在通过 [`scripts/package-cli.mbtx`](scripts/package-cli.mbtx) 打包发布 `napi-mbt-cli` 预编译归档包时，所有相关许可证文件均随附于归档包的 `licenses/` 目录下：

| 第三方组件 | 版本 / 上游来源 | 在 `napi-mbt` 中的用途 | 许可证 | 仓库路径 / 发布包许可证路径 |
| :--- | :--- | :--- | :--- | :--- |
| **Tree-sitter C Runtime** | `v0.26.8` (`cd5b087c`) · [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter) | 内置 C 语法解析运行时，用于解析 MoonBit AST | **MIT** | [`internal/syntax/vendor/TREE-SITTER-LICENSE`](internal/syntax/vendor/TREE-SITTER-LICENSE)（`licenses/TREE-SITTER-LICENSE`） |
| **Unicode Character Database** | Unicode Consortium（随附于 Tree-sitter） | Tree-sitter 词法分析器使用的 Unicode 字符分类表 | **Unicode-DFS-2016** | [`internal/syntax/vendor/runtime/unicode/LICENSE`](internal/syntax/vendor/runtime/unicode/LICENSE)（`licenses/UNICODE-LICENSE`） |
| **Tree-sitter MoonBit Grammar** | Commit `190881df` (ABI 15) · [unmbt/tree-sitter-moonbit](https://github.com/unmbt/tree-sitter-moonbit) | 内置 MoonBit 语法分析表（`parser.c` / `scanner.c`） | **Apache-2.0 AND MIT** | [`internal/syntax/vendor/GRAMMAR-LICENSE`](internal/syntax/vendor/GRAMMAR-LICENSE)（`licenses/GRAMMAR-LICENSE`） |
| **Node-API Headers (`node-api-headers`)** | `v1.9.0` · [nodejs/node-api-headers](https://github.com/nodejs/node-api-headers) | 内嵌 `node_api.h` 与 `js_native_api.h` 头文件，支持离线编译 `.node` | **MIT** | 内嵌于 [`internal/assets/data/resources.json`](internal/assets/data/resources.json)（`licenses/NODE-API-LICENSE`） |
| **MoonBit Async Runtime (`moonbitlang/async`)** | `v0.22.4` · [moonbitlang/async](https://github.com/moonbitlang/async) | 内嵌原生异步事件循环桥接层与运行时支持代码 | **Apache-2.0** | 内嵌于 [`internal/assets/data/resources.json`](internal/assets/data/resources.json)（`licenses/MOONBIT-ASYNC-LICENSE`） |
| **libuv Headers & Declarations** | [libuv/libuv](https://github.com/libuv/libuv) | 内嵌 libuv 类型与函数声明，用于接入 Node.js 事件循环 | **MIT** | 内嵌于 [`internal/assets/data/resources.json`](internal/assets/data/resources.json)（`licenses/LIBUV-LICENSE`） |
