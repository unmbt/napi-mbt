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

## 🚀 快速开始

### 1. 环境准备

- 🟢 [Node.js](https://nodejs.org/en/) >= 8.6
- 🌙 [MoonBit](https://www.moonbitlang.com/) 核心工具链
- 🔨 C/C++ 编译器（Unix 上需要 GCC/Clang，Windows 上需要 Visual Studio）

### 安装 CLI

可以直接用 MoonBit 从源码构建：

```bash
moon build --target native --release cmd/main
```

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

原生启动器会调用随 release 一起下载的 Node fallback runtime 来执行
tree-sitter 生成。只有直接安装 fallback 包或发布 N-API 平台包时才需要 npm。

### 2. 项目初始化

创建一个新的 Node.js 项目，并安装 N-API 头文件：

```bash
mkdir my-napi-addon
cd my-napi-addon
npm init -y
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
npx napi-mbt build
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

版本发布使用仓库中的 `bump.config.json`，会在版本提交前执行 native 构建和测试。完成各目标平台构建后，按平台包、CLI、根包的顺序准备并发布：

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
