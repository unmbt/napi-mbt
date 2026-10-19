'use strict';
const assert = require('node:assert/strict');
const { Worker } = require('node:worker_threads');
const modulePath = require('node:path').resolve(process.argv[2] || '.napi-mbt/callback-smoke/napi_mbt.node');
const addon = require(modulePath);
assert.equal(addon.invoke(x => x + 1, 3), 4);
assert.throws(() => addon.invoke(1, 3), TypeError);
assert.throws(() => addon.invoke(() => 'wrong', 3), TypeError);
const error = new Error('original callback error');
assert.throws(() => addon.invoke(() => { throw error; }, 3), e => e === error);
assert.equal(addon.invoke(x => addon.invoke(y => y * 2, x), 5), 10);
assert.deepEqual(addon.map_strings(xs => xs.map(x => x.toUpperCase())), ['ONE', 'TWO']);
let called = 0;
addon.notify(() => called++);
assert.equal(called, 1);
addon.retain(x => x * 3);
global.gc();
assert.equal(addon.call_saved(4), 12);
addon.clear();
assert.equal(addon.call_saved(4), -1);
let add = addon.make_adder(7);
assert.equal(add(5), 12);
assert.throws(() => add('x'), TypeError);
assert.throws(() => add(), e => e.code === 'ERR_NAPI_ARGUMENTS');
assert.throws(() => add.dispose.call({}), e => e.code === 'ERR_NAPI_RECEIVER');
add.dispose(); add.dispose();
assert.throws(() => add(1), e => e.code === 'ERR_NAPI_DISPOSED');
add = null;
let wrapped = addon.wrap(x => { wrapped.dispose(); return x + 1; });
assert.equal(wrapped(5), 6);
assert.throws(() => wrapped(5), e => e.code === 'ERR_NAPI_DISPOSED');
wrapped = null;
for (let i = 0; i < 10000; i++) {
  const f = addon.wrap(x => x + i);
  assert.equal(f(1), i + 1);
  f.dispose();
}
async function main() {
  addon.retain(x => x);
  await new Promise((resolve, reject) => {
    const worker = new Worker(`const { parentPort } = require('node:worker_threads'); const a = require(${JSON.stringify(modulePath)}); try { a.call_saved(1); throw Error('cross environment call succeeded'); } catch(e) { if(e.code !== 'ERR_NAPI_ENVIRONMENT') throw e; } a.retain(x => x * 2); parentPort.postMessage('ready');`, { eval: true });
    worker.on('error', reject); worker.on('exit', code => code ? reject(Error('worker exit '+code)) : resolve());
  });
  assert.throws(() => addon.call_saved(1), e => e.code === 'ERR_NAPI_DISPOSED');
  addon.clear();
  for (let i = 0; i < 8; i++) {
    const worker = new Worker(`const { parentPort } = require('node:worker_threads'); const a = require(${JSON.stringify(modulePath)}); a.retain(x => x); const closures = Array.from({length: 100}, () => a.wrap(x => x + 1)); parentPort.postMessage('ready'); setInterval(() => closures[0](1), 1000);`, { eval: true });
    await new Promise((resolve, reject) => { worker.once('message', resolve); worker.once('error', reject); });
    await worker.terminate();
    assert.throws(() => addon.call_saved(1), e => e.code === 'ERR_NAPI_DISPOSED');
    addon.clear();
  }
  for (let i = 0; i < 10; i++) { global.gc(); await new Promise(resolve => setImmediate(resolve)); }
  assert.equal(addon.resources(), 0, JSON.stringify([1,2,3,4].map(k => addon.resource_kind(k))));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
