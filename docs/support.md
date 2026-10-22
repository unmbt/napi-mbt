# Support policy

| Layer | Policy |
| --- | --- |
| Native CLI | No Node/npm dependency |
| New addon | N-API 4, CJS and ESM enabled |
| Main Node CI | 22, 24, 26 on seven native host profiles |
| Minimum consumers | Node 10.16 CJS/N-API 4; 12.20 dual/N-API 4; 12.22 async/N-API 8 |
| Native build gates | Windows x64 MSVC; Linux x64/ARM64 glibc and musl; macOS x64/ARM64 |
| New platform status | Linux ARM64, macOS x64 and Alpine musl gates configured; awaiting CI execution |
| Cross-compilation | Requires a matching host; the CLI rejects a different target |
| libc | glibc and musl; compiler probe and addon ELF dependencies must match the host |

Generated `engines.node` is the intersection of N-API introduction versions and
loader requirements. The default dual-mode range is
`>=12.20.0 <13 || >=14.13.1`. N-API 8 requires
`>=12.22.0 <13 || >=14.17.0 <15 || >=15.12.0 <16 || >=16.0.0`.
Other configurations receive their own precise range. A minimum-version test
checks compatibility; it is not a recommendation to deploy an EOL Node release.

Web streams require Node 18. Musl builds use native Alpine x64/ARM64 toolchains;
the compiler probe and addon ELF dynamic dependencies are checked before output
installation and again at prepublish. See [platform validation](platforms.md).

| Feature | Minimum N-API |
| --- | ---: |
| Numbers, Bool, UTF-16 strings, owned structured values | 1 |
| Class and callback lifecycle | 3 |
| [Threadsafe Function](tsfn.md) | 4 |
| Int64/UInt64 bigint | 6 |
| Bytes and checked BufferView | 7 |
| Embedded async host, Promise exports and async cleanup | 8 |

Bare N-API Promise operations exist in v1; the async host needs v8 cleanup.
Features can compose: a structured value containing bigint or Buffer inherits
the higher requirement. `moonbitlang/async` must be exactly 0.22.4.

The checked napi-rs CLI declares `^20.17.0 || ^22.13.0 || >= 23.5.0`, while its
core defaults to `napi4` and `dyn-symbols`. It does not impose Node 22 on every
addon. napi-mbt aligns the default N-API and separates CLI/runtime requirements.

CI pins Moon/core `0.10.15+943464bfa`, CMake 4.4.4 and build Node 26.4.0.
CMake includes the Visual Studio 18 2026 generator used by current Windows runners.
Project checking runs before template validation to download dependencies;
`moon update` only refreshes the registry index.
`moon run scripts/ci-bootstrap-test.mbtx` repeats dependency and template checks
in a temporary copy of the Git sources without project caches.
The corresponding moon/moonrun are `0.1.20261012 (748b63c)` with
`rr_moon_mod,rr_moon_pkg`. `moon run scripts/toolchain-check.mbtx` verifies
the exact compiler, build tool, runner and feature flags in pinned CI jobs and WSL.
The local Windows toolchain uses MSVC 19.44.35211, MSBuild 17.14.14 and SDK
10.0.26100.0. Hosted compiler/SDK images can still change; `doctor --json`
records the selected compiler/SDK, and actual compile/link probes gate builds.
A separate latest-MoonBit job detects compiler changes. On 2026-10-19,
[CI run 39229142895](https://github.com/unmbt/napi-mbt/actions/runs/39229142895)
passed all 18 validation jobs for `00503d9`, including the three release
platforms, Node 22/24/26, minimum Node consumers and Windows/Linux memory checks.
The tag-only release job was skipped; packaging validation does not establish
publication. See the [validation record](validation.md#hosted-ci-confirmation)
for hosted and local evidence and remaining platform limits.
