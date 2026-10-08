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

The CLI is a standalone MoonBit native executable distributed through Mooncakes and GitHub Releases. `init`, `generate`, `build`, and `prepublish` do not invoke Node.js or npm. The Tree-sitter parser, project templates, and Node-API headers are bundled into the executable.

## ✨ Key Features

- ⚡ **Zero Overhead Native ABI**: `napi-mbt` natively connects MoonBit with Node-API without WASM intermediaries, guaranteeing bare-metal execution performance.
- 🪄 **`#export_name` generation**: The annotation name becomes the C ABI, JavaScript, and TypeScript export name;
- 📝 **Automatic TypeScript Typing**: Generates `.d.ts` declaration files effortlessly alongside your MoonBit compilations for strong-typed JS/TS consumption.
- 🚀 **Zero-Copy Buffer Mutation**: Safely manipulate Node.js Buffers directly in MoonBit memory using `NapiBufferView`.
- 📦 **Integrated Cross-Platform CI/CD**: Builds native modules and CLI binaries for Windows x64, Linux x64, and macOS ARM64. Platform packages use NPM's `optionalDependencies` pattern.

Intel macOS prebuilt releases are paused because the current MoonBit toolchain
installer does not support macOS x64. macOS CI and GitHub Releases target Apple
Silicon (ARM64). Existing Intel package metadata is retained for compatibility.

## 🚀 Quick Start

### 1. Requirements

- `init`, `generate`, `prepublish`: the native CLI only.
- `build`: [MoonBit](https://www.moonbitlang.com/), CMake, and GCC/Clang on Unix or Visual Studio C++ build tools on Windows. CMake must support the installed Visual Studio version.
- [Node.js](https://nodejs.org/en/) is needed to load/test the generated addon; npm is needed to publish packages. Neither is a CLI build dependency.

### Installing the CLI

Use `moon install` (recommended, once a release containing this entry point is on Mooncakes):

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
napi-mbt-cli --help
```

This installs `napi-mbt-cli` (`napi-mbt-cli.exe` on Windows) into `~/.moon/bin`.
Ensure that directory is on PATH. To install the current checkout before a new
Mooncakes release, or choose `~/.unmbt` as the destination:

```bash
moon install ./cmd/napi-mbt-cli
moon install ./cmd/napi-mbt-cli --bin ~/.unmbt
```

You can also build from source:

```bash
moon build --target native --release cmd/napi-mbt-cli
```

The native CLI uses `moonbitlang/core/argparse` for subcommands and help.
Its version comes from `moon.mod`: the `gen_version` rule and `dev_build` in
`cmd/napi-mbt-cli/moon.pkg` run `scripts/gen_version.mbtx` to regenerate
`generated_version.mbt`. Keep that generated file in releases for downstream
builds. After building the CLI, run `moon run scripts/cli-native-test.mbtx` to test both the release executable and `moon install` without Node/npm on PATH.

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

`moon install` and the Release installer provide the same standalone CLI. The old npm CLI package and Node fallback are retired. Use `--generator=auto` or `--generator=moonbit`; the old `node` value produces a migration error. No `node_modules` directory is required. Build resources are extracted into the ignored `.napi-mbt/` directory.

### 2. Project Setup

Create a project with the native CLI on PATH:

```bash
napi-mbt-cli init my-napi-addon
cd my-napi-addon
napi-mbt-cli generate --check
```

The command creates the MoonBit package, addon configuration, loaders, type declarations, and Node smoke tests. It refuses to overwrite existing files unless `--force` is given.

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
napi-mbt-cli build
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

Version releases use the repository's `bump.config.json`; it runs `moon check` before the version is committed. After all target binaries have been built, prepare platform packages and publish them in dependency order:

```bash
napi-mbt-cli prepublish
npm run publish:all
```

Use `npm run publish:dry-run` to inspect package contents without publishing.

### Development checks

```bash
moon build --target native --release cmd/napi-mbt-cli
moon run --target native --release cmd/napi-mbt-cli -- build --release
moon run scripts/cli-native-test.mbtx
moon check --target native --warn-list +73 --deny-warn
moon test --target native
moon run scripts/parser-asan-test.mbtx
node --test scripts/test.js
```

The native test stages run before Node load tests. Vendored parser versions and licenses are recorded in `internal/syntax/VENDOR.md`. Editable templates and header resources live in `internal/assets/data/resources.json`; the MoonBit resource build rule regenerates the embedded copy when that input changes.

## 📚 Documentation

For a detailed guide on supported types, advanced configurations, and internal architectures, refer to the documentation directories:

- 📖 [Usage Guide (en)](docs/en/usage.md)
- ⚙️ [Development & Architecture (en)](docs/en/development.md)

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
