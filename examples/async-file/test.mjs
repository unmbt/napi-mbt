import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);
const { mkdtemp, rm } = await import('node:fs/promises');
const { tmpdir } = await import('node:os');
const { join } = await import('node:path');
const dir = await mkdtemp(join(tmpdir(), 'napi-example-'));
try {
 const path = join(dir, 'input');
 const data = Buffer.from('Moon');
 assert.equal((await addon.readFile(path, data)).toString(), 'Moon');
 const controller = new AbortController(); const reason = new Error('cancel');
 const pending = addon.suspend(1000, { signal: controller.signal });
 // Let the adapter publish its pending operation before cancellation. This
 // keeps the standalone sample deterministic across Node event-loop hosts.
 await new Promise(resolve => setImmediate(resolve));
 controller.abort(reason);
 await assert.rejects(pending, e => e === reason);
 // The abort callback settles the Promise before the cancelled MoonBit task
 // finishes unwinding. Give the adapter one turn to release that task before
 // reusing the same environment for the recovery read.
 await new Promise(resolve => setImmediate(resolve));
 assert.equal((await addon.readFile(path, data)).toString(), 'Moon');
} finally { await rm(dir, { recursive: true, force: true }); }
console.log('async-file passed');
