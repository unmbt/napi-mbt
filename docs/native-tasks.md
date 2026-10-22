# Native background tasks

Configure `nativeTasks` as an export-name to C-symbol object and select N-API 8:

```json
{ "napiVersion": 8, "nativeTasks": { "compute": "compute_task" } }
```

Add `moonbitlang/async@0.22.4` to `moon.mod` (`moon add
moonbitlang/async@0.22.4`) and resolve it before building. Tasks reuse the existing
async Promise/AbortSignal adapter; the CLI supplies its package import in the
isolated workspace. Add your C file to `native-stub`. The generated public API is
`compute(input: Buffer, options?: { signal?: AbortSignal }): Promise<Buffer>`.
MoonBit async functions can call `napi_native_task("compute", input)` with `Bytes`.
Unknown names fail before starting work. Ordinary projects retain their existing
minimum Node/N-API levels. No registry access happens during the build itself.

[napi_native_task.h](../napi_native_task.h) defines ABI version 1. The entry point
is `void compute_task(napi_mbt_task_context *context)`. Read the borrowed input
using `napi_mbt_task_input`; return a copied result using `napi_mbt_task_result`,
or a copied code/message using `napi_mbt_task_error`. Submit once, then return.
An empty result is valid. Returning without a result/error rejects the Promise.
The result helper returns zero on invalid input, duplicate submission or failed
allocation. Contexts and input pointers are valid only until the entry returns.

The execute callback runs on the Node-API worker pool without the MoonBit global
lock. It may use C-owned memory and call the task helpers; it must not call JS,
retain the context, touch MoonBit values/reference counts, or spawn work that
outlives the entry point. C++ entries must use `extern "C"` and catch exceptions:

```cpp
extern "C" void compute_task(napi_mbt_task_context *ctx) {
  try { /* compute; submit copied output */ }
  catch (const std::exception& e) { napi_mbt_task_error(ctx, "E_CPP", e.what()); }
  catch (...) { napi_mbt_task_error(ctx, "E_CPP", "Unknown native exception"); }
}
```

Input is copied before submission, and output is copied on the Node thread.
`AbortSignal` rejects once with the original reason. Queued work is cancelled;
running work observes `napi_mbt_task_cancelled` cooperatively. The caller can
finish before the work does; storage remains alive until actual exit. Environment
cleanup cancels and waits for pending work without invoking JavaScript. A task
that ignores cancellation delays teardown until it returns; native threads are
never forcibly killed. Completion is observed by the async adapter's timer,
which can add a scheduling tick to delivery.

The [standalone example](../examples/native-tasks/README.md) demonstrates both
entry paths. `scripts/native-tasks-test.mbtx` checks real execution, queue/running
cancellation, input snapshots, original rejection identity, recovery, event-loop
responsiveness and repeated worker teardown. Windows ASan and Linux ASan/leak
jobs exercise the same fixture; only executed results are recorded in progress.
