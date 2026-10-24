# Native platform validation

The CLI builds for its own host. No cross compiler or architecture emulation is
used. All seven target names select matching loader paths and npm os/cpu/libc
metadata. CI runs installed CLI/examples, real consumers and package installation
for the seven target profiles; the current low-level/advanced API change passed
the hosted native and memory gates.

| Target | Native CI host | Current change evidence |
| --- | --- | --- |
| win32-x64-msvc | windows-2025 | Windows x64 |
| darwin-x64 | macos-15-intel | Hosted CI |
| darwin-arm64 | macos-15 | Hosted CI |
| linux-x64-gnu | ubuntu-24.04 | Hosted CI |
| linux-arm64-gnu | ubuntu-24.04-arm | Hosted CI |
| linux-x64-musl | Alpine on ubuntu-24.04 | Hosted CI |
| linux-arm64-musl | Alpine on ubuntu-24.04-arm | Hosted CI |

Musl builds use Alpine's native C toolchain. `gcompat` runs the pinned MoonBit
compiler binaries; it must not become the addon libc. The CLI is compiled inside
Alpine, and compiler probes and addons must depend on the matching musl SONAME.
The CLI parses ELF PT_DYNAMIC/DT_NEEDED at build and prepublish, rejecting missing,
mixed or mismatched libc dependencies. CI records `readelf -d` and `ldd` results.

Node 22/24/26 consumers run on all profiles, with separate native Alpine images
for musl. Existing minimum Node CJS/dual/async consumers remain in the glibc job.
Web stream consumers additionally run on Node 18. Platform configuration and
synthetic ELF/loader tests do not establish a successful native platform build.
