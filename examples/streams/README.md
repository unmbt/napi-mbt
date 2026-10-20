# Async iterators and Web streams

Requires Node 18 or later. Install the CLI and materialize this standalone addon:

```sh
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
moon run examples/setup.mbtx examples/streams ../streams
cd ../streams
npm test
```

`range` produces one item for each read. `sum` accepts an AsyncIterable or Web
ReadableStream. Use `for await` or `toReadableStream({ signal })` on an output,
once per iterator. Early `break`, `return`, stream cancellation and environment
shutdown share the closing path. Production never runs ahead of demand.
