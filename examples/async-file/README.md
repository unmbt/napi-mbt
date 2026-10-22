# async-file

Read a file asynchronously, cancel a pending operation, then recover with another request.

From the napi-mbt repository root:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/async-file ../async-file
cd ../async-file
pnpm test
```

The destination is a standalone project; the installed CLI supplies runtime boilerplate.
See `lib.mbt` for the MoonBit API, `test.mjs` for CJS/ESM behavior, and
`consumer.mts` for valid and invalid TypeScript calls.
