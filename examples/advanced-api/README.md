# Low-level and advanced Node-API

This addon demonstrates environment-bound object/function/array handles,
escapable scopes, native External pointers, GC-retained external binary values,
owned DataView and BigInt arrays, N-API 8/9/10 helpers and encoded typed TSFN.
Use Node 22.14+ (or Node 24/26) and a CLI built from this checkout.

From the napi-mbt repository root:

```sh
moon install ./cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/advanced-api ../advanced-api
cd ../advanced-api
pnpm test
```

The destination is a standalone project. `lib.mbt` is intentionally explicit
about the `NapiEnv` parameter: it is hidden from generated JavaScript and
TypeScript signatures, but keeps handle lifetime and thread ownership visible
in MoonBit. The low-level wrappers are synchronous; only the owned binary
roundtrips can safely cross an async or worker boundary.

`externalBuffer` and `externalArrayBuffer` share their backing storage with
JavaScript until garbage collection. `dataViewRoundtrip`, `bigInt64Roundtrip`
and `bigUint64Roundtrip` copy values and reject detached or shared backing
stores. `typedTsfn` encodes an `Int32` to a C-owned Buffer before the callback
runs on the JavaScript thread.

The configuration declares the advanced features used here so the generated schema and
CLI reject an insufficient N-API version before generation. See
[`docs/en/advanced-api.md`](../../docs/en/advanced-api.md) and the
[software design description](../../docs/sdd.md) for the ownership contract.

```js
import addon from './index.mjs';
addon.objectInfo({ name: 'Moon' });          // { name: 'Moon', keyCount: 1 }
addon.callMethod({ add(n) { return n + 40; } }); // 42
addon.makeArray(7);                         // [7, 'from-moonbit']
addon.escapeValue('scoped');                // created inside a nested scope
const token = addon.makeExternal();
addon.externalIdentity(token) === token;    // static C token; not freed by External
const bytes = addon.externalBuffer();
bytes[0] = 69;                              // shared writable backing
addon.externalString();                    // 'café': Latin-1 bytes, not UTF-8
addon.bigInt64Roundtrip(new BigInt64Array([-2n, 3n]));
addon.freezeAndTag({});                     // true
addon.globalSymbol() === Symbol.for('napi-mbt-example');
await new Promise(resolve => addon.typedTsfn(buffer => resolve(buffer.toString()), 42)); // '42'
```

`NapiEnv` is injected; callers do not pass it. Low-level return values have
TypeScript types `unknown`, `object` or `unknown[]`; use runtime narrowing
(`Buffer.isBuffer`, `instanceof`) as shown in `consumer.mts`. Use owned structs
when you want a precise generated object shape.

Dynamic Bytes are shared by external Buffer/ArrayBuffer; static literals use a
writable copy. Never mutate bytes backing an external string. `native.c` uses a
static token to demonstrate External and the addon-owned instance-data slot;
heap resources need their own cleanup design. `typedTsfn` encodes on the owner
thread, delivers later and releases its initial producer count. `boundedTsfn`
demonstrates nonblocking backpressure and abort. Actual native-thread producers
use the [low-level TSFN fixture](../../docs/tsfn.md).

`pnpm test` enables GC. Tests cover copy isolation, offsets, detached/shared views,
Unicode/NUL SyntaxErrors, property descriptors, native token identity, bounded
queues, abort and worker termination. Run memory checks from the repository:

```sh
moon run scripts/sanitizer-test.mbtx <cli-path> --fixture advanced-api
```

中文：这是 N-API 10 独立示例，包含低层对象/函数/数组操作、scope escape、External、
DataView/BigInt 数组和高级 API。typed TSFN 在 MoonBit 所属线程编码，再异步投递 Buffer；
不能把该包装或编码闭包交给任意 C 线程。完整用法和所有权规则见
[中文高级 API 文档](../../docs/zh/advanced-api.md)。
