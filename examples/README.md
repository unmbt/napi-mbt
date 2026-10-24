# Standalone addon examples

Install the CLI with `moon install unmbt/napi-mbt/cmd/napi-mbt-cli`.
From this repository, materialize a complete project in a **new** directory:

```sh
moon run examples/setup.mbtx examples/hello-addon ../my-addon
cd ../my-addon
pnpm test
```

The helper obtains runtime boilerplate from the installed CLI, overlays the
example's own sources/configuration, resolves dependencies, builds and runs the
example. The resulting directory is a standalone addon project. Nothing is
written into the example source. An optional final argument selects an absolute
CLI executable. No reference to the napi-mbt checkout remains in the project.

| Project | Purpose | N-API |
| --- | --- | ---: |
| [hello-addon](hello-addon/README.md) | CJS/ESM imports and strict scalar arguments | 4 |
| [structured-data](structured-data/README.md) | Struct/enum, records, JSON, tuples, Date, Symbol, Set and synchronous iterators | 5 |
| [native-class](native-class/README.md) | Constructors, properties, factories and disposal | 4 |
| [callbacks](callbacks/README.md) | Stored synchronous callbacks, returned closures and exceptions | 4 |
| [async-file](async-file/README.md) | File I/O, cancellation, recovery and typed JS Promise input | 8 |
| [binary-processing](binary-processing/README.md) | Owned Bytes, borrowed BufferView, numeric TypedArrays and ArrayBuffer | 7 |
| [native-tasks](native-tasks/README.md) | C worker-pool computation, cancellation and MoonBit async calls | 8 |
| [worker-tasks](worker-tasks/README.md) | Pure MoonBit computation in isolated Node processes | 8 |
| [streams](streams/README.md) | AsyncIterable/Web stream input, demand-driven output and cancellation | 8 |
| [advanced-api](advanced-api/README.md) | Low-level handles, External, DataView/BigInt arrays, N-API 8/9/10 helpers and typed TSFN | 10 |

Use Node 22.14+ (or Node 24/26) for the whole suite; `advanced-api` requires
Node-API 10. Build with the matching host compiler described in
[support](../docs/support.md). To try changes from this checkout, run
`moon install ./cmd/napi-mbt-cli` before setup instead of installing the published version.

Each directory includes MoonBit source, JS assertions in `test.mjs` and
TypeScript calls in `consumer.mts`. The consumer is a type-checking fixture;
its deliberately invalid calls must not be run as JavaScript. The setup command
builds and runs the JS tests; the all-example command below also checks TypeScript
with both NodeNext and Bundler resolution.

The [English usage guide](../docs/en/usage.md) and [中文用法导航](../docs/zh/usage.md)
map these projects to common tasks. For actual native-thread TSFN producers,
see the [C/Windows/pthread fixture](../scripts/fixtures/tsfn_threads.h) and
[thread guide](../docs/tsfn.md); the typed wrapper encodes on the MoonBit owner thread.

`moon run scripts/examples-test.mbtx` packages and installs the current CLI into
a temporary directory and builds every example, including TypeScript positive
and negative consumers. Node/pnpm are consumer tools; no package is published for the CLI.
