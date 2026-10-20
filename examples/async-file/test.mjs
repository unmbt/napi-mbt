import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);
const { mkdtemp, writeFile, rm } = await import('node:fs/promises');
const { tmpdir } = await import('node:os');
const { join } = await import('node:path');
const dir = await mkdtemp(join(tmpdir(), 'napi-example-'));
try {
 const path = join(dir, 'input'); await writeFile(path, 'Moon');
 assert.equal((await addon.read(path, 0)).toString(), 'Moon');
 const controller = new AbortController(); const reason = new Error('cancel');
 const pending = addon.read(path, 1000, { signal: controller.signal }); controller.abort(reason);
 await assert.rejects(pending, e => e === reason);
 assert.equal((await addon.read(path, 0)).toString(), 'Moon');
} finally { await rm(dir, { recursive: true, force: true }); }
console.log('async-file passed');
