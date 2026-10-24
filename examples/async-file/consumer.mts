import addon from './index.mjs';
const pending: Promise<Buffer> = addon.readFile('input', Buffer.from('Moon'));
const suspend: Promise<string> = addon.suspend(1, { signal: new AbortController().signal });
// @ts-expect-error invalid delay
addon.suspend('1');
const twice: Promise<number> = addon.twice(Promise.resolve(21));
void twice;
// @ts-expect-error Promise payload must be a number
addon.twice(Promise.resolve('21'));
