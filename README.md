<div align="center">
  <h1>🚀 napi-mbt</h1>

  <p>
    <b>A highly-automated native extension framework for MoonBit and Node.js.</b>
  </p>

  <p>
    <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-%3E%3D8.6-brightgreen?logo=node.js&logoColor=white" alt="Node.js version" /></a>
    <a href="https://www.moonbitlang.com/"><img src="https://img.shields.io/badge/MoonBit-Native-blueviolet?logo=moon&logoColor=white" alt="MoonBit Native" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
    <img src="https://img.shields.io/badge/Status-Beta-orange" alt="Status" />
  </p>

  <p>
    <a href="./README.zh.md">🇨🇳 简体中文</a> | 🇺🇸 English
  </p>
</div>

---

## 🌟 Introduction

`napi-mbt` is a framework inspired by `napi-rs` that empowers developers to build native Node.js addons using **MoonBit**, a fast and lightweight multi-paradigm language. `napi-mbt` bridges MoonBit and Node.js with a zero-overhead Node-API (N-API) C ABI, avoiding the memory cost of WASM-based marshaling while maintaining optimal execution performance.

The repository publishes a native MoonBit CLI to Mooncakes and GitHub Releases. The Node CLI remains a fallback transport for tree-sitter generation, while the native launcher makes global npm installation optional.

## ✨ Key Features

- ⚡ **Zero Overhead Native ABI**: `napi-mbt` natively connects MoonBit with Node-API without WASM intermediaries, guaranteeing bare-metal execution performance.
- 🪄 **`#export_name` generation**: The annotation name becomes the C ABI, JavaScript, and TypeScript export name;
- 📝 **Automatic TypeScript Typing**: Generates `.d.ts` declaration files effortlessly alongside your MoonBit compilations for strong-typed JS/TS consumption.
- 🚀 **Zero-Copy Buffer Mutation**: Safely manipulate Node.js Buffers directly in MoonBit memory using `NapiBufferView`.
- 📦 **Integrated Cross-Platform CI/CD**: Matrix-build ready! Automatically publishes architecture-specific Native Modules via NPM's `optionalDependencies` pattern (Supports Windows, Linux, macOS - x64 & ARM64).

## 🚀 Quick Start

### 1. Requirements

- 🟢 [Node.js](https://nodejs.org/en/) >= 8.6
- 🌙 [MoonBit](https://www.moonbitlang.com/) Toolchain
- 🔨 A C Compiler (GCC/Clang on Unix, MSVC on Windows)

### Installing the CLI

Build it from source with MoonBit:

```bash
moon build --target native --release cmd/main
```

The native CLI uses `moonbitlang/core/argparse` for subcommands and help.
Its version comes from `moon.mod`: the `gen_version` rule and `dev_build` in
`cmd/main/moon.pkg` run `scripts/gen_version.mbtx` to regenerate
`generated_version.mbt`. Keep that generated file in releases for downstream
builds. Run `moon run scripts/cli-native-test.mbtx` to check argument handling
and version regeneration.

Or install the precompiled native CLI into `~/.unmbt` (Windows uses
`%USERPROFILE%\.unmbt`):

On Unix-like systems the repository installer performs the same version check:

```bash
curl -fsSL https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.sh | bash
```

On Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.ps1 | iex
```

The native launcher delegates to the bundled Node fallback runtime for
tree-sitter generation. npm is only needed when you choose to install the
fallback package directly or publish the N-API platform packages.

### 2. Project Setup

Create a new Node.js project (the native CLI is already on your PATH):

```bash
mkdir my-napi-addon
cd my-napi-addon
npm init -y
npm install node-api-headers
```

Initialize your MoonBit package and configure `moon.pkg`:
```bash
moon new lib
```

### 3. Writing MoonBit Code

In your `lib.mbt`, write a function and tag it with `#export_name("mbt_add")`:

```moonbit
#export_name("mbt_add")
pub fn add(a : Int, b : Int) -> Int {
  a + b
}
```

### 4. Build the Addon

Run the CLI tool to auto-generate bindings and build the `.node` binary:

```bash
npx napi-mbt build
```

This command will:
1. 🔍 Parse your `#export_name("mbt_add")` annotated functions.
2. 🛠️ Generate `napi_exports.mbt` and `index.d.ts`.
3. 🏗️ Compile the Native target (`moon build --target native`).
4. 📦 Generate `.node` binary at `artifacts/[platform]-[arch]/`.

You can now use your native addon in JavaScript:

```javascript
const addon = require('./artifacts/win32-x64-msvc/napi_mbt.node');
console.log(addon.mbt_add(2, 3)); // Output: 5
```

Set one package-wide N-API version in `napi-mbt.json`. The default v1 covers Node 8.6–26; Threadsafe Function requires v4 and BigInt requires v6. Core Promise APIs are v1 according to the Node-API headers.

### Release and publish

Version releases use the repository's `bump.config.json`; it runs the native build and tests before the version is committed. After all target binaries have been built, prepare platform packages and publish them in dependency order:

```bash
npm run publish:prepare
npm run publish:all
```

Use `npm run publish:dry-run` to inspect package contents without publishing.

## 📚 Documentation

For a detailed guide on supported types, advanced configurations, and internal architectures, refer to the documentation directories:

- 📖 [Usage Guide (en)](docs/en/usage.md)
- ⚙️ [Development & Architecture (en)](docs/en/development.md)

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
