# Native background tasks

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/native-tasks ../native-tasks
cd ../native-tasks
pnpm test
```

The installed CLI supplies the versioned C header and runtime. `tasks.c` performs
ASCII conversion on Node's native worker pool, `lib.mbt` calls the same task from
a MoonBit async function, and `test.mjs` exercises CJS/ESM and cancellation.
`consumer.mts` checks the Buffer/Promise TypeScript API. The project depends on
async 0.22.4 for Promise scheduling; native execution owns only C data.
See [the task contract](../../docs/native-tasks.md) for ownership and cancellation.
