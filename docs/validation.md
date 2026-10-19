# Implementation validation

Local execution environment (2026-10-19): Windows x64, Moon 0.1.20261012,
moonc v0.10.15+943464bfa, Node 26.4.0, CMake 4.0.3, MSBuild 17.14.14,
MSVC 19.44.35211, Windows SDK 10.0.26100.0.

| Stage | Executed locally | Platform limits |
| --- | --- | --- |
| Native toolchain validation (`efaf490`) | Strict check, 23 MoonBit tests, doctor compile/link probe, current-source addon, packaged and installed CLI without Node/npm in Chinese/space paths, CJS/ESM loading | Linux/macOS not executed locally |
| Isolated configuration (`7a1e0a6`) | Strict check, 25 MoonBit tests, extra C stub, dependency-package stub, user compilation flags and user32.lib, unchanged manifests, failed-build artifact preservation, Node loading | Linux/macOS linking not executed locally |
| Runtime error boundaries | Strict check, 25 MoonBit tests, actual Node conversion faults, pending exception identity, borrowed-view cleanup, detached/empty/sliced Buffer, numeric limits, repeated allocation/release; MSVC addon AddressSanitizer | Windows ASan does not provide the Linux leak-sanitizer gate; Linux/macOS memory checks remain CI work |

Test orchestration is in `.mbtx` files. Node fixtures exercise built binaries;
they do not stand in for native CLI tests. No registry publication or remote
push has been performed. The downloaded `napi-rs/` checkout is reference material.
