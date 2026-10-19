# Implementation validation

Local execution environment (2026-10-19): Windows x64, Moon 0.1.20261012,
moonc v0.10.15+943464bfa, Node 26.4.0, CMake 4.0.3, MSBuild 17.14.14,
MSVC 19.44.35211, Windows SDK 10.0.26100.0.

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
