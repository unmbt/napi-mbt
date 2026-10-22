# Isolated MoonBit computations

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/worker-tasks ../worker-tasks
cd ../worker-tasks
pnpm test
```

`lib.mbt` contains an ordinary synchronous computation. `workerTasks` makes its
generated CJS/ESM package API return a cancellable Promise. Each child Node
process loads the same addon with its own MoonBit runtime and global state.
The generated worker entry is included in the npm main package. Use `index.cjs`
or `index.mjs` as the API; directly requiring the `.node` keeps synchronous calls.
The default pool starts lazily, uses at most two workers, accepts 64 queued jobs
and closes idle workers after 30 seconds. Idle workers do not keep Node running.
