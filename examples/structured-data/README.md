# structured-data

Optional input fields become explicit null output fields; enum payloads use tag and args.
This example also covers records, JSON, tuples, Date, Symbol, Set and synchronous
iterator input/output. It requires N-API 5 for Date.

From the napi-mbt repository root:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/structured-data ../structured-data
cd ../structured-data
pnpm test
```

The destination is a standalone project; the installed CLI supplies runtime boilerplate.
See `lib.mbt` for the MoonBit API, `test.mjs` for CJS/ESM behavior, and
`consumer.mts` for valid and invalid TypeScript calls.

```js
import addon from './index.mjs';
addon.records({ moon: { name: 'Moon' } }); // { moon: { name: 'Moon', age: null } }
addon.tuple(['Moon', 2, undefined]);       // ['Moon', 2, null]
addon.json({ nested: [1, 'two', null] });
addon.tomorrow(new Date('2026-01-01T00:00:00Z')); // Jan 2 in UTC
addon.set(new Set([3, 1, 3]));             // Set { 3, 1 }
[...addon.range(3)];                      // [0, 1, 2]
addon.first([7, 8]);                      // 7; closes the iterator early
```

`Map[String, T]` takes a JS object record, not `new Map()`. JSON rejects bigint,
undefined and cycles. Tuples require the exact length. Date copies the timestamp;
Symbol preserves identity. `first` closes its input even when it stops early,
so a generator's `finally` runs. Iterators remain tied to their Node environment.

中文：`Map` 对应普通对象；可选字段输出为 `null`；元组严格检查长度；Date 复制时间值，
Symbol 保留身份。`first` 提前返回也会关闭迭代器。详见[类型说明](../../docs/zh/types.md)。
