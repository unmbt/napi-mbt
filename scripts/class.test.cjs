'use strict';
const assert = require('assert');
const path = require('node:path');
const { Worker } = require('node:worker_threads');
const modulePath = path.resolve(process.argv[2] || '.napi-mbt/class-smoke/napi_mbt.node');
const addon = require(modulePath);
const second = require(path.join(path.dirname(modulePath), 'second.node'));
assert.throws(() => addon.read_counter(new second.Counter(1)), e => e.code === 'ERR_NAPI_RECEIVER');
const { Counter, Other } = addon;
const counter = new Counter(3);
assert.strictEqual(counter.value, 3);
assert.strictEqual(counter.increment(2), 5);
counter.value = 10;
assert.strictEqual(counter.value, 10);
assert.strictEqual(counter.hidden, undefined);
assert.strictEqual(counter.copy().value, 10);
assert(Counter.twice(4) instanceof Counter);
assert.strictEqual(Counter.twice(4).value, 8);
assert.throws(() => Counter(1), e => e.code === 'ERR_NAPI_CONSTRUCTOR');
assert.throws(() => new Counter('x'), TypeError);
assert.throws(() => Counter.prototype.increment.call({}, 1), e => e.code === 'ERR_NAPI_RECEIVER');
assert.throws(() => Counter.prototype.increment.call(new Other(1), 1), e => e.code === 'ERR_NAPI_RECEIVER');
assert.throws(() => addon.read_counter(Object.create(Counter.prototype)), e => e.code === 'ERR_NAPI_RECEIVER');
assert.strictEqual(addon.read_counter(counter), 10);
const other = new Other(1);
assert.throws(() => { other.value = 2; }, TypeError);
counter.dispose();
counter.dispose();
assert.throws(() => counter.value, e => e.code === 'ERR_NAPI_DISPOSED');
assert.throws(() => counter.increment(1), e => e.code === 'ERR_NAPI_DISPOSED');
assert.throws(() => { counter.value = 2; }, e => e.code === 'ERR_NAPI_DISPOSED');
assert.throws(() => addon.read_counter(counter), e => e.code === 'ERR_NAPI_DISPOSED');
assert.throws(() => Counter.prototype.dispose.call({}), e => e.code === 'ERR_NAPI_RECEIVER');
for (let i = 0; i < 10000; i++) new Counter(i).dispose();
async function collect() {
  for (let i = 0; i < 8; i++) {
    const worker = new Worker(`const { parentPort } = require('node:worker_threads'); const a = require(${JSON.stringify(modulePath)}); const values = Array.from({length: 1000}, (_, i) => new a.Counter(i)); parentPort.postMessage('ready'); setInterval(() => values[0].increment(1), 1000);`, { eval: true });
    await new Promise((resolve, reject) => { worker.once('message', resolve); worker.once('error', reject); });
    await worker.terminate();
  }
  for (let i = 0; i < 10; i++) { global.gc(); await new Promise(resolve => setImmediate(resolve)); }
  // Two retained constructors and the two explicitly retained JS objects.
  assert.strictEqual(addon.resources(), 4);
  assert.strictEqual(other.value, 1);
  assert.throws(() => counter.value, e => e.code === 'ERR_NAPI_DISPOSED');
}
collect().catch(error => { console.error(error); process.exitCode = 1; });
