# napi-mbt

[简体中文](README.zh.md)

Build native Node.js addons in MoonBit. A standalone native CLI parses MoonBit
with Tree-sitter, validates one type IR, and generates MoonBit adapters, C glue,
TypeScript declarations and independent CJS/ESM loaders. The project is under
active development and distributed through Mooncakes.

Supported exports include strict numeric conversions, bigint, exact UTF-16
strings, owned and borrowed Buffers, nested Option/Array, structs/enums, explicit
classes, callbacks and `async fn` returning cancellable Promises. Runtime errors
stop the current call. JavaScript exceptions retain their identity.

## Install from Mooncakes

Install MoonBit and a native C toolchain. The verified versions and Node policy
are in the [support matrix](docs/support.md). Build requires CMake and GCC/Clang,
or Visual Studio C++ Build Tools, MSBuild and a Windows SDK.

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
napi-mbt-cli init my-addon
cd my-addon
napi-mbt-cli doctor --json
napi-mbt-cli build --release
node -e "console.log(require('./index.cjs').mbt_add(2, 3))"
```

The native CLI does not require Node or npm, including during addon compilation.
Node is needed to load an addon; npm is needed for package installation/testing.
The parser, headers, runtime templates and versioned async patch are embedded.

For development, clone this repository and run `moon install ./cmd/napi-mbt-cli`.
The root npm package is private and only installs development tools. Addons
created with the CLI retain npm facade/platform packages and `prepublish`.

Export functions with `#export_name("name")` on `pub fn` or `pub async fn`.
The annotation determines the JavaScript export name. Generated declarations
include the source documentation and error contract. See the
[usage guide](docs/en/usage.md), [types](docs/types.md),
[classes and callbacks](docs/classes-callbacks.md), [async](docs/async.md), and
[native background tasks](docs/native-tasks.md).
Six [standalone examples](examples/README.md) include native behavior and
TypeScript consumers and are built with the packed, installed CLI in CI.

## Commands

```sh
napi-mbt-cli generate --check
napi-mbt-cli build --watch --verbose --output-dir "native output"
napi-mbt-cli prepublish --target win32-x64-msvc
```

`generate --check` validates without writing. `doctor` and `build` share an actual
compile/link probe. Builds supplement configuration in an isolated workspace,
preserving user flags, exports, dependencies and native inputs. Watch serializes
changes and keeps the last successful binary and declarations after failures.
See [build behavior](docs/build.md).

New projects default to N-API 4, matching napi-rs. There is **no blanket Node 22
minimum**: generated `engines.node` follows the chosen N-API and loader features.
Main CI covers Node 22/24/26, plus minimum-version consumers. Bytes/BufferView
require N-API 7; the async host requires N-API 8 and `moonbitlang/async@0.22.4`.

CJS and ESM default to enabled; either can run independently. Unknown config
fields, unsupported features and incompatible N-API requirements fail explicitly.
Loaders prefer existing local artifacts and retain the original cause when a
candidate is broken. Platform package versions and metadata must match.

## Validation and distribution

```sh
moon build --target native --release cmd/napi-mbt-cli
moon run --target native --release cmd/napi-mbt-cli -- build --release
npm ci --ignore-scripts
moon run scripts/ci-regression-test.mbtx
moon run scripts/ci-consumers.mbtx
moon run scripts/sanitizer-test.mbtx
```

Mooncakes gates package and validate the CLI source. Addon gates package, dry-run and install facade/platform tarballs into a clean
directory, then load CJS/ESM and type-check the installed declarations. CLI
archives target Windows x64, Linux x64 glibc and macOS ARM64. No registry publish
is performed by these tests. See [engineering](docs/en/development.md),
[executed validation](docs/validation.md), [benchmarks](docs/performance.md),
and [roadmap](docs/roadmap.md).

MIT licensed; bundled parser, Unicode, Node-API, async and libuv notices are
included in distribution archives. See [LICENSE](LICENSE).
