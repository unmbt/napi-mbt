'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { setTimeout: delay } = require('node:timers/promises');
const file = path.resolve(process.argv[2] || '.napi-mbt/js-promises-smoke/napi_mbt.node');
const addon = require(file);
const timeout = setTimeout(() => { console.error('Promise input timeout'); process.exit(1); }, 30000);
process.on('unhandledRejection', error => { console.error('Unexpected unhandled rejection', error); process.exit(1); });
(async () => {
  const baseline = addon.resources();
  assert.equal(await addon.twice(Promise.resolve(4)), 8);
  assert.equal(await addon.parallel(delay(20).then(() => 3)), 6);
  assert.deepEqual(await addon.binary(Promise.resolve(new Int32Array([-1,2]))), new Int32Array([-1,2]));
  assert.deepEqual(await addon.nested(Promise.resolve({x:[42n,{a:[null,true]}]})), {x:[42n,{a:[null,true]}]});
  await assert.rejects(addon.twice(2), TypeError);
  await assert.rejects(addon.twice({then(resolve){resolve(2);}}), TypeError);
  await assert.rejects(addon.twice(Promise.resolve(2.5)), RangeError);
  for (const reason of [{ marker: 1 }, new Error('original'), undefined, null, 42, 'text']) {
    await assert.rejects(addon.twice(Promise.reject(reason)), error => Object.is(error, reason));
  }
  const marker = new Error('then getter');
  const broken = Promise.resolve(1);
  Object.defineProperty(broken, 'then', { get() { throw marker; } });
  await assert.rejects(addon.twice(broken), error => error === marker);
  await assert.rejects(addon.dispose(new Promise(() => {})), {code:'ERR_NAPI_DISPOSED'});
  addon.store(Promise.resolve(11));
  const foreign = new Worker(`const {parentPort,workerData}=require('node:worker_threads'); const a=require(workerData); try {a.disposeStored(); parentPort.postMessage('unexpected success');} catch(error) {parentPort.postMessage(error.code);}`, { eval:true, workerData:file });
  const foreignResult = await new Promise((resolve,reject) => {foreign.once('message',resolve);foreign.once('error',reject);});
  assert.equal(foreignResult, 'ERR_NAPI_ENVIRONMENT');
  await foreign.terminate();
  assert.equal(await addon.storedWait(), 11);
  addon.disposeStored();
  for (let i = 0; i < 30; i++) {
    let resolve, reject;
    const input = new Promise((ok,no) => {resolve=ok;reject=no;});
    const controller = new AbortController(), reason = { iteration: i };
    const output = addon.twice(input, {signal:controller.signal});
    const rejected = assert.rejects(output, error => error === reason);
    await delay(2);
    controller.abort(reason);
    await rejected;
    if (i % 2) resolve(7); else reject(new Error('late ignored rejection'));
    await delay(2);
  }
  for (let i = 0; i < 8; i++) {
    const worker = new Worker(`const {parentPort,workerData}=require('node:worker_threads'); const a=require(workerData); a.twice(new Promise(()=>{})); setTimeout(()=>parentPort.postMessage('waiting'),10);`, { eval:true, workerData:file });
    await new Promise((resolve,reject) => {worker.once('message',resolve);worker.once('error',reject);});
    await worker.terminate();
  }
  for (let i = 0; i < 8; i++) { global.gc?.(); await delay(10); }
  assert.equal(addon.resources(), baseline, 'Promise handles and reactions return to baseline');
  clearTimeout(timeout);
  console.log('Typed JS Promise values, rejection identity, late cancellation and teardown passed');
})().catch(error => { console.error(error); process.exitCode=1; clearTimeout(timeout); });
