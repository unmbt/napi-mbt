import addon from './index.mjs';
const pending: Promise<Buffer> = addon.read('input', 1);
addon.read('input', 1, { signal: new AbortController().signal });
// @ts-expect-error invalid delay
addon.read('input', '1');
