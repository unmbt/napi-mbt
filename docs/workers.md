# Isolated MoonBit workers

`workerTasks` selects synchronous exports for execution in child Node processes:

```json
{
  "napiVersion": 8,
  "workerTasks": ["compute"],
  "workerPool": { "size": 2, "maxQueue": 64, "idleTimeoutMs": 30000 }
}
```

The generated package API changes `compute(args)` into
`compute(args, { signal? }): Promise<Result>`. Its implementation remains a
normal MoonBit `pub fn`. There is no shared MoonBit heap, and no separate MoonBit
executable to build. The internal Node entry loads the resolved `.node` directly.
Use the generated CJS/ESM package entry: directly loading the `.node` deliberately
keeps synchronous behavior and does not provide the pool. N-API 8 is required for
branded native cleanup registration; no async MoonBit dependency is needed.

Inputs and outputs must be owned value types: scalars, bigint integers, strings,
Bytes, owned TypedArrays/ArrayBuffer, JSON and nested arrays/maps/tuples/value
structs/enums. Classes, callbacks, raw JS handles, borrowed views and streams are
rejected. Before enqueueing, generated native adapters validate and copy input
using the same type IR as ordinary calls. Getters run at submission; later input
mutation cannot change queued work. Node's advanced IPC serialization preserves
bigint, UTF-16 code units, Buffer and TypedArray values.

Each addon in each Node environment owns one lazy pool, shared by its generated
CJS and ESM entry points. Each child executes one job at a time. `size` ranges
from 1 to 64; `maxQueue` from 0 to 100000; `idleTimeoutMs` from 1 to 2147483647.
Queue overflow rejects with `ERR_NAPI_WORKER_QUEUE_FULL`. Idle children/timers
do not keep the parent alive. The generated `napi_workers.cjs` and
`napi_worker_entry.cjs` belong in the npm main package and build receipt.

Cancelling queued work removes it. Cancelling active work kills its process and
starts replacements only as needed, after the old process exits. A crashing job
rejects with `ERR_NAPI_WORKER_EXIT`; it is never automatically replayed because
the computation may have side effects. Subsequent work can run in a replacement.
Remote errors preserve name, message, stack and string/number code, without
preserving object identity. Parent-side validation exceptions and AbortSignal
reasons retain their original identity. Cancellation cannot roll back external
side effects already performed by a child.

Normal exit and `worker_threads` forced teardown terminate owned children. A
native cleanup hook supplements JavaScript events, including when a busy child
cannot process IPC disconnect. Windows holds a process handle; Linux uses pidfd
where supported. The POSIX fallback checks that the pid is still an unreaped
child before signalling it. User computations must not intentionally detach
additional processes that outlive the managed child.

See the [standalone example](../examples/worker-tasks/README.md).
`scripts/workers-test.mbtx` exercises simultaneous computation, global isolation,
input snapshots, CJS/ESM identity, errors/cancellation, idle shutdown, native
teardown with JS exit listeners removed, pnpm pack/offline installation, and TS
positive/negative consumers. Platform test results are recorded only after runs.
