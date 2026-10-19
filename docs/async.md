# Async exports

Pin `moonbitlang/async@0.22.4` in `moon.mod`, import the packages you use,
and set `"napiVersion": 8` in `napi-mbt.json`. The CLI validates the exact
dependency version and source checksums, then adapts a private build copy.
It does not change the dependency cache or install process signal handlers.

```moonbit
#export_name("delay")
pub async fn delay(ms : Int, value : String) -> String {
  @async.sleep(ms)
  value
}
```

The generated declaration is
`delay(ms: number, value: string, options?: { signal?: AbortSignal }): Promise<string>`.
Options follow every declared argument; pass `undefined` for an omitted
optional MoonBit argument when supplying options. Class methods and static
methods can be async; constructors and accessors must be synchronous.

Argument and return conversion errors reject the Promise. Business errors
use `ERR_NAPI_CALL`; JS callback exceptions preserve the original thrown value,
including primitives, even when caught and rethrown after a suspension.
`NapiReference` owns a value across handle scopes and provides explicit,
idempotent `dispose()`; a raw `NapiValue` is only valid in its current scope.

```js
const controller = new AbortController()
const result = addon.delay(100, 'ready', { signal: controller.signal })
controller.abort(new Error('cancelled'))
await result // rejects with that same Error
```

An already aborted signal prevents business execution. Cancellation rejects
once with `signal.reason` (or an `AbortError` with `ABORT_ERR` if absent), then
drains task groups and pending native I/O. Completion, failure and cancellation
share one settlement flag. Listeners and persistent references are released on
every path. Cancellation is cooperative: synchronous MoonBit computation must
return or reach a suspension before Node can dispatch another event.

Use owned `Bytes` across async boundaries; exporting borrowed `NapiBufferView`
in an async signature is rejected. Values are converted before scheduling.
The driver runs MoonBit and its reference counting on the owning Node thread,
under the addon lock. Only C I/O and waiting run in background threads.
Node callback scopes deliver Promise microtasks without requiring an unrelated
JS timer. Standard stream handles/buffers and scheduler state are per environment.

Worker shutdown cancels tasks and waits for I/O cleanup without calling JS or
settling Promises in the closing environment. See [adapter details](async-adapter.md)
and [executed validation](validation.md). Run `moon run scripts/async-exports-test.mbtx`
and the async variant of `scripts/lifecycle-sanitizer.mbtx` to exercise the native addon.
