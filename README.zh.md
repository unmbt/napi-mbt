<div align="center">
  <h1>🚀 napi-mbt</h1>

  <p>
    <b>面向 MoonBit 和 Node.js 的高自动化原生扩展框架。</b>
  </p>

  <p>
    <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-%3E%3D8.6-brightgreen?logo=node.js&logoColor=white" alt="Node.js version" /></a>
    <a href="https://www.moonbitlang.com/"><img src="https://img.shields.io/badge/MoonBit-Native-blueviolet?logo=moon&logoColor=white" alt="MoonBit Native" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
    <img src="https://img.shields.io/badge/Status-Beta-orange" alt="Status" />
  </p>

  <p>
    🇨🇳 简体中文 | <a href="./README.md">🇺🇸 English</a>
  </p>
</div>

---

## 🌟 简介

`napi-mbt` 是一款深受 `napi-rs` 启发的框架，它赋予了开发者利用极速、轻量的多范式语言 **MoonBit** 编写原生 Node.js C++ 扩展（Addon）的能力。
`napi-mbt` 基于无开销的 Node-API (N-API) C ABI，完美连接 MoonBit 与 Node.js，彻底避免了基于 WASM 序列化的内存损耗，让你的代码获得比肩 C++ 的裸机执行性能。

CLI 是通过 Mooncakes 和 GitHub Releases 分发的独立 MoonBit 原生程序。`init`、`generate`、`build` 和 `prepublish` 均不调用 Node.js 或 npm；Tree-sitter 解析器、项目模板和 Node-API 头文件已内嵌。

## ✨ 核心特性

- ⚡ **零开销原生 ABI**：跳过 WASM 虚拟机中间层，以 Native 目标编译直接通过 Node-API 进行内存互操作，保证极限性能。
- 🪄 **`#export_name` 自动化生成**：注解中的名称同时成为 C ABI、JavaScript 和 TypeScript 导出名；
- 📝 **自动 TypeScript 定义**：构建时自动分析 MoonBit 签名，同步输出严谨的 `.d.ts` 类型声明文件，实现 JS/TS 的全链路强类型约束。
- 🚀 **Buffer 零拷贝修改**：提供专属的 `NapiBufferView` 视图，允许在 MoonBit 侧直接读写 Node.js Buffer 内存，极为适合图像处理和加密的高性能场景。
- 📦 **集成跨平台 CI/CD**：内置针对 Optional Dependencies 的发布支持，配合标准化的 GitHub Actions 矩阵，实现 Windows、Linux、macOS 原生拓展库的一键编译发布。

当前 CI 构建 Windows x64、Linux x64 和 macOS ARM64 的原生模块及 CLI。
由于当前 MoonBit 工具链安装器不支持 macOS x64，Intel macOS 的预编译发布暂时暂停；
macOS CI 和 GitHub Releases 仅面向 Apple Silicon（ARM64）。已有 Intel 包元数据保留以兼容旧版本。

## 🚀 快速开始

### 1. 环境准备

- `init / generate / prepublish`：只需要原生 CLI。
- `build`：需要 [MoonBit](https://www.moonbitlang.com/)、CMake 和 C 编译器（Unix 使用 GCC/Clang，Windows 使用 Visual Studio C++ 构建工具）；CMake 需支持安装的 Visual Studio 版本。
- [Node.js](https://nodejs.org/en/) 仅用于加载、测试和使用生成的扩展，npm 用于发包；构建工具本身不依赖它们。

### 安装 CLI

首选使用 `moon install`（需要 Mooncakes 上已发布包含此入口的版本）：

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
napi-mbt-cli --help
```

默认安装到 `~/.moon/bin`，命令名为 `napi-mbt-cli`，Windows 下为
`napi-mbt-cli.exe`。请将安装目录加入 PATH。新版本发布前，可从当前仓库
安装；也可以通过 `--bin` 指定安装到 `~/.unmbt`：

```bash
moon install ./cmd/napi-mbt-cli
moon install ./cmd/napi-mbt-cli --bin ~/.unmbt
```

也可以只编译，不安装：

```bash
moon build --target native --release cmd/napi-mbt-cli
```

原生 CLI 使用 `moonbitlang/core/argparse` 解析子命令并提供帮助。
版本以 `moon.mod` 为唯一来源：`cmd/napi-mbt-cli/moon.pkg` 中的 `gen_version`
rule 和 `dev_build` 调用 `scripts/gen_version.mbtx` 生成
`generated_version.mbt`。发布时保留生成文件，供下游构建使用。
构建 CLI 后运行 `moon run scripts/cli-native-test.mbtx`，可在隔离 Node/npm 的环境验证 Release 程序和 `moon install` 的安装产物。

也可以把预编译 CLI 安装到 `~/.unmbt`（Windows 为
`%USERPROFILE%\.unmbt`）：

Unix 系统可使用仓库安装脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.sh | bash
```

Windows PowerShell：

```powershell
irm https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.ps1 | iex
```

`moon install` 和 Release 安装脚本均提供独立原生 CLI，旧 npm CLI 包和 Node 回退实现已移除。生成器使用 `--generator=auto` 或 `--generator=moonbit`；旧 `node` 值会返回迁移提示。项目无需 `node_modules`，构建资源写入已忽略的 `.napi-mbt/` 目录。

### 2. 项目初始化

使用已加入 PATH 的原生 CLI 创建项目：

```bash
napi-mbt-cli init my-napi-addon
cd my-napi-addon
napi-mbt-cli generate --check
```

命令会创建 MoonBit 包、扩展配置、加载器、类型声明和 Node 加载测试。默认拒绝覆盖已有文件，需要覆盖时使用 `--force`。

### 3. 编写 MoonBit 逻辑代码

在 `lib.mbt` 文件中，写一个函数并附带 `#export_name("mbt_add")` 标记：

```moonbit
#export_name("mbt_add")
pub fn add(a : Int, b : Int) -> Int {
  a + b
}
```

### 4. 构建与编译

通过 CLI 工具自动生成所有绑定并编译出 `.node` 二进制插件：

```bash
napi-mbt-cli build
```

上述命令会自动执行：
1. 🔍 扫描 AST 并识别 `#export_name("mbt_add")` 标记。
2. 🛠️ 生成逐导出的 `napi_exports.mbt`、`napi_glue.c` 和 `index.d.ts`。
3. 🏗️ 执行底层的原生编译 (`moon build --target native`) 并链接 C 代码。
4. 📦 将产生的 `.node` 输出到对应环境的构件目录 `artifacts/[platform]-[arch]/` 中。

最后，你可以在 JavaScript 中直接调用了：

```javascript
const addon = require('./artifacts/win32-x64-msvc/napi_mbt.node');
console.log(addon.mbt_add(2, 3)); // 输出: 5
```

在 `napi-mbt.json` 中设置单一 N-API 版本。默认 v1 覆盖 Node 8.6–26；Threadsafe Function 需要 v4，BigInt 需要 v6。核心 Promise API 按当前 Node-API 头文件属于 v1。

### 发包

版本发布使用仓库中的 `bump.config.json`，会在版本提交前执行 `moon check`。完成各目标平台构建后，按平台包、根包的顺序准备并发布；CLI 单独通过 Mooncakes 和 GitHub Releases 分发：

```bash
napi-mbt-cli prepublish
npm run publish:all
```

使用 `npm run publish:dry-run` 可以只检查 npm 包内容而不实际发布。

### 开发验证

```bash
moon build --target native --release cmd/napi-mbt-cli
moon run --target native --release cmd/napi-mbt-cli -- build --release
moon run scripts/cli-native-test.mbtx
moon check --target native --warn-list +73 --deny-warn
moon test --target native
moon run scripts/parser-asan-test.mbtx
node --test scripts/test.js
```

先完成原生命令验证，再单独使用 Node 做加载测试。解析器固定版本及许可证记录在 `internal/syntax/VENDOR.md`；模板与头文件资源维护在 `internal/assets/data/resources.json`，MoonBit 构建规则会根据资源修改更新内嵌内容。

## 📚 文档

想深入了解所支持的数据类型、CLI 的高级用法，或是 `napi-mbt` 底层的系统架构与跨端分发原理？请参阅以下详细的手册：

- 📖 [使用文档 (zh)](docs/zh/usage.md)
- ⚙️ [架构开发与贡献指南 (zh)](docs/zh/development.md)

## 📄 协议

本项目基于 MIT 协议开源，详情请参阅 [LICENSE](LICENSE) 文件。
