# Architecture & Development Guide

This document dives deep into the internal architecture of `napi-mbt`. It is intended for those who wish to understand the inner workings of the project, debug its systems, or contribute to its development.

## 1. System Architecture Overview

`napi-mbt` is designed to be a highly performant and automated bridge between V8 JavaScript engine and MoonBit, facilitated through Node-API (N-API).

The architecture is broadly split into three distinct layers:
1. **The Toolchain (`@unmbt/napi-mbt-cli`)**: A Node.js CLI tool that controls AST extraction and orchestrates compilation.
2. **The MoonBit N-API Core**: Contains memory primitives and the ID-based function dispatcher mechanism.
3. **The C Trampoline (`stub.c`)**: A minimal C component bridging Node.js C ABI and the MoonBit runtime interface.

### The Problem with C <-> MoonBit Interaction

Node-API is a C interface. When Node.js wants to call a Native Addon, it expects a C-style function pointer matching the signature:
`napi_value cb(napi_env env, napi_callback_info info)`.

MoonBit does not (yet) allow arbitrary closures to be exported directly as C function pointers.
To solve this, we implemented the **ID-Based Dispatcher (Trampoline)** architecture.

## 2. The Trampoline Architecture

Instead of exporting many dynamic function pointers, we utilize a statically mapped router.

1. **AST Code Generation**: The CLI parses `/// @napi` functions using `web-tree-sitter`. It generates a massive `match` statement inside `_napi_bindings.mbt` called the `moonbit_napi_dispatcher`. Each exported function is assigned a unique integer `id`.
2. **Initialization**: When Node.js loads the addon, `napi_register_module_v1` is invoked inside `stub.c`. It runs MoonBit's core init block `moonbit_napi_init()`.
3. **Registration**: MoonBit registers functions via `moonbit_napi_create_func(env, name, id)`. Inside this method, it registers the JS string property to point to the generic C function `c_generic_trampoline`.
4. **Invocation (The Trampoline)**: When JavaScript calls the native function, `c_generic_trampoline` is invoked. It retrieves the registered `id` from the V8 external data, and routes the call to the central `moonbit_napi_dispatcher(id, env, info)` back inside MoonBit.

```mermaid
sequenceDiagram
    participant JS as JavaScript
    participant C as stub.c (c_generic_trampoline)
    participant Dispatcher as MoonBit Dispatcher
    participant Target as Target MoonBit Function
    JS->>C: call nativeMethod()
    C->>Dispatcher: moonbit_napi_dispatcher(id, env, info)
    Dispatcher->>Target: Call actual logic
    Target-->>Dispatcher: Returns raw NapiValue
    Dispatcher-->>C: Return NapiValue
    C-->>JS: Yields result to JS
```

## 3. The Dual-GC Problem and Safety

MoonBit and V8 both have independent Garbage Collectors. Passing memory between them is dangerous, as one GC might collect memory while the other is still holding a reference to it.

- `Int`, `Double`, `Bool` are primitive value types and carry zero GC risk.
- `String` involves memory copying. Node-API handles extraction of the string into MoonBit-managed memory.
- `Bytes` uses `napi_create_buffer_copy`. The data is fully cloned from V8 memory into MoonBit memory, severing dependencies between the two GCs.
- `NapiBufferView` requires extreme caution. We bypass the GC boundary by extracting the direct address pointer of the V8 buffer (`napi_get_buffer_info`). However, V8's Moving GC might invalidate this pointer. Hence, `NapiBufferView` is structurally safe **only** when used synchronously. It does not escape the current call stack.

## 4. Contributing to `napi-mbt`

### Testing Locally
The testing framework operates without needing to publish packages.
Simply run `npm test`. The test runner triggers `node --test scripts/test.js`, testing bidirectional integration across the AST generator, the C linkage, and the MoonBit runtime logic.

### Building Optional Dependencies
To debug the `napi-mbt prepublish` generation logic:
```bash
node cli/bin/napi-mbt.js prepublish
```
This generates the target JSON layouts within the `npm/` folder. Ensure your changes to `index.js` correctly resolve the generated layouts.

### Adding New Types (e.g., Object, Array)
1. In `cli/src/generate.js`: Implement the TypeScript AST mapper to properly emit the `.d.ts` typing.
2. In `cli/src/generate.js`: Enhance the `mbt` generation block to parse JS types to their corresponding internal definitions.
3. In `lib.mbt`: Implement the extraction primitives utilizing underlying raw N-API signatures (`napi_get_named_property`, etc.).
