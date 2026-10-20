import addon from './index.mjs';
const result: number = addon.add(1, 2);
// @ts-expect-error numeric arguments required
addon.add('1', 2);
