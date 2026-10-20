# Implementation progress

Scope: Mooncakes tool distribution; npm distribution for generated addons;
standalone examples; owned value types; TSFN; isolated build caching; native
tasks; process workers; JS promises and streams; seven native platforms.

Commits are made only after their focused checks pass. No push, registry
publication, tag, or release-version change is part of this work.

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
  default N-API 4 addon passed. Node 22/24/26 consumers are configured in CI.
- Step 6: real native-thread TSFN consumers and Windows ASan passed: 20 rounds
  each of delivery, queue-full and abort, plus 12 worker terminations. All 72
  finalizers ran once, C allocations returned to baseline and callback thread
  checks passed. Strict check, 48 tests and documentation checks passed.
- Step 7: persistent cache, receipts, source/header/dependency/toolchain changes,
  corruption recovery, concurrent build/clean, killed-process lock release and
  failed-build preservation passed. Async warm builds, npm installation and watch
  consumers passed. Windows ASan covered lock lifetime; strict check and 50 tests
  passed. Warm median 3.812 s versus 24.510 s without cache (84.4% reduction), with
  no project compilation/linking. POSIX cache validation awaits CI.
