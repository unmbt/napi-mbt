# Usage

Install from Mooncakes with `moon install unmbt/napi-mbt/cmd/napi-mbt-cli`.
For development, run `moon install ./cmd/napi-mbt-cli` in the source checkout.
`napi-mbt-cli --help` and each subcommand's `--help` describe the accepted flags.

| Command | Behavior |
| --- | --- |
| `init <directory> --name <name>` | Creates a project; existing files require explicit `--force` |
| `doctor [directory] --json` | Finds and probes the actual compiler, linker and SDK |
| `generate [directory] --check` | Parses, resolves types and checks all outputs without writing |
| `build [directory] --release` | Generates and compiles in isolation, then installs successful outputs |
| `build --watch --verbose --output-dir <path>` | Watches inputs, reports commands/timings and chooses the artifact root |
| `targets` | Lists recognized host target profiles |
| `prepublish [directory] --target <target>` | Validates release artifacts and prepares npm platform metadata |

Without `--check`, generation validates the complete package before replacing
managed files. `napi-mbt.json` is strict JSON; the generated
`napi-mbt.schema.json` supplies editor validation. For example:

```json
{
  "$schema": "./napi-mbt.schema.json",
  "napiVersion": 8,
  "builder": "auto",
  "cjs": true,
  "esm": true
}
```

Use `napiVersion: 4` for a basic new project, 6 for bigint, 7 for checked Buffers
and owned binary views, and 8 for async exports. Low-level JS handles and typed
TSFN work from N-API 4; freeze/seal and type tags require 8, `Symbol.for` and
SyntaxError helpers require 9, and property keys, external strings and
ArrayBuffer-backed Buffer views require 10. Features required by signatures are
inferred and checked.
Set `targets` only to constrain host profiles; it does not enable cross-compiling.
Disabling both module modes is an error. [Support policy](../support.md) explains
Node minimums and release platforms.

For advanced bindings, see [low-level and advanced APIs](advanced-api.md). The
page covers environment injection, `NapiObject`/`NapiFunction`/`NapiArray`,
External lifetime rules, owned DataView and BigInt arrays, version-gated helpers,
and encoded typed TSFN. Add the relevant names to `features` when you want the
configuration schema to reject an insufficient `napiVersion` early.

Put exports in the root MoonBit package. The parser resolves exported signatures
and referenced value types across that package's source files. Generic exports,
unknown types and unsupported signatures fail with a filename and line.
`///` documentation preceding an export or value type appears in declarations
and `napi_manifest.json`; error explanations use the same validated IR.

Read [types](../types.md), [classes/callbacks](../classes-callbacks.md),
[async](../async.md), and [build/watch](../build.md). The
[documented addon fixture](../../scripts/fixtures/documented-addon.mbt.txt) is
compiled and exercised in CI, including basic values, Buffer, errors, objects,
callbacks and async calls. TypeScript projects using Buffer or async signatures
need `@types/node`; declarations explicitly identify that dependency.

Use `require('./index.cjs')` or `import addon from './index.mjs'` locally.
Installed packages use their package name. Existing local binaries take priority;
damaged binaries do not trigger fallback. Loader errors expose `target`, attempted
paths, N-API requirements and the original `cause`. Platform packages must have
matching name/version/target/N-API metadata.

Generation manages the package root entry, engines and its own files while
preserving other metadata, scripts, dependencies and export subpaths. Build
preserves MoonBit manifests, native stubs, flags and libraries in the original
project. See [distribution validation](development.md) before preparing packages.

Project text must be UTF-8. Malformed input reports the offending path; missing
files retain their I/O errors. Generated text is explicitly encoded as UTF-8.
External compiler diagnostics tolerate non-UTF-8 bytes, so Windows code-page
output cannot abort an otherwise successful build.
