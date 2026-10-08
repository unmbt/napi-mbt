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

仓库会把原生 MoonBit CLI 发布到 Mooncakes 和 GitHub Releases。Node CLI 继续作为 tree-sitter 生成器的 fallback，因此全局安装 CLI 不再强制依赖 npm。

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

- 🟢 [Node.js](https://nodejs.org/en/) >= 8.6
- 🌙 [MoonBit](https://www.moonbitlang.com/) 核心工具链
- 🔨 C/C++ 编译器（Unix 上需要 GCC/Clang，Windows 上需要 Visual Studio）

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
运行 `moon run scripts/cli-native-test.mbtx` 可验证参数解析和版本自动更新。

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

`moon install` 只安装原生可执行文件。当前 `init`、`generate`、`build`
和 `prepublish` 仍需要 Node.js 和 Node fallback。可在项目中安装
`@unmbt/napi-mbt-cli` 开发依赖（启动器会从当前目录向父目录查找），或将
`NAPI_MBT_NODE_RUNTIME` 设置为已安装 npm 依赖的源码仓库中
`cli/bin/napi-mbt.js` 的绝对路径。GitHub Release 安装脚本会附带 fallback
及其依赖。帮助、版本查询和 `targets` 完全由 MoonBit 执行。

### 2. 项目初始化

创建一个新的 Node.js 项目，并安装 N-API 头文件：

```bash
mkdir my-napi-addon
cd my-napi-addon
npm init -y
npm install --save-dev @unmbt/napi-mbt-cli
npm install node-api-headers
```

初始化 MoonBit 包并配置你的 `moon.pkg`：
```bash
moon new lib
```

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

版本发布使用仓库中的 `bump.config.json`，会在版本提交前执行 `moon check`。完成各目标平台构建后，按平台包、CLI、根包的顺序准备并发布：

```bash
npm run publish:prepare
npm run publish:all
```

使用 `npm run publish:dry-run` 可以只检查 npm 包内容而不实际发布。

## 📚 文档

想深入了解所支持的数据类型、CLI 的高级用法，或是 `napi-mbt` 底层的系统架构与跨端分发原理？请参阅以下详细的手册：

- 📖 [使用文档 (zh)](docs/zh/usage.md)
- ⚙️ [架构开发与贡献指南 (zh)](docs/zh/development.md)

## 📄 协议

本项目基于 MIT 协议开源，详情请参阅 [LICENSE](LICENSE) 文件。
