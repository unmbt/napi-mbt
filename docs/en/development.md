# Engineering and distribution

The pipeline is AST → typed IR → whole-package validation → MoonBit/C/TypeScript/
loader outputs. `generator/` owns the only public generator. `internal/syntax/`
owns the bundled parser; [vendor provenance](../../internal/syntax/VENDOR.md)
records source versions and licenses.

Root runtime sources are authoritative. After editing them, run
`moon run scripts/sync-runtime.mbtx`; the resource build rule embeds that result.
The async 0.22.4 adaptation has separate sources, checksums and licenses:
`moon run scripts/sync-async-adapter.mbtx`. Both support `--check` and run in CI.
Do not hand-edit duplicated runtime text in `resources.json`.

Every addon call enters a recursive per-addon lock. MoonBit code and reference
counting run on the owning JS environment thread. C callbacks pin borrowed
payloads around reentry; persistent JS references have explicit release paths.
Class finalizers, disposal and environment cleanup share resource management.
The async host drives bounded scheduler rounds from Node; background threads
perform only C waiting/I/O. See [async architecture](../async-adapter.md).

## Checks

```sh
moon info --target native
moon fmt
moon check --target native --warn-list +73 --deny-warn
moon build --target native --release cmd/napi-mbt-cli
moon test --target native cmd/napi-mbt-cli generator internal/syntax internal/assets
moon run --target native --release cmd/napi-mbt-cli -- build --release
npm ci --ignore-scripts
moon run scripts/ci-regression-test.mbtx
moon run scripts/ci-consumers.mbtx
moon run scripts/sanitizer-test.mbtx
```

Inspect `.mbti` changes. Snapshot updates require reviewing complete generated
files, followed by actual compilation and Node consumers. Tests cover positive
and negative NodeNext/Bundler declarations, worker shutdown, cancellation races,
resource counts, Unicode, detached buffers, user configuration and native
dependencies. Process tests have timeouts. ASan runs parser and addon scenarios;
Linux also enables leak detection. [Validation](../validation.md) distinguishes
local results from configured CI jobs.

Unit tests select the CLI, generator, parser and assets packages explicitly.
The root foreign library needs the Node host; its tests run through real addon
consumers rather than a standalone MoonBit test executable. This also avoids
depending on local headers/import libraries left by previous builds.
ASan uses the runtime from Visual
Studio's default C++ toolset. Linux suppresses two Node 26.4.0 host allocations:
the OpenSSL startup allocation at `ossl_load_builtin_compressions` and the cppgc
wrapper for `ContextifyScript` when evaluating worker scripts. Both reproduce
without any addon. A bare-Node worker baseline and an intentional unrelated leak
verify that leak detection remains active; no whole-library suppression is used.

## Package gates

Versions in `moon.mod`, `package.json`, lockfile and platform dependencies must
match; release tags are checked. `prepublish` rejects missing, wrong-architecture,
non-library or stale artifacts/declarations. It preserves user package metadata
and includes bundled licenses. Generated `npm/`, `artifacts/` and `licenses/`
are not source-controlled.

Release with `moon-bump` from the repository root. Its configured
`prepare-release.mbtx` hook synchronizes the npm manifest and lockfile versions
from `moon.mod`, strictly checks the project (regenerating the CLI version), and
runs the release checks before committing and tagging. `all: true` includes
these generated changes in the release commit. To repair or validate a manually
changed version, run `moon run scripts/prepare-release.mbtx`. CI runs
`release-check.mbtx` without `--write`, so an inconsistent release still fails.

The checkout manifest contains development dependencies, without unpublished
platform packages. `prepublish` adds the platform dependencies for distribution;
the root distribution test restores the checkout manifest afterward.
`source-install-test.mbtx` runs `npm ci` in a fresh temporary directory with
only the manifests and verifies rejection of an incomplete lockfile.

```sh
moon run scripts/release-check.mbtx
moon run scripts/distribution-test.mbtx
moon run scripts/distribution-test.mbtx _build/native/release/build/cmd/napi-mbt-cli/napi-mbt-cli.exe --root
moon run scripts/mooncake-package-test.mbtx
```

The distribution test runs npm pack/dry-run, installs actual tarballs offline in
a clean directory, loads CJS/ESM and checks installed TypeScript declarations.
It also verifies that corrupt binaries, stale declarations and version mismatches
are rejected. `--root` emits root/package tarballs to `dist/npm/<target>/`.
No registry publication occurs. Source digests are not currently tied to binary
receipts; always build the checkout being packaged.

The Mooncake gate packs the module, rejects accidental dependencies/binaries in
the archive, extracts it, and strictly checks the extracted sources. It uses no
registry publication. `moon publish --dry-run` additionally contacts the registry
and rejects a version that already exists; use it
only when checking availability of an actual new release version.

CI pins Moon/core and CMake, builds the three release platforms, runs the Node
22/24/26 matrix and minimum consumers, and gates release archives on tests.
A separate job checks latest MoonBit compatibility. Test orchestration uses
`.mbtx`; `.cjs/.mts/.cts` files are real consumers. Keep downloaded `napi-rs/`
as local reference only. [Benchmarks](../performance.md) and the
[roadmap](../roadmap.md) describe remaining performance and platform work.
