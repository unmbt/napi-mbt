# Build and watch

`napi-mbt-cli doctor [directory] --json` reports and probes the native toolchain.
`build` runs the same compile/link probe before generation. Node/npm are not
dependencies of the native CLI.

```sh
napi-mbt-cli build . --release --verbose
napi-mbt-cli build . --watch --output-dir "native output"
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
change. Concurrent edits of package.json are detected before installation to
avoid overwriting the user's changes. Stop watch with Ctrl+C.

The original module/package manifests, flags, stub sources, dependencies and
link inputs remain the source of truth. Build configuration is supplemented in
the isolated copy, and Moon resolves the full native dependency graph.
