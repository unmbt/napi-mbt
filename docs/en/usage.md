# Usage Guide (napi-mbt)

This document provides a comprehensive guide on how to integrate and use `@unmbt/napi-mbt-cli` to develop native Node.js addons with MoonBit.

## 1. Environment Requirements

Before you start, ensure your environment meets the following dependencies:

- **Node.js**: Version 18 or newer.
- **MoonBit Toolchain**: Make sure `moon` is available in your PATH. You can install it from the [official MoonBit website](https://www.moonbitlang.com/).
- **C Compiler**: The toolchain compiles C glue code (`stub.c`).
  - **Windows**: Microsoft Visual Studio with C++ Desktop Development (MSBuild/lib.exe).
  - **macOS / Linux**: GCC or Clang.

## 2. CLI Commands

The `@unmbt/napi-mbt-cli` exposes the `napi-mbt` bin command.

### `napi-mbt build [--release]`
Executes the full pipeline to build your native module:
1. Triggers the internal AST parser to scan all `.mbt` files in the current folder for functions tagged with `/// @napi`.
2. Generates the `_napi_bindings.mbt` file containing routing tables and memory conversion implementations.
3. Generates the `index.d.ts` file containing exactly matching TypeScript definitions.
4. Executes `moon build --target native` internally.
5. C links the Node-API and MoonBit artifacts to produce the `.node` binary.
6. Moves the resulting `.node` file to `artifacts/[platform]-[arch]/napi_mbt.node`.

**Flag:** Append `--release` for optimized builds.

### `napi-mbt prepublish`
Automates the structural setup for cross-platform Node distribution.
It reads your root `package.json`, generates `optionalDependencies` logic, and outputs target packages in the `npm/` directory (e.g., `npm/win32-x64/package.json`).
It also creates an intelligent `index.js` loader in the root directory that dynamically loads the correct `.node` package depending on the host's operating system in runtime.

## 3. The `/// @napi` Macro & Supported Types

To expose a MoonBit function to JS, simply document it with the `/// @napi` tag. The parser strictly supports specific Types that guarantee memory safety and bidirectional conversions.

### Current Supported MoonBit Types:

| MoonBit Type     | TypeScript Type        | Description & Notes |
| ---------------- | ---------------------- | ------------------- |
| `Int`            | `number`               | Converted bidirectionally to 32-bit integers. |
| `Double`         | `number`               | Converted bidirectionally to 64-bit floating point numbers. |
| `Bool`           | `boolean`              | Evaluated properly via JavaScript's boolean values. |
| `String`         | `string`               | Safely transcoded from V8's UTF-8 implementation to MoonBit strings without losing data. |
| `Bytes`          | `Buffer`               | Memory is fully copied across the JS <-> N-API boundary. Excellent for safety, but causes heap allocations. |
| `NapiBufferView` | `Buffer`               | Represents a **Zero-Copy** unmanaged reference to a Node.js Buffer memory space. Perfect for high performance data mutation. |
| `Unit`           | `void`                 | Used when there is no return value. |

### Note on Complex Types
Objects, Arrays, and Promises are **not natively supported yet** in Phase 4 due to ongoing stabilization of MoonBit's dual garbage collector interoperability. These will be natively supported in future releases (Phase 5).

## 4. Error Handling

Errors originating from user input types are handled automatically by the generated wrapper.
If you pass a string to a function expecting an `Int`, the generated bindings will catch it and invoke `napi_throw_error()`, terminating the function safely and emitting a standard JavaScript `TypeError`.

## 5. Working with NapiBufferView (Zero Copy)

For applications handling images, encryptions, or massive datasets, copying arrays into MoonBit causes extreme overhead.

`NapiBufferView` avoids this overhead entirely by giving you raw access to V8's ArrayBuffer memory address.
Because memory is managed entirely by Node.js GC, **never** store a `NapiBufferView` struct into global state, it is strictly only valid during the synchronous execution of your function.

Example usage:
```moonbit
/// @napi
pub fn mutate_image_colors(view : NapiBufferView) -> Unit {
  let length = view.length()
  for i = 0; i < length; i = i + 1 {
    let pixel = view.load8(i)
    // Darken pixel by 10
    view.store8(i, if pixel > 10 { pixel - 10 } else { 0 })
  }
}
```
