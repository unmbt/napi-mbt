# JavaScript Promise inputs

An exported MoonBit function can accept `NapiJsPromise[T]` and asynchronously
wait for a typed JavaScript value:

```moonbit
#export_name("twice")
pub async fn twice(value : NapiJsPromise[Int]) -> Int {
  value.wait() + value.wait()
}
```

Its JS signature is `twice(value: Promise<number>, options?: { signal?:
AbortSignal }): Promise<number>`. Like other async exports it requires N-API 8
and the pinned `moonbitlang/async@0.22.4` dependency. An actual JS Promise is
required; arbitrary thenables are rejected. This is an input wrapper; use
`async fn` for Promise output. Borrowed BufferView values are forbidden inside it.

The resolution is converted once with the ordinary typed converter, including
depth, cycle, numeric and binary ownership checks. Repeated/concurrent waits
share that result. Rejected objects and primitive values preserve identity in
the same Node environment; validation errors also reject the exported Promise.
Waiting suspends the MoonBit coroutine until a JS reaction wakes it, without
polling. It never blocks the Node event loop.

The wrapper retains the input Promise and its reactions until settlement,
explicit `dispose()` or environment shutdown. Cancellation of its last active
waiter disposes the pending subscription. It does not cancel the original JS
operation. Later reactions become inert, without introducing unhandled Promise
rejections. Disposing twice is safe; further waits reject. Completed values can
be awaited again until disposal. A retained rejection keeps its value reference
for repeated waits, then releases it with the wrapper.

Wrappers are environment-bound and cannot be passed to process-pool tasks.
Environment teardown releases persistent references without invoking JS. Tests
in `scripts/js-promises-test.mbtx` cover resolution/rejection, binary/nested
values, repeated waits, cancellation with late settlement, resource baselines,
worker teardown and TypeScript positive/negative consumers.
