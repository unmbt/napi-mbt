import addon from './index.mjs';
const result: Buffer = addon.copy(Buffer.from([1]));
addon.increment(result);
// @ts-expect-error Buffer required
addon.increment('data');
