# Implementation validation

Current hosted status: [run 39229142895](https://github.com/unmbt/napi-mbt/actions/runs/39229142895)
passed all 18 validation jobs for commit `00503d9` on 2026-10-19.
See [hosted CI confirmation](#hosted-ci-confirmation) for the tested matrix and
the distinction between packaging validation and release publication.

Local execution environment (2026-10-19): Windows x64, Moon 0.1.20261012,
moonc v0.10.15+943464bfa, Node 26.4.0, CMake 4.0.3, MSBuild 17.14.14,
MSVC 19.44.35211, Windows SDK 10.0.26100.0.

The stage entries below record what was known at each commit; final integration
results are listed after them.

| Stage | Executed locally | Platform limits |
| --- | --- | --- |
| Native toolchain validation (`efaf490`) | Strict check, 23 MoonBit tests, doctor compile/link probe, current-source addon, packaged and installed CLI without Node/npm in Chinese/space paths, CJS/ESM loading | Linux/macOS not executed locally |
| Isolated configuration (`7a1e0a6`) | Strict check, 25 MoonBit tests, extra C stub, dependency-package stub, user compilation flags and user32.lib, unchanged manifests, failed-build artifact preservation, Node loading | Linux/macOS linking not executed locally |
| Runtime error boundaries | Strict check, 25 MoonBit tests, actual Node conversion faults, pending exception identity, borrowed-view cleanup, detached/empty/sliced Buffer, numeric limits, repeated allocation/release; MSVC addon AddressSanitizer | Windows ASan does not provide the Linux leak-sanitizer gate; Linux/macOS memory checks remain CI work |
| Single generator | Typed IR and public-interface review; complete artifact snapshots; 22 MoonBit tests after deleting five obsolete tests and adding two transactional-output tests; template consistency check; current-source native build and Node loading | Other hosts not executed locally |
| Configuration and loaders | 25 MoonBit tests; strict configuration and schema generation; full ten-file snapshots; real CJS/ESM/ESM-only addon loading; original error identity and damaged local binary in fresh processes; platform metadata/version checks; NodeNext/Bundler positive and negative consumers; packaged and installed release CLI without Node/npm in Chinese/space paths; root CJS/ESM loading | Loader OS/CPU/libc error branches also exercised with VM inputs; native Linux/macOS and minimum Node versions remain CI work |
| Structured values | 29 MoonBit tests; complete primitive and structured artifact snapshots; actual bigint limits, nested Option/Array, cross-file structs, recursive and labeled enums, own-field checks, getter exceptions, cycles and 10,000 allocation cycles; strict NodeNext/Bundler consumers including declarations; addon ASan and 13 parser/generator ASan tests on Windows; runtime boundary regression; packaged/installed CLI without Node/npm; root CJS/ESM loading | Linux/macOS and leak sanitizer not executed locally. Cross-regression also found and fixed ESM helper/export name collisions, with ten colliding names exercised in real loaders |
| Classes and callbacks | 32 MoonBit tests; complete class/callback snapshots; strict NodeNext/Bundler consumers; actual constructors, factory results, accessors, hidden methods, receiver forgery and multiple addons; callback exceptions, reentry and disposal during invocation; 10,000 repeated allocations with resource counts returning to baseline; eight concurrent workers and forced worker termination; class/callback addon ASan and 16 parser/generator ASan tests on Windows | Linux/macOS and Linux leak sanitizer not executed locally. A FuncRef retention leak found by resource-count tests was fixed and the same scenarios passed under ASan. Runtime template version is 4 |
| Embedded async host | 34 MoonBit tests and two isolated adapter tests; actual Node timers, filesystem, TCP, task groups and heartbeat; four concurrent worker environments; termination while TCP reads and timers are pending; environment counts restored; full async fixture and dependency C stubs instrumented with Windows ASan; dependency cache preserved and mismatched versions/checksums rejected; regenerated snapshots and class/callback/structured regressions | POSIX thread-pool C passed GCC C11 syntax checking in Fedora WSL. Linux/macOS runtime and leak sanitizer were not executed. Runtime template version is 5; the Node driver polls pending OS I/O within two milliseconds |
| Promise exports and cancellation | 36 MoonBit tests; two isolated scheduler tests; complete async snapshots; NodeNext/Bundler TS consumers; Promise microtask delivery, conversion rejection without business effects, original JS thrown values across suspension, pre-abort, 100 completion/cancel races, callback reentry, file/TCP/task-group operations, standard output, four concurrent workers and forced termination; resource counts restored; full async addon and dependency C stubs passed Windows ASan; 18 parser/generator ASan tests; class/callback/structured regressions | Linux/macOS runtime and leak sanitizer not executed locally. Runtime template version 6, adapter patch version 2. Standard streams and buffers are environment-local; interface lookup sockets are call-owned |

Watch and diagnostics validation: 38 MoonBit tests; strict warning checks;
real initial build, three rapid source changes coalesced into one build, a syntax
failure preserving both binary and declarations, automatic recovery, no loops
from generated outputs, CJS/ESM loading from Chinese/space output paths,
prepublish from that custom directory, stage timings, and isolated dependency
regression. Loader CJS/ESM/ESM-only and TS consumer tests also passed. These
native watch scenarios were executed on Windows only.

Distribution gates: 39 MoonBit tests, strict checks, complete generator and
structured snapshots, actual fixture and root npm pack/dry-run, offline clean
installation, CJS/ESM and installed TypeScript consumers passed on Windows.
Both packages include runtime, Node-API, async and libuv licenses. Corrupt
binaries, stale declarations and mismatched versions are rejected. Full parser,
runtime, structured, class, callback and async ASan orchestration passed on
Windows. Node 22.22.1 additionally passed native runtime/lifecycle/async tests.
The pinned CI gates cover Node 22/24/26 and minimum Node 10.16/12.20/12.22,
Linux/Windows sanitizer jobs, and a separate latest-MoonBit compatibility job.
These configured jobs are not a claim of GitHub execution. Local Linux
validation is tracked separately; macOS has not been executed locally.

Test orchestration is in `.mbtx` files. Node fixtures exercise built binaries;
they do not stand in for native CLI tests. No registry publication or remote
push has been performed. The downloaded `napi-rs/` checkout is reference material.

## Final integration

The Windows and Fedora 43 WSL toolchains both report moon/moonrun
`0.1.20261012 (748b63c)` and moonc `v0.10.15+943464bfa`, with
`rr_moon_mod,rr_moon_pkg`. The main CI toolchain/core are pinned to that release,
and `scripts/toolchain-check.mbtx` checks the executable versions and feature
flags. Latest-MoonBit compatibility is a separate job.

Origin commit `4a03028` was merged as `8a3f858`, retaining both histories and
adapting its Windows diagnostic decoding and UTF-8 file handling to the current
generator/build pipeline. Encoding regressions, strict checks, 41 tests at the
merge point, and a real Windows addon CJS/ESM load passed. The final MoonBit suite
contains 45 tests; the parser/generator ASan suite contains 20.

Linux validation used Node 22.22.1, GCC 15.2.1 and CMake 3.31.10 in an isolated
WSL workspace. It passed user-configuration and native-dependency preservation,
failed-build recovery, Promise/I/O/cancellation/worker tests, parser ASan and
all runtime/structured/class/callback/async addon ASan tests with leak detection
enabled. This exposed and verified fixes for missing runtime/stub PIC, bundled
simdutf symbol collisions with Node, conflicting multi-class C prototypes, and
unsettled deferred handles leaked during forced worker termination. Async patch
version 3 uses environment-owned resolver callbacks; it does not call JS during
shutdown. Runtime template version remains 7.

The conversion benchmark reports preserve independent before/after binaries.
UTF-16 correctness covers every code unit, including lone surrogates and NUL;
Buffer tests cover detached, empty, sliced and independent copied storage.
The reports do not claim an async speedup or an incremental build cache.

Windows Node 22.22.1 and 24.14.0 and minimum consumers 10.16.0/12.20.0/12.22.0
were also executed locally, in addition to Node 26.4.0. The configured GitHub
matrix is not evidence of a hosted run. macOS, Linux ARM64 and macOS x64 have
not been executed locally; hosted SDK/compiler image reproducibility remains
limited to the version reporting and compile/link gate described in the support
matrix.

The final Windows regression and consumer runs passed native CLI installation
without Node/npm, malformed UTF-8 diagnostics in Chinese/space paths, complete
generator snapshots, isolated native dependency builds, documented examples,
watch failure/recovery, and installed NodeNext/Bundler declarations. Root and
fixture npm tarballs passed dry-run and offline clean installation. Node
22.22.1/24.14.0 and minimum 10.16.0/12.20.0/12.22.0 were rerun after async patch 3.
Final Windows parser/addon ASan passed; Windows has no LeakSanitizer, so leak
validation uses the Linux run above.

The final strict check and all 45 MoonBit tests passed. `moon info` and `moon fmt`
introduced no additional public-interface changes. Runtime/async template checks,
generated-output checks, documentation checks, version/lockfile checks and
workflow actionlint passed. Mooncake packaging, archive inspection, extraction
and strict checking of the extracted module passed on Windows and Fedora WSL
without registry access.
The separate `moon publish --dry-run` reached a successful extracted-source
check, then returned registry 409 because version 0.1.1 already exists. Nothing
was published.

## Clean-host CI repair

[Run 39220229169](https://github.com/unmbt/napi-mbt/actions/runs/39220229169)
exposed failures hidden by local generated files and host differences. The source
npm manifest no longer depends on unpublished platform packages; `prepublish`
still adds distribution dependencies, and the root distribution test restores
the source manifest. Clean temporary-directory installation and rejection of a
missing lockfile entry both passed. Root npm pack/dry-run, clean consumer install
and extracted Mooncake checks also passed after this change.

Unit CI now explicitly selects the CLI, generator, parser and assets packages:
all 45 tests passed on Windows and isolated Fedora WSL. The root addon requires
Node and remains covered by actual Node consumers; it is not linked as a
standalone unit-test executable with missing Node headers or non-PIC runtime
objects. Windows ASan selects the DLL directory of the default MSVC toolset,
rather than prepending every installed toolset in filesystem order. The complete
Windows parser/addon ASan run passed locally.

Fedora WSL passed the complete parser/addon sanitizer run with both Node 22.22.1
and the CI-pinned Node 26.4.0. The latter independently reproduced two host leaks
without an addon: 24 bytes in OpenSSL startup and 32 bytes per evaluated worker
script in the ContextifyScript cppgc wrapper. Only those exact allocation sites
are suppressed. A bare worker baseline passes, and a separate deliberate
37-byte leak still fails under the same settings. Parser (20 tests), conversion,
class/callback, Promise/cancellation, I/O and worker teardown tests all passed.

Strict checks, interface/format checks, generation checks and workflow actionlint
passed. At this repair commit, a hosted rerun was still pending; the subsequent
CI results below record the remaining failures and their resolution.

## Dependency bootstrap and Visual Studio 2026 CI repair

[Run 39223932105](https://github.com/unmbt/napi-mbt/actions/runs/39223932105)
confirmed that Linux memory checks and latest-MoonBit compatibility passed.
Windows parser ASan also passed all 20 tests. The remaining failures were the
async template check running before project dependencies were downloaded, and
CMake 4.0.3 lacking the hosted Visual Studio 18 2026 generator.

Strict project checking now precedes template checks, and both workflows pin
CMake 4.4.4. The new bootstrap regression copies Git sources without project
caches, checks the missing-dependency diagnostic, then runs strict checking and
both template checks successfully. The WSL validation copy also excludes
`.mooncakes` now. Moon/core remain pinned to `0.10.15+943464bfa`.

Official SHA-256 checks passed for the Windows and Linux CMake 4.4.4 downloads.
The Windows executable lists `Visual Studio 18 2026` in its capabilities. Actual
compile/link probes passed on Windows with VS 2022 and on Fedora WSL with GCC
15.2.1. The complete Windows parser/addon ASan suite passed with CMake 4.4.4 and
Node 26.4.0, including Promise cancellation, I/O and worker teardown.

A fresh Fedora WSL source copy passed all main native gates and the Node 26.4.0
consumer commands: dependency/template checks, 45 unit tests, no-Node CLI
installation, snapshots, isolated native inputs, loaders and declarations,
classes/callbacks, async I/O/cancellation/workers, documented examples, watch
recovery, npm packing/dry-run/clean installation, Mooncake extraction/checking,
CLI archive packaging and consumer artifact staging. This complete run used
the existing CMake 3.31.10 installation.

A fresh Windows source copy passed the same complete main gates and Node 26.4.0
consumer commands with CMake 4.4.4 and VS 2022.

A separate fresh Fedora WSL source copy built the CLI and passed the entire
parser/addon ASan/LSan suite with CMake 4.4.4 and Node 26.4.0. This includes the
bare-host baseline, rejection of the intentional unrelated leak, conversion,
class/callback and async I/O/cancellation/worker teardown cases.

Strict checks, interface/format checks, documentation checks and workflow
actionlint passed. There are no public-interface changes.

Hosted VS 2026 and macOS execution were pending at this repair commit. The
following run now confirms both environments.

## Hosted CI confirmation

On 2026-10-19, [Build and distribution gates, run 39229142895](https://github.com/unmbt/napi-mbt/actions/runs/39229142895)
passed all 18 validation jobs for commit `00503d9`:

| Gate | Confirmed successful coverage |
| --- | --- |
| Native build and distribution gates | Ubuntu 24.04 x64 glibc, Windows 2025 x64 MSVC, macOS 15 ARM64 |
| Node consumers | Node 22, 24 and 26 on each of the three release platforms (9 jobs) |
| Minimum Node consumers | Linux Node 10.16.0 CJS, 12.20.0 dual mode and 12.22.0 async |
| Native memory | Linux ASan/LSan and Windows ASan |
| Latest MoonBit compatibility | Ubuntu 24.04 |

This confirms the dependency-bootstrap repair on all three platforms and the
CMake 4.4.4 repair on the hosted Windows Visual Studio 2026 toolchain.
[Copilot Setup Steps, run 39229142894](https://github.com/unmbt/napi-mbt/actions/runs/39229142894)
also passed for the same commit.

The native jobs include CLI/npm packaging, dry-run and clean-install checks,
Mooncake archive extraction/checking and artifact uploads. `Release archives`
was correctly skipped because this was a branch push, not a version tag. This
run does not establish GitHub Release or registry publication. Linux ARM64 and
macOS x64 remain outside the release matrix; macOS has no sanitizer job.
