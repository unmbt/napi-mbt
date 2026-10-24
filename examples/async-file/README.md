# async-file

Read a file asynchronously, cancel a pending operation, then recover with another request.
The `twice` export also waits for a typed JavaScript Promise. N-API 8 is required.

From the napi-mbt repository root:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/async-file ../async-file
cd ../async-file
pnpm test
```

The destination is a standalone project; the installed CLI supplies runtime boilerplate.
See `lib.mbt` for the MoonBit API, `test.mjs` for CJS/ESM behavior, and
`consumer.mts` for valid and invalid TypeScript calls.

```js
import addon from './index.mjs';
await addon.twice(Promise.resolve(21)); // 42
const failure = new Error('upstream');
try { await addon.twice(Promise.reject(failure)); }
catch (error) { console.assert(error === failure); }
const controller = new AbortController();
const pending = addon.suspend(1000, { signal: controller.signal });
controller.abort(new Error('cancel'));
await pending.catch(error => console.log(error.message));
```

`NapiJsPromise[Int]` validates the resolved value and preserves rejection identity.
`AbortSignal` is the generated trailing async option. See the runnable test for
cancellation followed by recovery and [Promise inputs](../../docs/js-promises.md)
for lifetime/disposal rules.

中文：`twice` 在 MoonBit 异步函数内等待 JS Promise，类型不符会拒绝结果，JS rejection
保留原对象。取消通过最后一个参数 `{ signal }` 传入，详见[异步说明](../../docs/zh/async.md)。
