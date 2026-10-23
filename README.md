<div align="center">

[English](README.md) | [简体中文](README.zh.md)

# ⚡ napi-mbt

*A Native Node-API (N-API) Toolchain, Code Generator, and Runtime for MoonBit*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-f97316?style=flat-square)](https://www.moonbitlang.com/)
[![Mooncakes](https://img.shields.io/badge/mooncakes.io-unmbt%2Fnapi--mbt-7c3aed?style=flat-square)](https://mooncakes.io/docs/unmbt/napi-mbt)
[![CI](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml/badge.svg?branch=master)](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square)](docs/support.md)
[![Node-API](https://img.shields.io/badge/ABI-Node--API%20v4--v8-339933?style=flat-square)](docs/support.md)

</div>

---

## 📖 Overview

**`napi-mbt`** is an end-to-end toolchain and runtime library that compiles [MoonBit](https://www.moonbitlang.com/) native packages (`preferred_target = "native"`) into ABI-stable Node.js `.node` addons.

Without writing C/C++ boilerplate by hand, `napi-mbt` parses your MoonBit package with an embedded Tree-sitter MoonBit grammar and automatically produces:

- **Native Node-API C glue** with strict boundary validation and deterministic resource cleanup
- **Compiled `.node` native addons** via CMake and the host C compiler (MSVC, GCC, or Clang)
- **Dual-mode JavaScript loaders** supporting both CommonJS (`index.cjs`) and ES Modules (`index.mjs`)
- **Strict TypeScript declarations** (`index.d.ts`) matching your MoonBit signatures
- **Cross-platform npm package manifests** for per-platform binary distribution (`optionalDependencies`)

Crucially, **`napi-mbt-cli` is a standalone native binary**. You can install it directly via Mooncakes (`moon install`) or GitHub Releases—running the CLI itself does not require Node.js or npm.

---

## ✨ Key Highlights

| Capability | Description |
| :--- | :--- |
| 🎯 **Zero-Boilerplate Exports** | Export `pub fn`, `pub async fn`, `pub struct`, and `pub enum` directly from MoonBit. Only stateful classes require an explicit `// napi:class` marker. |
| 🛡️ **Strict Boundary Validation** | Rejects `NaN`, `±Infinity`, fractional floats passed to integers, out-of-range 32-bit/64-bit numbers, and invalid UTF-16/Buffer inputs at the C boundary before entering MoonBit. |
| ⚡ **Full Async & Concurrency Stack** | Supports cancellable `pub async fn` Promises (`moonbitlang/async@0.22.4` + libuv), native C worker pool tasks (`NapiTask`), isolated MoonBit worker pools (`NapiWorker`), awaited JS Promises (`NapiJsPromise`), and demand-driven async streams (`NapiAsyncIterator`). |
| 🧱 **Safe Classes & Callbacks** | Native classes (`NapiClass[T]`) include constructors, static factories, getters/setters, methods, explicit `.dispose()`, and `Symbol.dispose`. Callbacks (`NapiCallback`) support both synchronous borrows and stored threadsafe functions. |
| 🔒 **Isolated, Cached Builds** | Compiles inside `.napi-mbt/build/` without mutating user source files. Includes content-addressed build caching, watch mode (`watch`), and native symbol collision inspection (`nm` / `dumpbin`). |
| 📦 **Precise ABI & Engine Ranges** | Targets **N-API v4** by default and automatically raises the required N-API level (up to v8) only when higher-level features are used, computing the exact `engines.node` intersection in `package.json`. |

---

## 🖥️ Platform & Node.js Support

### Native Host Targets

`napi-mbt` builds native addons for the current host architecture and C runtime:

| OS | Architecture | C Runtime / Toolchain | Package Platform Triple |
| :--- | :--- | :--- | :--- |
| **Windows** | `x64` | MSVC (`cl` / MSBuild + Windows SDK) | `win32-x64-msvc` |
| **Linux** | `x64`, `arm64` | `glibc` (`gcc` / `clang`) | `linux-x64-gnu`, `linux-arm64-gnu` |
| **Linux** | `x64`, `arm64` | `musl` (Alpine native toolchain) | `linux-x64-musl`, `linux-arm64-musl` |
| **macOS** | `x64`, `arm64` | Apple Clang (Xcode / Command Line Tools) | `darwin-x64`, `darwin-arm64` |

> [!NOTE]
> Cross-architecture compilation is intentionally rejected unless running on a matching host toolchain. On Linux (`gnu` and `musl`), compiler probes and output ELF dynamic dependencies (`PT_INTERP` / `DT_NEEDED`) are verified before installing `.node` binaries and again during `prepublish`. See [Support Policy](docs/support.md) and [Platform Validation](docs/platforms.md).

### Node-API Feature Matrix

| Feature Surface | Minimum N-API | Minimum Node.js Consumer Baseline |
| :--- | :---: | :--- |
| Scalars (`Int`, `UInt`, `Double`, `Bool`), UTF-16 `String`, owned `struct` / `enum` / `Array` / `Map` | **1** | Node 10.16.0 (CJS) / 12.20.0 (Dual CJS+ESM) |
| Native classes (`NapiClass`) & callback lifecycle | **3** | Node 10.16.0 (CJS) / 12.20.0 (Dual CJS+ESM) |
| Stored / threadsafe callbacks (`NapiCallback`, default CLI target) | **4** | `>=12.20.0 <13 \|\| >=14.13.1` (Dual default) |
| Exact 64-bit `Int64` / `UInt64` (`bigint`) | **6** | Node 10.7.0+ (intersected with loader mode) |
| `Bytes` (`Buffer`) & synchronous borrowed `NapiBufferView` | **7** | Node 10.16.0+ (intersected with loader mode) |
| `pub async fn`, `NapiTask`, `NapiJsPromise`, `NapiAsyncIterator`, async host cleanup | **8** | `>=12.22.0 <13 \|\| >=14.17.0 <15 \|\| >=15.12.0 <16 \|\| >=16.0.0` |
| Web `ReadableStream` helper (`*Stream`) | **8** | **Node 18.0.0+** |

CI continuously validates Node **22, 24, and 26**, alongside minimum-version consumer compatibility gates and Windows/Linux memory-leak verification.

---

## 📦 Quick Start

### 1. Install the CLI

Install `napi-mbt-cli` from [Mooncakes](https://mooncakes.io/docs/unmbt/napi-mbt) using the MoonBit toolchain:

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
```

This installs the executable to `~/.moon/bin/napi-mbt-cli` (`%USERPROFILE%\.moon\bin\napi-mbt-cli.exe` on Windows). Prebuilt archives for Windows, Linux, and macOS are also available on [GitHub Releases](https://github.com/unmbt/napi-mbt/releases) with `SHA256SUMS.txt` and build provenance attestations.

Verify your host compiler, CMake, and MoonBit environment at any time:

```bash
napi-mbt-cli doctor
```

### 2. Scaffold and Build a New Addon

```bash
napi-mbt-cli init my-addon
cd my-addon
moon update
moon check
napi-mbt-cli check
napi-mbt-cli build
```

Generated projects declare `"preferred_target": "native"` in `moon.mod`, depend on `unmbt/napi-mbt` from Mooncakes, and default to **N-API 4** with both CommonJS and ESM loaders enabled.

### 3. Write MoonBit & Call from JavaScript / TypeScript

Define your exports in `lib.mbt`:

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

Rebuild with `napi-mbt-cli build` and consume the generated addon from ES Modules, CommonJS, or TypeScript:

```js
import { summarize } from './index.mjs';
// or: const { summarize } = require('./index.cjs');

console.log(summarize('orders', [10, 20, 30]));
// => { label: 'orders', total: 60 }
```

---

## 🧬 Type System & Runtime Capabilities

`napi-mbt` enforces strict, predictable conversions across the MoonBit <-> Node.js boundary:

| MoonBit Type | JavaScript / TypeScript | Semantics & Boundary Guarantees |
| :--- | :--- | :--- |
| `Int`, `UInt` | `number` | Checked 32-bit signed (`[-2^31, 2^31 - 1]`) and unsigned (`[0, 2^32 - 1]`) integers; rejects `NaN`, `±Infinity`, and fractions. |
| `Int64`, `UInt64` | `bigint` | Checked 64-bit signed/unsigned `BigInt` (`N-API 6`); rejects out-of-range 64-bit values. |
| `Double`, `Bool`, `Unit` | `number`, `boolean`, `void` | `Double` requires finite IEEE-754 numbers (`NaN` and `±Infinity` are rejected). |
| `String` | `string` | Direct UTF-16 string conversion without intermediate UTF-8 transcoding. |
| `Bytes` | `Buffer` | Owned byte copy across the boundary (`N-API 7`); safe to store and return from async functions. |
| `@napi.NapiBufferView` | `Buffer \| Uint8Array` | Zero-copy synchronous borrow (`N-API 7`); valid only during the synchronous call frame. |
| `@napi.NapiUint8Array` / `NapiInt32Array` / `NapiFloat64Array` / `NapiArrayBuffer` | `Uint8Array` / `Int32Array` / `Float64Array` / `ArrayBuffer` | Owned typed-array and `ArrayBuffer` copies with full element length preservation. |
| `T?`, `Array[T]`, `Map[String, T]`, `(A, B, ...)`, `Json` | `T \| null`, `Array<T>`, `Record<string, T>`, `[A, B, ...]`, `JsonValue` | Recursive structural validation; `Option::None` maps to `null` (and accepts `null` or `undefined` on input). |
| `pub struct` / `pub enum` | Object / Discriminated Union | Exported structs map to typed JS objects; enums use `{ tag: "Variant", ... }` discriminated unions. |
| `// napi:class` + `@napi.NapiClass[T]` | `class` with `dispose()` & `[Symbol.dispose]()` | Native handle wrapping with constructors, static factories, properties, methods, and deterministic disposal. |
| `@napi.NapiCallback[Args, Ret]` | `(...args) => Ret` | Supports synchronous call-scoped invocations and cloned threadsafe functions (`N-API 4`). |
| `pub async fn(...) -> T raise` | `Promise<T>` (with `.cancel()` & `{ signal }`) | Runs on the embedded `moonbitlang/async@0.22.4` + libuv loop (`N-API 8`) with cooperative cancellation. |
| `@napi.NapiJsPromise[T]` | `Promise<T> \| PromiseLike<T>` | Awaits JavaScript Promises or thenables inside MoonBit `async fn` exports with typed resolution. |
| `@napi.NapiAsyncIterator[T]` | `AsyncIterableIterator<T>` & `ReadableStream<T>` | Demand-driven streaming input/output with backpressure and early consumer cancellation (`return()`). |
| `@napi.NapiTask` / `@napi.NapiWorker` | `Promise<T>` / Worker Pool Class | Offloads C jobs to the libuv threadpool (`NapiTask`) or pure MoonBit jobs to isolated Node worker processes (`NapiWorker`). |

---

## 🛠️ CLI Reference

```text
napi-mbt-cli <command> [project-dir] [options]
```

| Command | Description |
| :--- | :--- |
| `init <dir>` | Scaffold a new MoonBit native addon project (`--name <pkg>`, `--napi-version <1..8>`, `--no-cjs`, `--no-esm`). |
| `check [dir]` | Validate `napi-mbt.json`, MoonBit exports, N-API version requirements, and host toolchain without compiling. |
| `generate [dir]` | Generate `index.cjs`, `index.mjs`, `index.d.ts`, and C/MoonBit glue into `.napi-mbt/generated/`. |
| `build [dir]` | Run `moon build --target native` and CMake in `.napi-mbt/build/`, producing `.node` and loader artifacts (`--debug`, `--release`, `--clean`). |
| `watch [dir]` | Watch project sources and rebuild automatically on change (`--once` for single-cycle verification). |
| `doctor [dir]` | Inspect MoonBit, CMake, host C/C++ compiler, linker, and optional Node/npm environment (`--json`). |
| `npm-packages [dir]` | Generate per-platform npm package directories (`npm/<platform>/`) and update `optionalDependencies` (`--stage-prebuilds`). |
| `prepublish [dir]` | Verify staged platform binaries, ELF/PE/Mach-O headers, and optionally run `npm pack --dry-run` (`--verify-pack`). |
| `version` | Print the `napi-mbt-cli` version (`--json`). |

### How the Isolated Build Pipeline Works

1. **Source & Export Analysis**: `napi-mbt-cli` parses your `.mbt` files and `napi-mbt.json`, checking supported signatures and inferring the minimum N-API version.
2. **Non-Invasive Workspace Staging**: The CLI prepares an isolated build workspace under `.napi-mbt/build/` without modifying your source tree.
3. **Native Compilation & Linking**: `moon build --target native` compiles MoonBit packages to native archives, and CMake links them with the generated Node-API C shim (`napi_exports.c`), embedded `node-api-headers`, and (when async is used) the `moonbitlang/async` libuv bridge.
4. **Symbol & Loader Emission**: Exported symbols are verified against C runtime collisions (`nm`/`dumpbin`), `.node` binaries are copied to the output directory, and `index.cjs`, `index.mjs`, and `index.d.ts` are emitted.

---

## 📚 Documentation & Examples

### Documentation Guides

| Topic | Guide |
| :--- | :--- |
| **Getting Started & CLI Usage** | [Usage Guide](docs/en/usage.md) · [Build & Loader Pipeline](docs/build.md) |
| **Platform & ABI Policy** | [Support Policy](docs/support.md) · [Platform Validation](docs/platforms.md) · [Validation Record](docs/validation.md) |
| **Type System & Objects** | [Type Mapping](docs/types.md) · [Classes & Callbacks](docs/classes-callbacks.md) · [Threadsafe Functions](docs/tsfn.md) |
| **Async, Streams & Workers** | [Async Functions](docs/async.md) · [Async Adapter](docs/async-adapter.md) · [JS Promises](docs/js-promises.md) · [Async Streams](docs/streams.md) · [Native Tasks](docs/native-tasks.md) · [Worker Pools](docs/workers.md) |
| **Engineering & Benchmarks** | [Performance Benchmarks](docs/performance.md) · [Development Workflow](docs/en/development.md) · [Roadmap](docs/roadmap.md) |

### Standalone Examples

The [`examples/`](examples/README.md) directory contains 9 complete, self-contained addon projects covering every runtime surface:

| Example | Demonstrated Capabilities |
| :--- | :--- |
| [`examples/hello-addon`](examples/hello-addon) | Dual CJS/ESM imports and strict scalar boundary checks |
| [`examples/structured-data`](examples/structured-data) | Nested `struct` / `enum` records, `Option`, `Array`, `Map`, and `Json` |
| [`examples/native-class`](examples/native-class) | Stateful `// napi:class` handles, getters/setters, static factories, and `Symbol.dispose` |
| [`examples/callbacks`](examples/callbacks) | Synchronous callbacks, stored threadsafe functions, and JS exception propagation |
| [`examples/async-file`](examples/async-file) | `pub async fn` native file I/O, `AbortSignal` cancellation, and error recovery |
| [`examples/binary-processing`](examples/binary-processing) | Owned `Bytes` (`Buffer`) vs. zero-copy synchronous `NapiBufferView` and TypedArrays |
| [`examples/native-tasks`](examples/native-tasks) | C worker-pool jobs (`NapiTask`), cancellation, and composition with MoonBit `async fn` |
| [`examples/worker-tasks`](examples/worker-tasks) | Pure MoonBit CPU-bound computation in isolated Node worker process pools (`NapiWorker`) |
| [`examples/streams`](examples/streams) | `NapiAsyncIterator` input/output, backpressure, cancellation, and Web `ReadableStream` |

To materialize any example into a standalone directory and run its test suite:

```bash
moon run examples/setup.mbtx examples/hello-addon ../my-hello-addon
cd ../my-hello-addon
pnpm test
```

---

## 🧪 Development & Validation

This repository pins **MoonBit `0.10.17+093cb8f9c`**, **CMake `4.4.4`**, and **`moonbitlang/async@0.22.4`**. Common repository validation commands:

```bash
moon run scripts/toolchain-check.mbtx   # Verify pinned MoonBit, CMake, and host toolchain
moon check                              # Typecheck all MoonBit packages
moon test                               # Run unit, whitebox, and blackbox tests
moon run scripts/docs-check.mbtx        # Verify Markdown links and documentation gates
moon run scripts/release-check.mbtx     # Verify module version and lockfile hygiene
moon run scripts/examples-test.mbtx     # Package the CLI and build/test all 9 standalone examples
```

See [Development Workflow](docs/en/development.md) and [Validation Record](docs/validation.md) for the complete verification suite.

---

## 📄 License & Third-Party Notices

### Project License

`napi-mbt` is licensed under the **[MIT License](LICENSE)**.

### Third-Party Components & Licenses

`napi-mbt` vendors parser sources under [`internal/syntax/vendor/`](internal/syntax/VENDOR.md) and embeds C headers and async runtime glue inside [`internal/assets/data/resources.json`](internal/assets/data/resources.json). When packaging `napi-mbt-cli` release archives ([`scripts/package-cli.mbtx`](scripts/package-cli.mbtx)), all corresponding license files are distributed under the archive's `licenses/` directory:

| Component | Version / Source | Usage in `napi-mbt` | License | Repository / Archive License Path |
| :--- | :--- | :--- | :--- | :--- |
| **Tree-sitter C Runtime** | `v0.26.8` (`cd5b087c`) · [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter) | Vendored C parser runtime for MoonBit AST analysis | **MIT** | [`internal/syntax/vendor/TREE-SITTER-LICENSE`](internal/syntax/vendor/TREE-SITTER-LICENSE) (`licenses/TREE-SITTER-LICENSE`) |
| **Unicode Character Database** | Unicode Consortium (bundled in Tree-sitter) | Unicode character tables in Tree-sitter lexer | **Unicode-DFS-2016** | [`internal/syntax/vendor/runtime/unicode/LICENSE`](internal/syntax/vendor/runtime/unicode/LICENSE) (`licenses/UNICODE-LICENSE`) |
| **Tree-sitter MoonBit Grammar** | Commit `190881df` (ABI 15) · [unmbt/tree-sitter-moonbit](https://github.com/unmbt/tree-sitter-moonbit) | Vendored MoonBit grammar tables (`parser.c` / `scanner.c`) | **Apache-2.0 AND MIT** | [`internal/syntax/vendor/GRAMMAR-LICENSE`](internal/syntax/vendor/GRAMMAR-LICENSE) (`licenses/GRAMMAR-LICENSE`) |
| **Node-API Headers (`node-api-headers`)** | `v1.9.0` · [nodejs/node-api-headers](https://github.com/nodejs/node-api-headers) | Embedded `node_api.h` & `js_native_api.h` headers for standalone builds | **MIT** | Embedded in [`internal/assets/data/resources.json`](internal/assets/data/resources.json) (`licenses/NODE-API-LICENSE`) |
| **MoonBit Async Runtime (`moonbitlang/async`)** | `v0.22.4` · [moonbitlang/async](https://github.com/moonbitlang/async) | Embedded native async event-loop bridge and runtime support | **Apache-2.0** | Embedded in [`internal/assets/data/resources.json`](internal/assets/data/resources.json) (`licenses/MOONBIT-ASYNC-LICENSE`) |
| **libuv Headers & Declarations** | [libuv/libuv](https://github.com/libuv/libuv) | Embedded libuv declarations for Node.js event-loop integration | **MIT** | Embedded in [`internal/assets/data/resources.json`](internal/assets/data/resources.json) (`licenses/LIBUV-LICENSE`) |
