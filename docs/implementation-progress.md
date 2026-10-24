# Implementation progress

Scope: Mooncakes tool distribution; npm distribution for generated addons;
standalone examples; owned value types; TSFN; isolated build caching; native
tasks; process workers; JS promises and streams; seven native platforms.

The current release also includes environment-bound low-level JS handles,
External and zero-copy helpers, DataView and BigInt typed arrays, N-API 8/9/10
wrappers, and an encoded high-level typed TSFN. Their ownership and boundary
contracts are specified in [the SDD](sdd.md).

Commits are made only after their focused checks pass. This work does not publish
to a registry or create a release tag/version.

1. Mooncakes release / development npm metadata separation.
2. Packed Mooncake CLI installation and real consumer acceptance.
3. Six standalone example projects.
4. UInt, Float, maps, JSON and tuples.
5. Owned TypedArray and ArrayBuffer.
6. Real TSFN thread and shutdown tests.
7. Persistent isolated build cache and build receipts.
8. C ABI background tasks.
9. Isolated MoonBit process workers.
10. Typed JavaScript Promise inputs.
11. Async iterators and Web streams.
12. Linux ARM64 and macOS x64 validation.
13. Linux x64/ARM64 musl support.
14. Integration and measured performance.
15. Low-level JS handles, External/zero-copy memory, extended binary types,
    N-API 8/9/10 helpers and encoded typed TSFN.

## Validation

Baseline: strict check, 45 MoonBit tests, release CLI build, native documented
examples and packed/unpacked Mooncake check passed on Windows x64. Platform
and sanitizer results are reported only when actually executed.

- Step 1: development lockfile/source installation and documentation checks passed.
- Step 2: packed CLI installed without Node/npm, extracted source deleted, new
  addon built outside the checkout; CJS/ESM and both TS resolution modes passed.
- Step 3: all six standalone examples passed native builds, CJS/ESM smoke tests
  and positive/negative NodeNext/Bundler consumers using the packed, installed CLI.
- Step 4: strict native check, 47 MoonBit tests, generator snapshots, real Node
  collection boundaries and NodeNext/Bundler types passed. Windows ASan passed
  parser, runtime, structured/collection, class, callback and async suites.
  Linux ASan/leak checks are wired into CI and have not been run locally.
- Step 5: owned Uint8/Int32/Uint32/Float32/Float64 arrays and ArrayBuffer passed
  copy, offset, detached/shared-store, nested and async snapshot consumers,
  NodeNext/Bundler and Windows ASan. Strict check, 48 tests, snapshots and a
  default N-API 4 addon passed. Node 22/24/26 consumers passed in hosted CI.
- Step 6: real native-thread TSFN consumers and Windows ASan passed: 20 rounds
  each of delivery, queue-full and abort, plus 12 worker terminations. All 72
  finalizers ran once, C allocations returned to baseline and callback thread
  checks passed. Strict check, 48 tests and documentation checks passed.
- Step 7: persistent cache, receipts, source/header/dependency/toolchain changes,
  corruption recovery, concurrent build/clean, killed-process lock release and
  failed-build preservation passed. Async warm builds, pnpm installation and watch
  consumers passed. Windows ASan covered lock lifetime; strict check and 50 tests
  passed. Warm median 3.812 s versus 24.510 s without cache (84.4% reduction), with
  no project compilation/linking. POSIX cache validation passed in hosted CI.
- Step 8: native work, copied inputs/results, queued/cooperative cancellation,
  original AbortSignal reason, error recovery, responsive event loop and 12
  forced worker exits passed, including Windows ASan. The new teardown test
  exposed a timer callback entering JS while Node drained native work; async
  adapter patch 4 checks execution state before opening that callback scope.
  The standalone C/MoonBit task example passed. Linux memory checks later passed
  in hosted CI.
- Step 9: two child processes executed overlapping MoonBit computations with
  isolated globals. Owned nested snapshots (UTF-16, bigint, Buffer, binary views),
  queue limits/cancellation, crash recovery without replay, idle shutdown and
  forced worker teardown with JS exit listeners removed passed. Windows ASan,
  clean offline npm platform-package installation, CJS/ESM and both TS modes
  passed. The standalone worker example passed; strict checks and 51 tests passed.
  POSIX child cleanup and Linux leak validation later passed in hosted CI.
- Step 10: typed Promise resolution (including nested and binary values), repeated
  waits, object/primitive rejection identity, throwing getters, cancellation with
  late reactions, disposal, cross-environment ownership and worker teardown passed.
  NodeNext/Bundler consumers, Windows ASan, existing async exports, strict check
  and 52 MoonBit tests passed. The scheduler sleeps until external notifications
  when no OS I/O or timer is pending. Linux memory checks later passed in hosted
  CI.
- Step 11: demand-driven AsyncIterable/Web stream input and output, concurrent
  reads, early break/return, error identity, cancellation, reference cleanup and
  forced worker teardown passed on Windows. NodeNext/Bundler and generated
  main/platform Node >=18 metadata passed. Windows ASan exposed and verified a
  fix for borrowed closure pins being freed as owned resources during teardown;
  resumed reads also guard against creating JS handles in a closing environment.
  Strict check, 53 MoonBit tests and generator snapshots passed. Linux validation
  later passed in hosted CI.
- Step 12: Linux ARM64 and macOS x64 native build, installed CLI/examples and
  Node 22/24/26 consumer jobs added. Local architecture-header rejection and
  simulated loader local/platform-package branches pass; these do not substitute
  for native execution. Both added platform jobs later passed in hosted CI.
- Step 13: musl x64/ARM64 host detection, loader branches, npm libc metadata and
  native Alpine CI added. Bounds-checked ELF dynamic dependency validation rejects
  missing/mixed/wrong libc at compiler probing, build and prepublish. Synthetic
  ELF cases and simulated seven-target loaders run locally; Alpine execution and
  Node 22/24/26 jobs later passed in hosted CI.
- Step 14: combined typed Promise → native task → stream → worker consumers pass
  with cached and `--no-cache` builds, CJS/ESM, NodeNext/Bundler, offline npm
  installation and recovery. Full Windows consumer regression passed through
  workers, Promise, streams, cache, TSFN, native tasks and legacy fixtures;
  Windows parser/addon ASan orchestration passed. The subsequent hosted run
  also passed the non-Windows seven-target and Linux leak jobs. No registry
  publication or release tag is part of this change.
- Step 15: low-level JS handles, External/zero-copy memory, DataView and BigInt
  typed arrays, N-API 8/9/10 helpers and encoded typed TSFN passed generator
  snapshots, native consumers, Linux/Windows ASan, four hosted native profiles,
  Node 22/24/26 and minimum-version consumers. No release publication is part
  of this change.
