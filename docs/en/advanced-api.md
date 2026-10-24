# Low-level JavaScript and advanced Node-API

The advanced surface is intended for synchronous, hand-written bindings that
need direct access to JavaScript values. It is available from the generated
runtime package; no generated TypeScript parameter is added for `NapiEnv`.

## Environment-bound values

An exported function may request the current environment and low-level handles:

```moonbit
///|
#export_name("readName")
pub fn read_name(env : NapiEnv, object : NapiObject) -> String raise {
  get_String(env, object.get(env, "name"))
}
```

The JavaScript signature is `readName(object: object): string`. `NapiObject`,
`NapiFunction`, `NapiArray`, `NapiValue` and `NapiExternal` are direct values;
they cannot be nested in owned structs, promises, streams or worker payloads,
and cannot cross an async boundary. Store a long-lived JavaScript value in a
`NapiReference` instead.

`NapiObject` supports `get`, `set`, `has`, `define_property`, `keys`,
`prototype` and `is_instance_of`. `NapiFunction` supports `call` and
`new_instance`; `NapiArray` supports `new`, `length`, `get` and `set`. Use
`napi_value_type`, `napi_strict_equal`, `napi_global` and `napi_undefined` for
general value operations. `NapiHandleScopeGuard` and
`NapiEscapableHandleScopeGuard` must be closed on the environment thread.

## External and zero-copy memory

`NapiExternal::new(env, pointer)` wraps a caller-managed `UnmanagedBuffer` and
does not free the pointer. The helpers below retain the supplied MoonBit Bytes
until JavaScript garbage collection releases the value:

```moonbit
let buffer = napi_external_buffer(env, bytes)
let arraybuffer = napi_external_arraybuffer(env, bytes)
let (latin1, copied) = napi_external_string_latin1(env, bytes)
```

The backing store is shared and JavaScript can mutate it. Use owned
`NapiUint8Array`, `NapiArrayBuffer` or `NapiDataView` when a copy is required.
`napi_buffer_from_arraybuffer` creates an ArrayBuffer-backed Buffer view on
N-API 10 and validates offset/length in the native stub.

`NapiDataView` is an owned byte snapshot:

```moonbit
let view = get_NapiDataView(env, input)
let output = set_NapiDataView(env, view)
```

It is safe to return from a synchronous or asynchronous export. Owned
`NapiBigInt64Array` and `NapiBigUint64Array` have the same `new`, `length` and
`to_array` API as the other typed-array wrappers. Detached ArrayBuffers and
SharedArrayBuffer-backed views are rejected by all owned binary converters.

## N-API 8/9/10 helpers

The following wrappers are available with feature/version validation:

- N-API 8: `napi_object_freeze`, `napi_object_seal`, `napi_type_tag_object`,
  and `napi_check_object_type_tag`.
- N-API 6: `napi_set_instance_data` and `napi_get_instance_data`.
- N-API 9: `napi_symbol_for`, `napi_syntax_error`,
  `napi_throw_syntax_error`, and `napi_module_file_name`.
- N-API 10: `napi_property_key`, `napi_external_string_latin1`, and
  `napi_buffer_from_arraybuffer`.
- Runtime inspection: `napi_version`, `napi_adjust_external_memory`,
  `napi_detach_arraybuffer` and `napi_is_detached_arraybuffer`.

Declare the feature in `napi-mbt.json` when you want the CLI to enforce its
minimum version before generation:

```json
{
  "napiVersion": 10,
  "features": [
    "external_string",
    "property_key",
    "buffer_from_arraybuffer"
  ]
}
```

## Typed TSFN

`NapiTypedThreadsafeFunction[T]` is the high-level typed wrapper for a producer
that runs away from the JavaScript thread. The encoder returns `Bytes`; the
runtime copies those bytes to a C-owned payload and the JS callback receives a
Node Buffer:

```moonbit
let tsfn = NapiTypedThreadsafeFunction::new(
  env,
  callback,
  32,
  fn(_value : Int32) { b"payload" },
)
ignore(tsfn.try_call(42))
ignore(tsfn.acquire())
ignore(tsfn.release())
```

`call` accepts `Nonblocking` or `Blocking`; `try_call` is nonblocking. Queue
full and closing results are returned as `NapiTsfnStatus`, so the producer owns
the policy for retry or drop. `abort` stops the TSFN and drains the producer
count. Neither the encoder closure's MoonBit value nor a JavaScript handle is
invoked from the producer thread.

## Validation and failure behavior

All C statuses become `NapiError`; pending JavaScript exceptions retain their
original identity. The generator rejects a low-level handle before writing
outputs if it is nested or crosses an async/worker boundary. Validate changes
with the native checks, generator snapshots, owned-binary consumer and sanitizer
fixtures listed in the [SDD](../sdd.md).
