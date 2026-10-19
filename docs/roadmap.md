# Development priorities

The current foundation includes error short-circuiting, one validated generator,
strict configuration/loaders, isolated builds, owned/borrowed value conversion,
classes/callbacks and a version-pinned Node-driven async host.

Further work follows this order:

1. Keep correctness and developer diagnostics ahead of API expansion: retain
   native consumer, worker, cancellation, sanitizer and installation gates.
2. Add APIs only with a defined representation, ownership/error contract and
   matching TypeScript consumers. Generic exports and additional container kinds
   remain unsupported until their semantics are designed and tested.
3. Extend engineering guarantees: binary/source build receipts, reproducible
   hosted compiler images and an isolated incremental object cache. Current
   prepublish checks do not establish binary provenance from source hashes.
4. Expand platforms only with real builds, install tests and memory validation.
   Current releases remain the three platforms in the support matrix.
5. Optimize from measured workloads: async timer scheduling, dependency copying
   and repeated builds are useful next measurements. The recorded conversion
   results are local measurements, not a blanket zero-overhead claim.

The async patch is tied to 0.22.4, including exact source checksums. Updating it
requires reviewing upstream scheduler/ownership changes and repeating I/O,
cancellation, worker teardown and sanitizer tests. It must remain confined to
isolated build workspaces.
