# Standalone addon examples

Install the CLI with `moon install unmbt/napi-mbt/cmd/napi-mbt-cli`.
From this repository, materialize a complete project in a **new** directory:

```sh
moon run examples/setup.mbtx examples/hello-addon ../my-addon
cd ../my-addon
npm test
```

The helper obtains runtime boilerplate from the installed CLI, overlays the
example's own sources/configuration, resolves dependencies, builds and runs the
example. The resulting directory is a standalone addon project. Nothing is
written into the example source. An optional final argument selects an absolute
CLI executable. No reference to the napi-mbt checkout remains in the project.

| Project | Purpose |
| --- | --- |
| hello-addon | CJS/ESM imports and strict scalar arguments |
| structured-data | Struct/enum input and output contracts |
| native-class | Constructors, properties, factories and disposal |
| callbacks | Stored callbacks, returned closures and exceptions |
| async-file | Native file I/O, cancellation and recovery |
| binary-processing | Owned Bytes versus synchronous borrowed BufferView |

`moon run scripts/examples-test.mbtx` packages and installs the current CLI into
a temporary directory and builds every example, including TypeScript positive
and negative consumers. Node/npm are consumer tools; no npm package is published.
