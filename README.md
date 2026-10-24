<div align="center">

[English](README.md) | [简体中文](README.zh.md)

# ⚡ napi-mbt

*A Native Node-API (N-API) Toolchain, Code Generator, and Runtime for MoonBit*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-f97316?style=flat-square)](https://www.moonbitlang.com/)
[![Mooncakes](https://img.shields.io/badge/mooncakes.io-unmbt%2Fnapi--mbt-7c3aed?style=flat-square)](https://mooncakes.io/docs/unmbt/napi-mbt)
[![CI](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml/badge.svg?branch=master)](https://github.com/unmbt/napi-mbt/actions/workflows/build-and-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square)](docs/support.md)
[![Node-API](https://img.shields.io/badge/ABI-Node--API%20v4--v10-339933?style=flat-square)](docs/support.md)

</div>

---

## 📖 Overview

**`napi-mbt`** is an end-to-end toolchain and runtime library that compiles [MoonBit](https://www.moonbitlang.com/) native packages (`preferred_target = "native"`) into ABI-stable Node.js `.node` addons.

Without writing C/C++ boilerplate by hand, `napi-mbt` parses your MoonBit package with an embedded Tree-sitter MoonBit grammar and automatically produces:

- **Native Node-API C glue** with strict boundary validation and deterministic resource cleanup
- **Compiled `.node` native addons** via `moon build --target native` and host C toolchains (MSVC, GCC, or Clang)
- **Dual-mode JavaScript loaders** supporting both CommonJS (`index.cjs`) and ES Modules (`index.mjs`)
- **Strict TypeScript declarations** (`index.d.ts`) matching your MoonBit signatures
- **Cross-platform npm package manifests** for per-platform binary distribution (`optionalDependencies`)

Crucially, **`napi-mbt-cli` is a standalone native binary**. You can install it directly via Mooncakes (`moon install`) or GitHub Releases—running the CLI itself does not require Node.js or npm.

---

## ✨ Key Highlights

| Capability | Description |
| :--- | :--- |
| 🎯 **Zero-Boilerplate Exports** | Export `pub fn` and `pub async fn` with `#export_name("...")`, alongside owned `pub struct` and `pub enum` value types. Native classes are configured cleanly in `napi-mbt.json`. |
| 🛡️ **Strict Boundary Validation** | Rejects `NaN`, `±Infinity`, fractional floats passed to integers, out-of-range 32-bit/64-bit numbers, and invalid UTF-16/Buffer inputs at the C boundary before entering MoonBit. |
| ⚡ **Full Async & Concurrency Stack** | Supports cancellable `pub async fn` Promises (`moonbitlang/async@0.22.4` + libuv with `AbortSignal`), native C worker pool tasks (`nativeTasks`), isolated MoonBit worker process pools (`workerTasks`), awaited JS Promises (`NapiJsPromise`), and demand-driven async streams (`NapiAsyncIterator`). |
| 🧱 **Safe Classes & Callbacks** | Native classes include constructors, static factories, getters/setters, methods, and explicit idempotent `.dispose()`. Callbacks support typed MoonBit signatures `(Args) -> Ret raise`, returned closures with `.dispose()`, and threadsafe functions (`NapiCallback`). |
| 🔒 **Isolated, Cached Builds** | Compiles inside isolated workspaces without mutating user source files. Includes content-addressed build caching, watch mode (`--watch`), and native symbol collision inspection (`nm` / `dumpbin`). |
| 📦 **Precise ABI & Engine Ranges** | Targets **N-API v4** by default and automatically raises the required N-API level (up to v10) only when higher-level features are used, computing the exact `engines.node` intersection in `package.json`. |

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
| External/zero-copy Buffer, ArrayBuffer, DataView and BigInt typed arrays | **7** | Node 10.16.0+ (intersected with loader mode) |
| `pub async fn`, `NapiTask`, `NapiJsPromise`, `NapiAsyncIterator`, async host cleanup | **8** | `>=12.22.0 <13 \|\| >=14.17.0 <15 \|\| >=15.12.0 <16 \|\| >=16.0.0` |
| Freeze/seal and type tags | **8** | Node 12.22.0+ (intersected with loader mode) |
| `Symbol.for`, SyntaxError and module filename | **9** | Node 18.0.0+ (intersected with loader mode) |
| Property keys, external strings and ArrayBuffer-backed Buffer views | **10** | Node 22.0.0+ (intersected with loader mode) |
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
napi-mbt-cli build
```

Generated projects declare `"preferred_target": "native"` in `moon.mod`, default to **N-API 4**, and enable both CommonJS and ESM loaders.

### 3. Write MoonBit & Call from JavaScript / TypeScript

Define your exports in `lib.mbt`:

```moonbit
///|
pub(all) struct Summary {
  label : String
  total : Int
}

///|
#export_name("summarize")
pub fn summarize(label : String, values : Array[Int]) -> Summary raise {
  if label.is_empty() {
    fail("label must not be empty")
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
| `Double`, `Float`, `Bool`, `Unit` | `number`, `boolean`, `void` | Preserves IEEE-754 values, including `NaN` and `±Infinity`. |
| `String` | `string` | Direct UTF-16 string conversion without intermediate UTF-8 transcoding. |
| `Bytes` | `Buffer` | Owned byte copy across the boundary (`N-API 7`); safe to store and return from async functions. |
| `NapiBufferView` | `Buffer` | Zero-copy synchronous borrow (`N-API 7`); valid only during the synchronous call frame. |
| `NapiObject` / `NapiFunction` / `NapiArray` | JavaScript object/function/array | Environment-bound low-level handles for properties, calls, construction, prototypes and `instanceof`; never cross async or worker boundaries. |
| `NapiInt8Array` / `NapiUint8Array` / `NapiUint8ClampedArray` / `NapiInt16Array` / `NapiUint16Array` / `NapiInt32Array` / `NapiUint32Array` / `NapiFloat32Array` / `NapiFloat64Array` / `NapiArrayBuffer` | Corresponding JavaScript TypedArrays / `ArrayBuffer` | Owned typed-array and `ArrayBuffer` copies; 8/16-bit elements use range-safe MoonBit integer arrays. |
| `NapiBigInt64Array` / `NapiBigUint64Array` / `NapiDataView` | BigInt64Array / BigUint64Array / DataView | Owned copies; detached and shared backing stores are rejected. |
| `NapiExternal` and external helpers | External / Buffer / ArrayBuffer / string | Explicit caller-managed pointers or GC-retained Bytes backing stores; use owned wrappers when a copy is required. |
| `NapiDate` | `Date` | Copies the ECMAScript millisecond time value and rejects invalid dates at the boundary (N-API 5). |
| `NapiSymbol` | `symbol` | Retains symbol identity with an environment-owned reference; the description is used only when creating one. |
| `NapiSet[T]` | `Set<T>` | Copies insertion order through JavaScript Set and recursively applies the same converter. |
| `T?`, `Array[T]`, `Map[String, T]`, `(A, B, ...)`, `Json` | `T \| null`, `Array<T>`, `Record<string, T>`, `[A, B, ...]`, `JsonValue` | Recursive structural validation; `Option::None` maps to `null` (and accepts `null` or `undefined` on input). |
| `pub struct` / `pub enum` | Object / Discriminated Union | Exported structs map to typed JS objects; enums map to variant name string or `{ tag: "Variant", args: [...] }` discriminated unions. |
| Configured Class (`napi-mbt.json`) | `class` with `dispose()` | Native handle wrapping with constructors, static factories, properties, methods, and deterministic disposal. |
| `(Args) -> Ret raise` / `NapiCallback` | `(...args) => Ret` | Supports synchronous call-scoped invocations, returned closures with `dispose()`, and threadsafe functions (`N-API 4`). |
| `pub async fn(...) -> T` | `Promise<T>` (with `{ signal?: AbortSignal }`) | Runs on the embedded `moonbitlang/async@0.22.4` + libuv loop (`N-API 8`) with cooperative cancellation. |
| `NapiJsPromise[T]` | `Promise<T>` | Awaits JavaScript Promises inside MoonBit `async fn` exports with typed resolution. |
| `NapiAsyncIterator[T]` | `AsyncIterableIterator<T>` & `ReadableStream<T>` | Demand-driven streaming input/output with backpressure and early consumer cancellation (`return()`). |
| `NapiTypedThreadsafeFunction[T]` | Threadsafe producer to JS callback | Encodes `T` to copied Bytes on a producer thread; the owner-thread callback receives a Buffer. |
| `NapiIterator[T]` | `IterableIterator<T>` | Consumes JavaScript Iterables synchronously and releases callback resources on close or exhaustion. |
| `nativeTasks` / `workerTasks` (`napi-mbt.json`) | `Promise<T>` / Worker Pool | Offloads C jobs to the libuv threadpool (`nativeTasks`) or pure MoonBit jobs to isolated Node worker process pools (`workerTasks`). |

---

## 🛠️ CLI Reference

```text
napi-mbt-cli <command> [directory] [options]
```

| Command | Description |
| :--- | :--- |
| `init <dir>` | Create the official addon template (`--name <name>`, `--force`). |
| `generate [dir]` | Generate bindings and loaders (`--check` to validate without writing files). |
| `build [dir]` | Build the native addon in isolation (`--release`, `--watch`, `--no-cache`, `--dry-run`, `--verbose`, `--target <t>`, `--output-dir <p>`). |
| `clean [dir]` | Remove this project's persistent build cache (`--cache`). |
| `doctor [dir]` | Check the native compiler, linker, and platform SDK (`--json`). |
| `prepublish [dir]` | Validate release artifacts and prepare npm platform package metadata (`--target <t>`). |
| `targets` | List supported host target profiles. |

Common flags:
- `--help`, `-h`: Print help information.
- `--version`, `-V`: Print CLI version.

### How the Isolated Build Pipeline Works

1. **Source & Export Analysis**: `napi-mbt-cli` parses your `.mbt` files (`#export_name`) and `napi-mbt.json`, checking supported signatures and inferring the minimum N-API version.
2. **Non-Invasive Workspace Staging**: The CLI prepares an isolated build workspace under `.napi-mbt/cache/` (or a temporary directory) without modifying your source tree.
3. **Native Compilation & Linking**: `moon build --target native` compiles MoonBit packages and stubs to native artifacts, linking with the generated Node-API C shim (`napi_glue.c`), embedded `node-api-headers`, and (when async is used) the `moonbitlang/async` libuv bridge.
4. **Symbol & Loader Emission**: Exported symbols are verified against C runtime collisions (`nm`/`dumpbin`), `.node` binaries are copied to the artifact directory, and `index.cjs`, `index.mjs`, and `index.d.ts` are emitted.

---

## 📚 Documentation & Examples

### Documentation Guides

| Topic | Guide |
| :--- | :--- |
| **Getting Started & CLI Usage** | [Usage Guide](docs/en/usage.md) · [Build & Loader Pipeline](docs/build.md) |
| **Platform & ABI Policy** | [Support Policy](docs/support.md) · [Platform Validation](docs/platforms.md) · [Validation Record](docs/validation.md) |
| **Type System & Objects** | [Type Mapping](docs/types.md) · [Classes & Callbacks](docs/classes-callbacks.md) · [Threadsafe Functions](docs/tsfn.md) |
| **Async, Streams & Workers** | [Async Functions](docs/async.md) · [Async Adapter](docs/async-adapter.md) · [JS Promises](docs/js-promises.md) · [Async Streams](docs/streams.md) · [Native Tasks](docs/native-tasks.md) · [Worker Pools](docs/workers.md) |
| **Engineering & Benchmarks** | [Software Design Description](docs/sdd.md) · [Advanced APIs](docs/en/advanced-api.md) · [Performance Benchmarks](docs/performance.md) · [Development Workflow](docs/en/development.md) · [Roadmap](docs/roadmap.md) |

### Standalone Examples

The [`examples/`](examples/README.md) directory contains 10 standalone addon projects covering the main usage patterns, with executable JS tests and TypeScript consumers:

| Example | Demonstrated Capabilities |
| :--- | :--- |
| [`examples/hello-addon`](examples/hello-addon) | Dual CJS/ESM imports and strict scalar boundary checks |
| [`examples/structured-data`](examples/structured-data) | Structs/enums, optional fields, records, JSON, tuples, Date, Symbol, Set and synchronous iterators |
| [`examples/native-class`](examples/native-class) | Stateful class handles configured in `napi-mbt.json`, getters/setters, a factory export, and `.dispose()` |
| [`examples/callbacks`](examples/callbacks) | Stored synchronous callbacks, returned closures and JS exception propagation |
| [`examples/async-file`](examples/async-file) | Native file I/O, `AbortSignal` cancellation, recovery and JS Promise input |
| [`examples/binary-processing`](examples/binary-processing) | Owned `Bytes` (`Buffer`) vs. zero-copy synchronous `NapiBufferView` and TypedArrays |
| [`examples/native-tasks`](examples/native-tasks) | C worker-pool jobs (`nativeTasks`), cancellation, and composition with MoonBit `async fn` |
| [`examples/worker-tasks`](examples/worker-tasks) | Pure MoonBit CPU-bound computation in isolated Node worker process pools (`workerTasks`) |
| [`examples/streams`](examples/streams) | `NapiAsyncIterator` input/output, backpressure, cancellation, and Web `ReadableStream` |
| [`examples/advanced-api`](examples/advanced-api) | Environment-bound low-level handles, External/zero-copy values, owned DataView/BigInt arrays, N-API 8/9/10 helpers, and typed TSFN |

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
moon run scripts/examples-test.mbtx     # Package the CLI and build/test all 10 standalone examples
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
