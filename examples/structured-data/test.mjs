import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);
assert.deepEqual(addon.profile({ name: 'Moon' }), { name: 'Moon', age: null });
assert.deepEqual(addon.event({ tag: 'Message', args: ['hello'] }), { tag: 'Message', args: ['hello'] });
assert.throws(() => addon.profile({ age: 1 }));
console.log('structured-data passed');
