import assert from 'node:assert/strict';
import addon, { uppercase, uppercaseFromMoonBit } from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const run of [uppercase, uppercaseFromMoonBit, addon.uppercase, cjs.uppercase]) {
  assert.equal((await run(Buffer.from('Hello native tasks!'))).toString(), 'HELLO NATIVE TASKS!');
  const controller = new AbortController(), reason = new Error('cancelled');
  controller.abort(reason);
  await assert.rejects(run(Buffer.alloc(0), { signal: controller.signal }), error => error === reason);
}
console.log('Native tasks example passed');
