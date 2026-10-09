# Usage Guide (napi-mbt)

This document provides a comprehensive guide on how to install and use `@unmbt/napi-mbt`, initialize a new project, write MoonBit business logic, compile the native addon, and consume it in Node.js / TypeScript.

---

## Table of Contents

- [1. Prerequisites & Installation](#1-prerequisites--installation)
  - [1.1 Environment Requirements](#11-environment-requirements)
  - [1.2 Installing the CLI](#12-installing-the-cli)
- [2. Quickstart: From Init to Execution](#2-quickstart-from-init-to-execution)
  - [2.1 Project Initialization (`init`)](#21-project-initialization-init)
  - [2.2 Project Structure Breakdown](#22-project-structure-breakdown)
  - [2.3 One-Click Build (`build`)](#23-one-click-build-build)
  - [2.4 Running and Testing](#24-running-and-testing)
- [3. Writing MoonBit Addon Code](#3-writing-moonbit-addon-code)
  - [3.1 Code Organization](#31-code-organization)
  - [3.2 The `#export_name("...")` Attribute](#32-the-export_name-attribute)
  - [3.3 Supported Data Types & Type Mapping](#33-supported-data-types--type-mapping)
  - [3.4 Code Examples by Type](#34-code-examples-by-type)
    - [Scalar Numbers & Booleans (Int / Double / Bool)](#scalar-numbers--booleans-int--double--bool)
    - [Strings (String)](#strings-string)
    - [Binary Buffer Copy (Bytes)](#binary-buffer-copy-bytes)
    - [High-Performance Zero-Copy Buffer (NapiBufferView)](#high-performance-zero-copy-buffer-napibufferview)
  - [3.5 Error Handling & Exceptions (raise -> JS Error)](#35-error-handling--exceptions-raise---js-error)
  - [3.6 Advanced Features (Promise, BigInt, Threadsafe Function)](#36-advanced-features-promise-bigint-threadsafe-function)
- [4. CLI Commands Reference](#4-cli-commands-reference)
  - [`napi-mbt-cli init`](#napi-mbt-cli-init)
  - [`napi-mbt-cli generate`](#napi-mbt-cli-generate)
  - [`napi-mbt-cli build`](#napi-mbt-cli-build)
  - [`napi-mbt-cli prepublish`](#napi-mbt-cli-prepublish)
  - [`napi-mbt-cli targets`](#napi-mbt-cli-targets)
- [5. Consuming from Node.js & TypeScript](#5-consuming-from-nodejs--typescript)
  - [5.1 CommonJS (CJS)](#51-commonjs-cjs)
  - [5.2 ES Modules (ESM)](#52-es-modules-esm)
  - [5.3 TypeScript Support](#53-typescript-support)
- [6. Cross-Platform Packaging & npm Distribution](#6-cross-platform-packaging--npm-distribution)
- [7. Configuration Reference (`napi-mbt.json`)](#7-configuration-reference-napi-mbtjson)
- [8. Troubleshooting & FAQ](#8-troubleshooting--faq)

---

## 1. Prerequisites & Installation

### 1.1 Environment Requirements

Before starting, ensure your system has the following tools installed:

1. **MoonBit Toolchain**:
   - The `moon` command must be in your `PATH`.
   - Download and installation details can be found on the [official MoonBit website](https://www.moonbitlang.com/).
2. **C Compiler & CMake**:
   - **CMake**: >= 3.20.
   - **Windows**: Microsoft Visual Studio with "Desktop development with C++" workload (provides MSVC, `vswhere.exe`, and `lib.exe`).
   - **Linux**: GCC or Clang, along with `make` or `ninja`.
   - **macOS**: Xcode Command Line Tools (`clang`).
3. **Node.js**:
   - Node.js 18 or newer for running tests and executing addons.
   - *Note: The CLI itself is a standalone, statically linked MoonBit native executable. Code generation and native builds do not invoke Node.js.*

### 1.2 Installing the CLI

Recommended via `moon install`:

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
```

Or via official installation scripts:

- **Unix (Linux / macOS)**:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.sh | bash
  ```
- **Windows (PowerShell)**:
  ```powershell
  irm https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.ps1 | iex
  ```

Verify installation:

```bash
napi-mbt-cli --help
```

---

## 2. Quickstart: From Init to Execution

### 2.1 Project Initialization (`init`)

Run `napi-mbt-cli init` to create a standard MoonBit Node-API project:

```bash
napi-mbt-cli init my-addon
cd my-addon
```

Or in the current directory:

```bash
napi-mbt-cli init . --name my-addon
```

### 2.2 Project Structure Breakdown

The initialized project structure looks like this:

```text
my-addon/
├── .github/
│   └── workflows/
│       └── build.yml       # GitHub Actions CI matrix build workflow
├── test/
│   ├── smoke.cjs           # CommonJS smoke test
│   └── smoke.mjs           # ES Module smoke test
├── lib.mbt                 # [Core] MoonBit source code where you write logic
├── moon.mod                # MoonBit module definition
├── moon.pkg                # MoonBit package configuration (foreign_library, stubs, flags)
├── napi-mbt.json           # napi-mbt configuration (targets, N-API version, etc.)
├── package.json            # npm package metadata
├── bump.config.json        # Release bumping configuration
├── stub.c                  # Native springboard C stub
├── napi_types.mbt          # Node-API opaque pointers and type definitions
├── napi_bindings.mbt       # Node-API C FFI functions
├── napi_features.mbt       # Helpers for advanced features (Promise, BigInt, etc.)
├── napi_runtime.mbt        # Runtime data marshallers (Int, String, Buffer, etc.)
├── napi_exports.mbt        # [Auto-generated] MoonBit adapter functions
├── napi_glue.c             # [Auto-generated] C callbacks and module initialization
├── napi_manifest.json      # [Auto-generated] Export metadata manifest
├── index.d.ts              # [Auto-generated] TypeScript type declarations
├── index.cjs               # [Auto-generated] CJS dynamic loader for platform binaries
├── index.mjs               # [Auto-generated] ESM loader
└── .gitignore              # Git ignore rules for build caches and artifacts
```

> [!IMPORTANT]
> **Editing guidelines**:
> - Write your application logic in `lib.mbt` (or additional `.mbt` files).
> - `napi_exports.mbt`, `napi_glue.c`, `index.d.ts`, `index.cjs`, `index.mjs`, and `napi_manifest.json` are **auto-generated**. They will be overwritten on every build/generation run. **Do not modify them manually**.

### 2.3 One-Click Build (`build`)

In the project root, run:

```bash
napi-mbt-cli build
```

Or create an optimized release build:

```bash
napi-mbt-cli build --release
```

**What happens automatically**:
1. **AST Parsing**: Scans all `.mbt` files in the directory for `#export_name("...")` annotations.
2. **Code Generation**: Generates `napi_exports.mbt`, `napi_glue.c`, `index.d.ts`, and JS loaders.
3. **Package Synchronization**: Updates `moon.pkg` options (native stubs, exported symbols, flags).
4. **Native Compilation**: Invokes `moon build --target native`.
5. **C Linking via CMake**: Links MoonBit objects and C glue code to produce the final `.node` addon:
   - Windows: `artifacts/win32-x64-msvc/napi_mbt.node`
   - Linux: `artifacts/linux-x64-gnu/napi_mbt.node`
   - macOS: `artifacts/darwin-arm64/napi_mbt.node`

### 2.4 Running and Testing

Verify with the included smoke tests:

```bash
node test/smoke.cjs
node test/smoke.mjs
```

Or run a quick one-liner:

```bash
node -e "const addon = require('./index.cjs'); console.log('2 + 3 =', addon.mbt_add(2, 3));"
```

Output:
```text
2 + 3 = 5
```

---

## 3. Writing MoonBit Addon Code

### 3.1 Code Organization

- **Single file**: You can place all functions in `lib.mbt`.
- **Multiple files**: You can create arbitrary `.mbt` files in the root folder (e.g. `math.mbt`, `crypto.mbt`, `image.mbt`).
  - All `.mbt` files (excluding `_test.mbt`, `_wbtest.mbt`, and internal `napi_*` files) are scanned automatically.
- **Block style**: Follow MoonBit conventions by separating top-level blocks with `///|`.

### 3.2 The `#export_name("...")` Attribute

Annotate any `pub fn` with `#export_name("exported_name")`:

```moonbit
///|
#export_name("add")
pub fn my_add(a : Int, b : Int) -> Int {
  a + b
}
```

- **Name**: The string in `#export_name("...")` defines the JavaScript property name (`addon.add(...)`) and TypeScript function name in `index.d.ts`.
- **Identifiers**: Must be valid C and JavaScript identifiers, avoiding reserved keywords.
- **Signatures**: Must have explicit parameter and return types. Generics and `async fn` cannot be directly exported.

### 3.3 Supported Data Types & Type Mapping

| MoonBit Type | JavaScript / TypeScript Type | Boundary Behavior |
| :--- | :--- | :--- |
| `Int` | `number` | 32-bit signed integer passed through registers. |
| `Double` | `number` | 64-bit float passed through registers. |
| `Bool` | `boolean` | JavaScript standard boolean. |
| `String` | `string` | UTF-8 encoded string safely marshaled between V8 and MoonBit. |
| `Bytes` | `Buffer` | **Deep Copy**. Cloned between Node.js Buffer and MoonBit GC heap. 100% safe. |
| `NapiBufferView` | `Buffer` | **Zero-Copy unmanaged pointer**. Direct memory access to Node.js Buffer. Parameter only. |
| `Unit` | `void` | Represents no return value. |

### 3.4 Code Examples by Type

#### Scalar Numbers & Booleans (Int / Double / Bool)

```moonbit
///|
#export_name("calc_add")
pub fn calc_add(a : Int, b : Int) -> Int {
  a + b
}

///|
#export_name("circle_area")
pub fn circle_area(radius : Double) -> Double {
  3.141592653589793 * radius * radius
}

///|
#export_name("invert_flag")
pub fn invert_flag(flag : Bool) -> Bool {
  !flag
}
```

#### Strings (String)

```moonbit
///|
#export_name("greet")
pub fn greet(name : String) -> String {
  "Hello, " + name + "! Welcome to MoonBit Native Addon."
}
```

#### Binary Buffer Copy (Bytes)

Use `Bytes` when creating or receiving an independent binary payload:

```moonbit
///|
#export_name("reverse_buffer")
pub fn reverse_buffer(data : Bytes) -> Bytes {
  let len = data.length()
  let arr = Array::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    arr[i] = data[len - 1 - i]
  }
  Bytes::from_array(arr)
}
```

#### High-Performance Zero-Copy Buffer (NapiBufferView)

For image manipulation, encryption, or streaming large binary buffers where deep copies are too expensive, use `NapiBufferView`:

```moonbit
///|
#export_name("increment_buffer_inplace")
pub fn increment_buffer_inplace(view : NapiBufferView) -> Unit {
  let len = view.length()
  for i = 0; i < len; i = i + 1 {
    let current = view.load8(i)
    view.store8(i, (current + 1) & 0xFF)
  }
}
```

Methods available on `NapiBufferView`:
- `view.length() -> Int`: Returns the byte length.
- `view.load8(offset : Int) -> Int`: Reads one byte at `offset` (0..255).
- `view.store8(offset : Int, val : Int) -> Unit`: Writes one byte to `offset`.

> [!WARNING]
> **Safety rules for NapiBufferView**:
> 1. `NapiBufferView` is only valid during the synchronous execution of your function.
> 2. The generated wrapper automatically calls `view.invalidate()` when the function returns.
> 3. **Never cache or store `NapiBufferView` into global variables or asynchronous contexts.**

### 3.5 Error Handling & Exceptions (raise -> JS Error)

MoonBit functions with error annotations (`raise` or `!`) are automatically caught:

```moonbit
///|
suberror MathError {
  DivisionByZero
} derive(Show)

///|
#export_name("safe_divide")
pub fn safe_divide(a : Int, b : Int) -> Int!MathError {
  if b == 0 {
    raise MathError::DivisionByZero
  }
  a / b
}
```

When invoked with `addon.safe_divide(10, 0)`, the adapter catches the MoonBit error, triggers `napi_throw_error`, and cleanly emits a JavaScript `Error: MathError::DivisionByZero` catchable with standard JS `try { ... } catch (err)`.

Type errors in arguments (e.g. passing a string when `Int` is expected) are intercepted by the C layer and throw standard JavaScript `TypeError`s, preventing crashes.

### 3.6 Advanced Features (Promise, BigInt, Threadsafe Function)

The included `napi_features.mbt` provides higher-level primitives:

- **Promise**: `napi_promise_new`, `napi_promise_resolve`, `napi_promise_reject`.
- **BigInt**: `napi_bigint_from_int64`, `napi_bigint_to_int64` (requires `"napiVersion": 6` in `napi-mbt.json`).
- **Threadsafe Function**: Safely schedule callbacks back to the Node event loop (requires `"napiVersion": 4`).

---

## 4. CLI Commands Reference

- `napi-mbt-cli init [dir] [--name <name>] [--force]`: Initialize a new project.
- `napi-mbt-cli generate [dir] [--check]`: Generate adapters, C glue, TypeScript declarations, and loaders without building binaries.
- `napi-mbt-cli build [dir] [--release] [--dry-run]`: Full build pipeline into `.node` binaries.
- `napi-mbt-cli prepublish [dir]`: Prepare multi-platform npm packaging under `npm/`.
- `napi-mbt-cli targets`: List supported target platforms.

---

## 5. Consuming from Node.js & TypeScript

### 5.1 CommonJS (CJS)

```javascript
const addon = require('./index.cjs');
console.log(addon.calc_add(10, 20));
```

### 5.2 ES Modules (ESM)

```javascript
import addon, { calc_add, greet } from './index.mjs';
console.log(calc_add(10, 20));
```

### 5.3 TypeScript Support

`index.d.ts` is kept in sync on every generation and build. You get full autocompletion, type checks, and parameter documentation out of the box.

---

## 6. Cross-Platform Packaging & npm Distribution

`napi-mbt` uses the standard **Optional Dependencies** architecture:
1. The root package contains the loaders (`index.cjs`, `index.mjs`, `index.d.ts`) and platform `optionalDependencies`.
2. Each platform binary is packaged into a separate npm package (e.g. `@my-scope/my-addon-win32-x64-msvc`).
3. Running `napi-mbt-cli prepublish` sets up the `npm/` directory and optional dependencies automatically.

---

## 7. Configuration Reference (`napi-mbt.json`)

```json
{
  "napiVersion": 1,
  "generator": "auto",
  "builder": "auto",
  "targets": [
    "win32-x64-msvc",
    "darwin-arm64",
    "linux-x64-gnu"
  ],
  "features": [],
  "cjs": true,
  "esm": true
}
```

---

## 8. Troubleshooting & FAQ

- **Windows MSVC error (`lib.exe is required`)**: Install Visual Studio C++ desktop build tools.
- **Target mismatch error**: Ensure your current platform is listed in `napi-mbt.json`'s `"targets"` array.
- **Complex structs**: Pass serialized JSON strings or Buffer byte streams, then parse within MoonBit.
