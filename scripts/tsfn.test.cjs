const assert = require('node:assert/strict');
const { resolve } = require('node:path');
const { Worker } = require('node:worker_threads');
const binary = resolve(process.argv[2] || '.napi-mbt/tsfn-smoke/napi_mbt.node');
const addon = require(binary);
const seen = [];
global.__napiTsfnTest = value => seen.push(value);
async function until(predicate) {
  const deadline = Date.now() + 10000;
  while (!predicate()) {
    assert.ok(Date.now() < deadline, 'native thread cleanup timed out');
    await new Promise(resolve => setTimeout(resolve, 2));
  }
}
async function main() {
  for (let round = 0; round < 20; round++) {
    const finalized = addon.threadStats(4), delivered = seen.length;
    assert.equal(addon.start(0), 0);
    await until(() => addon.threadStats(4) === finalized + 1);
    assert.deepEqual(seen.slice(delivered), Array.from({ length: 16 }, (_, i) => i));
    const full = addon.threadStats(5);
    assert.equal(addon.start(1), 0);
    await until(() => addon.threadStats(4) === finalized + 2);
    assert.equal(addon.threadStats(5), full + 1);
    const closing = addon.threadStats(6);
    assert.equal(addon.start(2), 0);
    await until(() => addon.threadStats(4) === finalized + 3);
    assert.equal(addon.threadStats(6), closing + 1);
    assert.equal(addon.threadStats(0), addon.threadStats(1), 'every C payload freed exactly once');
    assert.equal(addon.threadStats(8), 0);
  }
  for (let round = 0; round < 12; round++) {
    const finalized = addon.threadStats(4);
    const worker = new Worker(`
      const { parentPort, workerData } = require('node:worker_threads');
      global.__napiTsfnTest = () => {};
      const addon = require(workerData);
      if (addon.start(3) !== 0) throw new Error('native start');
      parentPort.postMessage('started');
      setInterval(() => {}, 1000);
    `, { eval: true, workerData: binary });
    await new Promise((resolve, reject) => { worker.once('message', resolve); worker.once('error', reject); });
    await worker.terminate();
    await until(() => addon.threadStats(4) === finalized + 1 && addon.threadStats(8) === 0);
    assert.equal(addon.threadStats(0), addon.threadStats(1));
  }
  console.log('TSFN counters:', Array.from({length: 13}, (_, i) => addon.threadStats(i)));
  assert.equal(addon.threadStats(7), 0, 'no unexpected Node-API status');
  assert.equal(addon.threadStats(9), 0, 'callbacks run on their owner Node thread');
  console.log('C-thread TSFN delivery, queue full, acquire/release, abort and shutdown passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
