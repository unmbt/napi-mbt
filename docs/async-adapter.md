# Embedded MoonBit async runtime

The native builder supports a Node-driven host for `moonbitlang/async` **0.22.4**.
Enable the `async` feature with N-API **8** or newer. Async cleanup hooks are
required so worker termination can wait for cancellation and outstanding OS I/O.

The adapter is embedded in the native CLI. `scripts/sync-async-adapter.mbtx`
derives it from the pinned dependency and the reviewed sources in
`internal/async-adapter/`. The manifest records the dependency version, patch
version, Apache-2.0 license and FNV-1a 64-bit checksums of normalized UTF-8 source
before and after each change. These checksums detect mismatched or changed
sources; they are not a cryptographic signature. The libuv declarations retain
their MIT license separately.

The builder validates every source checksum before applying changes to its
isolated workspace. Missing dependencies, a different version, a changed upstream
file, existing adapter files or conflicting package imports produce an error.
The user's source manifests, compiler flags, native inputs and dependency cache
are preserved. The successful addon is replaced only after the new build links.

Each environment owns its scheduler, event loop, timers and C worker pool. The
public adapter package inside the isolated dependency exposes `Loop::new`,
`submit`, `step`, `next_wake`, `cancel_all`, `close` and `Task::cancel`. Every
operation temporarily activates the correct context and restores the previous
one. Reentering a main event loop while that context is active is rejected.

Node's libuv timer drives one bounded scheduling round at a time. Immediately
ready work yields between rounds; pending OS I/O is polled within two milliseconds
and timer deadlines control the next wakeup. Idle environments have no active
timer, allowing Node to exit. This baseline favors a simple, inspectable driver;
the benchmark suite should measure scheduling latency and polling overhead.
CPU-bound MoonBit code still occupies its JavaScript thread while executing.

MoonBit code, finalizers and reference counts execute on the owning JS thread
under the addon's recursive lock. Background workers only execute C I/O jobs.
Windows cancels synchronous I/O with `CancelSynchronousIo`. POSIX enables deferred
pthread cancellation only inside cancellable syscall regions and joins the job's
thread before reuse. The adapter installs no process signal handlers and does not
change Node's signal mask.

Environment shutdown cancels tasks, keeps driving their cancellation cleanup,
waits for I/O jobs, closes the loop, releases MoonBit state and finally completes
the N-API asynchronous cleanup hook. Cancellation does not discard buffers while
the OS may still access them.

`scripts/async-adapter-test.mbtx` tests independent contexts and cancellation.
`scripts/async-runtime-test.mbtx` builds a real addon and checks timers, filesystem,
TCP, task groups, JS heartbeats, worker termination, unchanged dependency sources,
version rejection and checksum rejection. Run the sanitizer variant with
`moon run scripts/sanitizer-test.mbtx` for the parser and native memory gates.
