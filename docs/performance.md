# Conversion performance

String conversion copies UTF-16 code units directly between V8 and MoonBit,
preserving NUL and lone surrogates. The input is allocated once, with Node
writing only into the new, unpublished MoonBit string. Output strings are
borrowed during Node's copy. Bytes input uses one allocation and `memcpy`;
Bytes output remains an owned Node copy. Neither conversion builds an
intermediate `Array`. Empty Buffer copies avoid passing null to `memcpy`.

Windows x64 measurements on 2026-10-19: Ryzen 7 8845HS, Node 26.4.0,
moonc v0.10.15+943464bfa and MSVC 19.44.35211. Baseline is runtime 6
(`cf407a1`); optimized is runtime 7. Five samples follow warmup and correctness
assertions. Medians are microseconds per roundtrip:

| Case | Before | After |
| --- | ---: | ---: |
| Two-number call | 0.552 | 0.544 |
| ASCII, 1,024 code units | 28.384 | 1.897 |
| Unicode/NUL, 1,280 code units | 71.080 | 1.802 |
| Buffer, empty | 3.612 | 1.692 |
| Buffer, 64 bytes | 3.397 | 1.866 |
| Buffer, 4 KiB | 46.787 | 4.126 |
| Buffer, 64 KiB | 840.298 | 72.075 |
| Buffer, 1 MiB | 10,479.528 | 1,167.172 |
| Async zero-delay timers, batches of 100 | 45.918 | 110.334 |

These are local microbenchmarks, not cross-platform performance guarantees.
Async timer samples vary substantially with Windows timer resolution and host
load; this run is slower and establishes no async speedup. Async scheduling was
not changed by the conversion optimization. All samples and machine metadata
are retained in [baseline.json](benchmarks/baseline.json) and
[optimized.json](benchmarks/optimized.json).

A fresh project built in 29.884 s; three subsequent builds took 29.573, 30.526
and 30.087 s. “Cold” means a fresh project, with an already installed toolchain.
“Warm” reuses that project. Each build still compiles in a new isolated workspace;
there is currently no incremental object cache. These numbers expose that cost.

Build the root addon and `scripts/async-exports-test.mbtx` fixture, then capture
binaries before and after an optimization. The captures remain independent of
later rebuilds:

```sh
moon run scripts/benchmark.mbtx before --capture
moon run scripts/benchmark.mbtx before
# After rebuilding the changed root addon and async fixture:
moon run scripts/benchmark.mbtx after --capture
moon run scripts/benchmark.mbtx after --build
```

Results are written to `.napi-mbt/benchmarks/<label>/results.json`. `--record`
copies an existing report to `docs/benchmarks/`. Run benchmarks without sanitizer
instrumentation. Correctness tests cover every UTF-16 code unit, invalid inputs,
empty/sliced/detached Buffers and independent copies up to 1 MiB. The same
conversion scenarios and class/callback/async consumers pass Windows ASan.

These reports compare the conversion change at `0634d1c` with `cf407a1`.
The later async adapter patch 3 replaces deferred handles with owned resolver
callbacks for leak-free worker teardown; its extra Promise setup is outside
these recorded before/after measurements. Rerun the benchmark against captured
current binaries when evaluating async scheduling performance.
