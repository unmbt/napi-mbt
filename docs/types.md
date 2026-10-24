# Exported value types

Exported functions use `pub fn` and `#export_name("jsName")`. Types are resolved
across the package before generation. Unknown types and generic exports fail
with a source filename and line; no type falls back to Buffer.

| MoonBit | JavaScript | Contract |
| --- | --- | --- |
| Int / Int32 | number | Finite integer in the signed 32-bit range |
| UInt / UInt32 | number | Integer in [0, 4294967295]; no truncation or wrapping |
| Float | number | IEEE float32 rounding; NaN, infinities and negative zero preserved |
| Double | number | IEEE values, including NaN and infinities |
| Int64 / UInt64 | bigint | N-API 6; overflow throws RangeError with `ERR_NAPI_BIGINT_RANGE` |
| String | string | Exact UTF-16 code units, including NUL and lone surrogates |
| Bytes | Buffer | Owned copy; N-API 7 for backing-store checks |
| NapiBufferView | Buffer | Direct synchronous borrowed parameter; invalid after the call |
| NapiObject / NapiFunction / NapiArray | JavaScript object/function/array | Environment-bound low-level handles; direct parameters/returns only, never nested or async/worker-owned |
| NapiUint8Array / NapiInt32Array / NapiUint32Array | Uint8Array / Int32Array / Uint32Array | Owned copies of the exact view type; N-API 7 |
| NapiFloat32Array / NapiFloat64Array | Float32Array / Float64Array | Owned copies preserving IEEE values; N-API 7 |
| NapiBigInt64Array / NapiBigUint64Array | BigInt64Array / BigUint64Array | Owned 64-bit integer copies; N-API 7 |
| NapiDataView | DataView | Owned byte snapshot; N-API 7 |
| NapiArrayBuffer | ArrayBuffer | Owned bytes; independent output backing store; N-API 7 |
| NapiExternal | External | Caller-managed `UnmanagedBuffer` pointer; it is not freed by the wrapper |
| Option[T] / T? | T or null | Missing, undefined and null become None; None returns null |
| Array[T] | Array | Recursive conversion; sparse slots behave as undefined |
| Map[String, T] | Record<string, T> | Own enumerable string keys; safe data properties on output |
| Json | $NapiJson | Finite JSON values; no coercion or `toJSON` invocation |
| (T, U, ...) | [T, U, ...] | Exact array length and recursive positional conversion |
| ordinary struct | object | Required own fields must exist; extra fields are ignored |
| enum without payloads | string | Exact constructor name |
| enum with payloads | `{ tag, args }` | Exact name and tuple arity, including `args: []` for empty variants |
| Unit result | undefined | Unit parameters and nested Unit are rejected |

```moonbit
pub(all) struct Person {
  name : String
  age : Int?
}

pub(all) enum Event {
  Ready
  Message(String)
}

#export_name("echo_person")
pub fn echo_person(value : Person) -> Person { value }
```

`echo_person({ name: "Moon" })` returns `{ name: "Moon", age: null }`.
Event values use `{ tag: "Ready", args: [] }` or
`{ tag: "Message", args: ["hello"] }`. Labeled enum payloads use declaration
order in the `args` tuple.

Option and Array can nest and reference structs/enums in other source files in
the same package. Recursive types accept finite trees. Cycles in converted
fields throw `ERR_NAPI_CYCLE`; excessive nesting throws `ERR_NAPI_DEPTH`.
Reusing an object in separate branches is allowed. Nested Option layers share
the null representation: None and Some(None) both return null. Borrowed
BufferView cannot be nested.

Maps and tuples compose with the other owned value types. Map keys preserve
UTF-16, including NUL and lone surrogates; inherited, non-enumerable and symbol
keys are ignored. `__proto__` is an ordinary data property on output. `Json`
rejects undefined, functions, symbols, bigint, non-finite numbers and cycles,
including these values inside objects or arrays. Sparse JSON arrays are rejected.
Getter exceptions retain their original identity. Numeric conversion never
coerces strings or boxed numbers.

Only a consecutive suffix of Option parameters becomes optional in TypeScript.
For `(a: Int?, b: Int, c: Int?)`, JS must supply the first two arguments. Input
interfaces use a `$Input` suffix and permit missing optional fields. Output
interfaces make every returned field present, with None represented by null.
Both declaration sets come from the same IR.

Conversion and getter failures stop the call before business code runs. Pending
JS exceptions keep their original identity. Output objects use data properties,
including for a field named `__proto__`.

Run `moon run scripts/structured-types-test.mbtx`, then
`moon run scripts/test-runtime.mbtx --structured` for native and TypeScript
consumer coverage. The first command also checks complete artifact snapshots.
Run `moon run scripts/collections-test.mbtx` for UInt/Float, records, tuples and
JSON boundary tests and NodeNext/Bundler declaration checks.

Owned binary wrappers copy on input and output, including zero-length arrays
and views with a nonzero byte offset. Shared backing stores and detached buffers
are rejected. No borrowed pointers or JavaScript handles remain after conversion,
so these wrappers can cross async boundaries. Use `NapiInt32Array::new([1, 2])`
(and the corresponding constructor for each typed array), `length()` and
`to_array()` to work with MoonBit values. `NapiArrayBuffer::from_bytes(bytes)`,
`to_bytes()` and `byte_length()` use immutable MoonBit Bytes. They do not change
the existing Bytes or NapiBufferView APIs. Run
`moon run scripts/owned-binary-test.mbtx` for copy isolation, offset, detached,
shared-store, nested and asynchronous lifetime checks.

External helpers (`napi_external_buffer`, `napi_external_arraybuffer` and
`napi_external_string_latin1`) deliberately retain a MoonBit `Bytes` backing
store until JavaScript GC releases the value. The store is shared and may be
mutated by JavaScript; use an owned wrapper when a copy is required. The
low-level handle and N-API 8/9/10 contracts are documented in
[Advanced APIs](en/advanced-api.md) and the [software design description](sdd.md).
