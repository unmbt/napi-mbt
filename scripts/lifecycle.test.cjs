const assert = require('assert');
const path = require('path');
const { Worker, isMainThread, workerData } = require('worker_threads');
const filename = path.resolve(workerData || '.napi-mbt/lifecycle-smoke/napi_mbt.node');
const addon = require(filename);
if (!isMainThread) {
  for (let i = 0; i < 10000; i++) addon.bump();
} else {
  assert.strictEqual(addon.bump(), 1);
  assert.strictEqual(addon.environments(), 1);
  const timeout = setTimeout(() => { console.error('Worker lifecycle timeout'); process.exit(1); }, 20000);
  Promise.all(Array.from({ length: 8 }, () => new Promise((resolve, reject) => {
    const worker = new Worker(__filename, { workerData: filename });
    worker.once('error', reject);
    worker.once('exit', code => code === 0 ? resolve() : reject(new Error('worker exit ' + code)));
  }))).then(() => {
    assert.strictEqual(addon.bump(), 80002);
    assert.strictEqual(addon.environments(), 1);
    assert.strictEqual(addon.resources(), 0);
    clearTimeout(timeout);
  }).catch(error => { console.error(error); process.exitCode = 1; clearTimeout(timeout); });
}
