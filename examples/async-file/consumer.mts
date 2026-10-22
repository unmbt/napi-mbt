import addon from './index.mjs';
const pending: Promise<Buffer> = addon.readFile('input', Buffer.from('Moon'));
const suspend: Promise<string> = addon.suspend(1, { signal: new AbortController().signal });
// @ts-expect-error invalid delay
addon.suspend('1');
