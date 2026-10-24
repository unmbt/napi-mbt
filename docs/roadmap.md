# Development priorities

The current foundation includes error short-circuiting, one validated generator,
strict configuration/loaders, isolated builds, owned/borrowed value conversion,
Date/Set/Symbol/synchronous iterators,
classes/callbacks, a version-pinned Node-driven async host, owned binary types,
native tasks, isolated process pools, typed Promise inputs and Web streams.
Mooncakes installation, standalone examples, persistent isolated workspaces and
source/toolchain/output build receipts are implemented.

Further work follows this order:

1. Keep correctness and developer diagnostics ahead of API expansion: retain
   native consumer, worker, cancellation, sanitizer and installation gates.
2. Add APIs only with a defined representation, ownership/error contract and
   matching TypeScript consumers. Generic exports and additional container kinds
   remain unsupported until their semantics are designed and tested.
3. Continue reproducible hosted compiler image work. Build receipts reject stale
   inputs, generated outputs, toolchains and binaries; they are local consistency
   records, not signed provenance attestations.
4. Expand platforms only with real builds, install tests and memory validation.
   Seven native profiles now have gates, and the low-level/advanced API change
   has passed the hosted Linux ARM64, macOS and musl jobs.
5. Optimize from measured workloads: cache invalidation, stream throughput and
   pool startup are useful next measurements. The recorded conversion
   results are local measurements, not a blanket zero-overhead claim.

The async patch is tied to 0.22.4, including exact source checksums. Updating it
requires reviewing upstream scheduler/ownership changes and repeating I/O,
cancellation, worker teardown and sanitizer tests. It must remain confined to
isolated build workspaces.

WASI, cross compilation, shared MoonBit closures, shared-memory TypedArrays,
generic exports and Node Readable-specific adapters remain outside this
implementation. External/zero-copy memory, DataView and BigInt typed arrays,
low-level JS handles, N-API 8/9/10 helpers and encoded typed TSFN are now part
of the supported runtime surface.
