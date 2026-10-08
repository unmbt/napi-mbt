# Architecture & Development Guide

This document dives deep into the internal architecture of `napi-mbt`. It is intended for those who wish to understand the inner workings of the project, debug its systems, or contribute to its development.

## 1. System Architecture Overview

`napi-mbt` is designed to be a highly performant and automated bridge between V8 JavaScript engine and MoonBit, facilitated through Node-API (N-API).

The architecture is broadly split into three distinct layers:
1. **The Toolchain (`napi-mbt-cli`)**: A standalone MoonBit executable with a statically linked Tree-sitter parser. It handles generation and native compilation without Node/npm.
2. **The MoonBit N-API Core**: Contains memory primitives and type-conversion helpers.
3. **The C glue (`napi_glue.c`)**: Creates one Node-API callback for each export.


Node-API is a C interface. When Node.js wants to call a Native Addon, it expects a C-style function pointer matching the signature:
`napi_value cb(napi_env env, napi_callback_info info)`.

MoonBit does not (yet) allow arbitrary closures to be exported directly as C function pointers.
To solve this, the generator emits one adapter and C wrapper for each exported function.

## 2. Per-export C wrapper architecture

The CLI generates one MoonBit adapter and one N-API callback for every `#export_name("...")` function. Calls enter the matching adapter directly without a global dispatcher or function IDs.

1. **Initialization**: Node.js invokes `napi_register_module_v1` in `napi_glue.c`, which calls `moonbit_init()`.
2. **Registration**: Generated C glue creates one N-API callback per export and attaches the exact export name to the module exports object.

## 3. The Dual-GC Problem and Safety

MoonBit and V8 both have independent Garbage Collectors. Passing memory between them is dangerous, as one GC might collect memory while the other is still holding a reference to it.

- `Int`, `Double`, `Bool` are primitive value types and carry zero GC risk.
- `String` involves memory copying. Node-API handles extraction of the string into MoonBit-managed memory.
- `Bytes` uses `napi_create_buffer_copy`. The data is fully cloned from V8 memory into MoonBit memory, severing dependencies between the two GCs.
- `NapiBufferView` requires extreme caution. We bypass the GC boundary by extracting the direct address pointer of the V8 buffer (`napi_get_buffer_info`). However, V8's Moving GC might invalidate this pointer. Hence, `NapiBufferView` is structurally safe **only** when used synchronously. It does not escape the current call stack.

## 4. Contributing to `napi-mbt`

### Testing Locally
The testing framework operates without needing to publish packages.
Build the CLI with `moon build --target native --release cmd/napi-mbt-cli`, then build the root addon with `moon run --target native --release cmd/napi-mbt-cli -- build --release`. Run `moon run scripts/ci-regression-test.mbtx` for native command tests in an environment without Node/npm and `moon test --target native` for unit tests. Finally, `node --test scripts/test.js` loads the already-built root and fixture addons.

### Building Optional Dependencies
To debug the `napi-mbt prepublish` generation logic:
```bash
napi-mbt-cli prepublish
```
This generates the target JSON layouts within the `npm/` folder. The generated `index.cjs` and `index.mjs` resolve these platform packages.

### Adding New Types (e.g., Object, Array)
1. In `generator/strict.mbt`: Extend the exported-signature validation and type model.
2. In `generator/outputs.mbt`: Extend adapters and TypeScript declarations; update the embedded templates in `internal/assets/data/resources.json` when runtime support changes.
3. In `lib.mbt`: Implement the extraction primitives utilizing underlying raw N-API signatures (`napi_get_named_property`, etc.).

### Troubleshooting

The build uses MoonBit, CMake, and the platform C compiler. Check `napi-mbt.json` and install the selected CMake, clang/GCC, or MSVC toolchain.
