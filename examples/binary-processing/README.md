# binary-processing

Bytes owns an independent copy; BufferView can mutate only during its synchronous call.
`typed_arrays.mbt` covers signed/unsigned 8/16/32-bit arrays, clamped uint8,
float32/float64 and ArrayBuffer. These owned conversions require N-API 7.

From the napi-mbt repository root:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/binary-processing ../binary-processing
cd ../binary-processing
pnpm test
```

The destination is a standalone project; the installed CLI supplies runtime boilerplate.
See `lib.mbt` for the MoonBit API, `test.mjs` for CJS/ESM behavior, and
`consumer.mts` for valid and invalid TypeScript calls.

```js
import addon from './index.mjs';
const source = Buffer.from([1, 2]);
const copy = addon.copy(source);
addon.increment(source);                 // source[0] === 2; copy[0] === 1
const words = addon.int16(new Int16Array([-32768, 32767]));
const floats = addon.float64(new Float64Array([NaN, -0, Infinity]));
const backing = addon.arrayBuffer(new ArrayBuffer(4));
```

Use `NapiBufferView` only within the synchronous call. Use owned binary wrappers
for storage or async results. TypedArray inputs must have the exact element type;
subarray offsets are respected and output buffers are independent. See
[advanced-api](../advanced-api/README.md) for DataView, BigInt arrays and external
shared memory, and [types](../../docs/types.md) for detached/shared-store rejection.

中文：`Bytes` 和 TypedArray 包装会复制；`NapiBufferView` 在当前同步调用中直接读写 JS
Buffer，不可保存到异步任务。需要 JS 和原生侧共享 backing store 时参阅高级示例。
