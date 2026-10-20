# Async iterators and Web streams

Use `NapiAsyncIterator[T]` with N-API 8 and `moonbitlang/async@0.22.4`. The CLI
infers async/stream support and a Node >=18 engine floor (higher N-API choices
retain their higher minimum). See the [standalone example](../examples/streams).

Construct an output with `NapiAsyncIterator::new(produce, close)`. Both closures
are async; `produce` returns `Some(item)` or `None`. `next()` returns the same
optional element in MoonBit; `close()` waits for the one-time close operation.
Keep cleanup bounded. A close callback that never completes also prevents
environment cleanup from completing. Do not enter JavaScript during teardown.

Inputs accept JS AsyncIterable or standard Web ReadableStream. Elements pass
through the same typed conversion as ordinary exports; borrowed BufferView
elements are rejected. Promise/iterator rejections preserve their JS identity.
Use `defer input.close()` in a consuming async function, including early returns.

Outputs implement AsyncIterableIterator: `for await`, `next`, `return` and
`throw`. Concurrent reads serialize; closing cancels the active producer and
settles queued reads as done. Producers run only on demand. Each output supports
one consumption chain, either iteration/manual reads or `toReadableStream()`.
The Web adapter uses highWaterMark 0 and supports `{signal?: AbortSignal}`;
abort reasons retain identity. A ReadableStream input is cancelled and its
reader lock released on close. Arbitrary input iterators must implement a
cooperative `return()`; JavaScript cannot forcibly interrupt their own work.

Streams belong to one Node environment and cannot enter workerTasks. The
internal production coroutine isolates cancellation from consumer promises.
Environment cleanup cancels all producers and releases native references without
calling into a closing JS environment. Web APIs come from Node, without polyfills.
