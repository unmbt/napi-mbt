import addon from './index.mjs';
const values: ReadableStream<number> = addon.range(5).toReadableStream();
const total: Promise<number> = addon.sum(values);
void total;
// @ts-expect-error stream elements must be numbers
addon.sum(new ReadableStream<string>());
