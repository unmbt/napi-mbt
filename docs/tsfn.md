# Native threads and Threadsafe Functions

For the owner-thread typed queue wrapper, use the [advanced addon example](../examples/advanced-api/README.md)
and [typed API guide](en/advanced-api.md#typed-tsfn). Its encoder is a MoonBit
closure executed synchronously by `call`; that wrapper cannot run on arbitrary
native producer threads. The C fixture below demonstrates actual native threads.

The existing low-level TSFN API requires N-API 4. A producer thread may pass
C-owned payloads through `napi_call_threadsafe_function`; it must not access
MoonBit objects, reference counts or JS handles. Convert values and invoke JS
only in the owner-thread callback. The callback must also reclaim a payload
when Node supplies `env == NULL` during shutdown.

Acquire a thread count before sharing a TSFN with another producer, and release
it when the producer finishes. A `napi_closing` result ends that producer's use
of the handle; do not call it or release it again. A queue-full result leaves
the rejected payload with its producer. Never block the owner JS thread waiting
for a producer that is itself waiting for the JS thread to drain the queue.

`moon run scripts/tsfn-test.mbtx` builds an addon using the runtime's actual C
wrappers. Native Windows/pthread producers exercise blocking and nonblocking
delivery, a deterministic full queue, acquire/release, abort and 12 forced
worker shutdowns. Atomic counters check owner-thread delivery, exactly one
finalizer per TSFN and full C payload reclamation. The shutdown test also covers
V8 termination racing a callback before Node enters its null-environment drain
path. No producer thread accesses MoonBit RC or runtime state.

Run the same fixture under the configured memory checker with:

```sh
moon run scripts/sanitizer-test.mbtx <cli-path> --fixture tsfn
```

Node 22/24/26 and Windows/Linux sanitizer jobs run this fixture in CI. Local
results and platform limits are recorded in [implementation progress](implementation-progress.md).
