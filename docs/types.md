# Exported value types

Exported functions use `pub fn` and `#export_name("jsName")`. Types are resolved
across the package before generation. Unknown types and generic exports fail
with a source filename and line; no type falls back to Buffer.

| MoonBit | JavaScript | Contract |
| --- | --- | --- |
| Int / Int32 | number | Finite integer in the signed 32-bit range |
| Double | number | IEEE values, including NaN and infinities |
| Int64 / UInt64 | bigint | N-API 6; overflow throws RangeError with `ERR_NAPI_BIGINT_RANGE` |
| String | string | Exact UTF-16 code units, including NUL and lone surrogates |
| Bytes | Buffer | Owned copy; N-API 7 for backing-store checks |
| NapiBufferView | Buffer | Direct synchronous borrowed parameter; invalid after the call |
| Option[T] / T? | T or null | Missing, undefined and null become None; None returns null |
| Array[T] | Array | Recursive conversion; sparse slots behave as undefined |
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
