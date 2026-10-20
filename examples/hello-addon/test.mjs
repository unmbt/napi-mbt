import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);
assert.equal(addon.add(20, 22), 42);
assert.throws(() => addon.add(1.5, 2), { code: 'ERR_NAPI_INT_RANGE' });
console.log('hello-addon passed');
