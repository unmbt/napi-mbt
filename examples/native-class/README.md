# native-class

A native Counter with a property, factory and explicit idempotent disposal.

From the napi-mbt repository root:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/native-class ../native-class
cd ../native-class
pnpm test
```

The destination is a standalone project; the installed CLI supplies runtime boilerplate.
See `lib.mbt` for the MoonBit API, `test.mjs` for CJS/ESM behavior, and
`consumer.mts` for valid and invalid TypeScript calls.
