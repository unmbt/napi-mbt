# Low-level JavaScript and advanced Node-API

The advanced surface is intended for synchronous, hand-written bindings that
need direct access to JavaScript values. It is available from the generated
runtime package; no generated TypeScript parameter is added for `NapiEnv`.

Start with the [runnable advanced addon](../../examples/advanced-api/README.md).
From the repository root, install this checkout with `moon install ./cmd/napi-mbt-cli`,
then run `moon run examples/setup.mbtx examples/advanced-api ../advanced-api`.
The example declares N-API 10 and needs Node 22.14+ or Node 24/26.

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

`keys` includes inherited enumerable string keys; for own keys use
`napi_object_keys`. `prototype` currently requires an object prototype and
rejects a null prototype. Named property helpers use NUL-terminated names;
use the value-key APIs for embedded NUL. A nested scope's handles expire when
closed; escape the one value you need before closing, and use `errdefer` for cleanup
on failure (see `escapeValue` in the example).

TypeScript exposes `NapiValue`/`NapiExternal` as `unknown`, `NapiObject` as
`object`, and `NapiArray` as `unknown[]`. Narrow them with `Buffer.isBuffer`,
`instanceof` or property checks. The generator cannot infer a low-level object's
shape from its function body; use an owned struct for that contract.

## External and zero-copy memory

`NapiExternal::new(env, pointer)` wraps a caller-managed `UnmanagedBuffer` and
does not free the pointer. The helpers below retain the supplied MoonBit Bytes
until JavaScript garbage collection releases the value:

```moonbit
let buffer = napi_external_buffer(env, bytes)
let arraybuffer = napi_external_arraybuffer(env, bytes)
let (latin1, copied) = napi_external_string_latin1(env, bytes)
```

For Buffer/ArrayBuffer, dynamically allocated Bytes (for example `@utf8.encode`)
are shared and JavaScript can mutate them. Static Bytes literals are copied to
writable memory before exposure. Treat retained dynamic Bytes as shared storage,
not an immutable snapshot, and keep them off background MoonBit threads. Use owned
`NapiUint8Array`, `NapiArrayBuffer` or `NapiDataView` when a copy is required.
`napi_buffer_from_arraybuffer` creates an ArrayBuffer-backed Buffer view on
N-API 10 and validates offset/length in the native stub.

External strings interpret each byte as Latin-1: `b"caf\xe9"` is `café`, whereas
UTF-8 encoding `café` is not the same byte sequence. Do not mutate a string's
backing bytes through any alias. Node may copy the string and report `copied`;
the finalizer releases the retained reference in both cases. Runtimes that
disallow external buffers report an error; use an owned wrapper there.

The [native token example](../../examples/advanced-api/native.c) has static lifetime.
`NapiExternal::new` does not install resource cleanup. Likewise, the instance-data
helpers store a caller-managed pointer without a finalizer. Reserve the addon-owned
slot explicitly; do not overwrite another component's pointer or finalizer.

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

Signature types are inferred. Calls inside function bodies are not feature-scanned:
declare the relevant features explicitly in `napi-mbt.json` to enforce their
minimum versions before generation. Otherwise unsupported C stubs return an error:

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

`NapiTypedThreadsafeFunction[T]` runs its encoder synchronously on the calling
MoonBit owner thread. It copies the returned `Bytes` to a C-owned queue payload;
the later JS callback receives a Node Buffer. Do not send this wrapper or its
encoder closure to an arbitrary native thread. Native producers use the
[low-level C TSFN API](../tsfn.md) instead:

```moonbit
let tsfn = NapiTypedThreadsafeFunction::new(
  env,
  callback,
  32,
  fn(_value : Int32) { b"payload" },
)
errdefer (ignore(tsfn.abort()) catch { _ => () })
let status = tsfn.try_call(42)
ignore(tsfn.release())
// Handle status without touching tsfn again after this final release.
ignore(status)
```

Creation owns one producer count; each successful `acquire` needs a matching
`release`. `abort` stops delivery and releases one count, not all producer counts.
Do not use a producer after release/abort or after receiving `Closing` (which also
ends that producer's ownership). The wrapper does not enforce linear ownership.

Prefer `try_call`/`Nonblocking`: blocking on a full queue from the owner thread
can deadlock delivery. `Accepted`, `QueueFull` and `Closing` describe acceptance,
not completion of the JS callback. Retry/drop policy belongs to the caller; all
rejected payloads are freed. Abort/shutdown drains queued C payloads without
invoking JS if Node supplies a null environment. The example's `boundedTsfn`
shows a queue of size one filling before the synchronous export returns.

## Validation and failure behavior

All C statuses become `NapiError`; pending JavaScript exceptions retain their
original identity. The generator rejects a low-level handle before writing
outputs if it is nested or crosses an async/worker boundary. Validate changes
with the native checks, generator snapshots, owned-binary consumer and sanitizer
fixtures listed in the [SDD](../sdd.md).
`moon run scripts/advanced-api-test.mbtx <cli-path>` checks the runnable example,
GC/worker teardown and NodeNext/Bundler consumers. Add
`--fixture advanced-api` to `scripts/sanitizer-test.mbtx <cli-path>` for ASan.
