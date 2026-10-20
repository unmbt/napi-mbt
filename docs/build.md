# Build and watch

`napi-mbt-cli doctor [directory] --json` reports and probes the native toolchain.
`build` reuses a successful probe only while tool selection, executable contents,
SDK identity and relevant environment settings still match. Node/npm are not
dependencies of the native CLI. `doctor` always performs a fresh probe.

```sh
napi-mbt-cli build . --release --verbose
napi-mbt-cli build . --watch --output-dir "native output"
napi-mbt-cli build . --release --no-cache
napi-mbt-cli clean . --cache
```

`--verbose` prints executable paths, arguments, working directories, compiler
output, and timings for toolchain, generation, preparation, compilation/linking
and artifact publication. Ordinary builds print the final artifact path;
failures always include the compiler diagnostics.

`--output-dir` is absolute or relative to the project. Artifacts are written to
`<output-dir>/<target>/napi_mbt.node`. Generated CJS and ESM loaders read the
local `.napi-mbt/build-output.json` record, so custom builds load directly.
This local record is excluded from published packages. `generate --check`
checks source-generated files without writing them.

Watch performs an initial build, debounces changes for 150 ms (at most one
second), and serializes builds. Changes arriving during compilation queue the
next build. Generated outputs, build directories, node_modules and the selected
artifact directory are excluded. Native dependencies and header changes are
watched. Package name/version changes trigger regeneration; generated package
entry fields do not trigger loops. `--watch --dry-run` is rejected.

Generation and compilation run in an isolated workspace. Only successful
builds replace the addon, declarations, loaders and generated metadata.
Failures leave the last successful files usable, and watch resumes when inputs
change. Concurrent edits of build inputs are detected before installation to
avoid overwriting the previous successful artifacts. Stop watch with Ctrl+C.

The persistent `.napi-mbt/cache` workspace is partitioned by target, mode, CLI,
runtime/async adapter, compiler/SDK and configuration identity. Source digests
do not partition it: changing one MoonBit file can reuse dependency objects.
The CLI creates the complete generated and patched overlay in a temporary tree,
then synchronizes only changed bytes into the cache and removes obsolete inputs.
Unchanged files retain their timestamps. Header changes invalidate native objects.
Corrupt cache metadata triggers reconstruction. Kernel file locks serialize
build and clean across processes and release automatically when a process exits.

`--no-cache` uses a fresh workspace and a fresh toolchain probe. Custom build hooks,
unresolved variables and explicit external include/library paths fall back to
this mode with a diagnostic, because their inputs cannot be tracked reliably.
`clean --cache` removes only this project's cache, retaining successful artifacts.

Each successful build records input, toolchain and output digests in
`.napi-mbt/receipt-<target>.json`. User addon `prepublish` requires a matching receipt
and rejects stale sources, declarations, loaders, binaries and host toolchains.
Rebuild when a receipt is missing. When collecting native builds from multiple
hosts, collect their receipts alongside their target artifacts; all must match
the same source tree. Digests detect stale/corrupt files and are not signatures.

The original module/package manifests, flags, stub sources, dependencies and
link inputs remain the source of truth. Build configuration is supplemented in
the isolated copy, and Moon resolves the full native dependency graph.

On POSIX, dependency stubs and MoonBit runtime objects must all be position
independent. The isolated build adds PIC flags and uses a small native compiler
driver for runtime objects, because the pinned Moon builder does not forward
package flags to those objects. It delegates to the compiler selected by the
probe, preserving arguments. Explicit compiler choices and MOON_CC are included
in toolchain selection; the original manifests and installed toolchain remain
untouched.

Conflicting package compiler choices and explicit `-fno-PIC` flags fail rather
than being discarded. Linux also hides bundled runtime/dependency symbols and
binds internal references locally, preventing simdutf collisions with Node.
The Node-API registration and user-configured exports remain visible.
