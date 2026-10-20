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
