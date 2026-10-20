'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { Worker } = require('node:worker_threads');
const { setTimeout: delay } = require('node:timers/promises');
const dir = path.resolve(process.argv[2]);
const addon = require(path.join(dir, 'index.cjs'));
const alive = pid => { try { process.kill(pid, 0); return true; } catch (error) { if (error.code === 'ESRCH') return false; throw error; } };
async function gone(pid) { for (let i = 0; i < 200; i++) { if (!alive(pid)) return; await delay(10); } assert.fail(`child ${pid} survived teardown`); }
(async () => {
  const esm = await import(pathToFileURL(path.join(dir, 'index.mjs')));
  assert.equal(esm.default, addon, 'CJS/ESM share one pool');
  assert.equal(Object.keys(addon).some(name => name.startsWith('__napi_mbt_')), false);
  assert.equal(addon.parentCalls(), 0);
  let ticks = 0;
  const timer = setInterval(() => { ticks++; }, 5);
  const [first, second] = await Promise.all([addon.compute(250), addon.compute(250)]);
  clearInterval(timer);
  assert.notEqual(first[0], second[0]);
  assert.notEqual(first[0], process.pid);
  assert.ok(Math.max(first[2], second[2]) < Math.min(first[3], second[3]), 'two MoonBit computations actually overlap');
  assert.ok(ticks >= 5);
  assert.equal(first[1], 1); assert.equal(second[1], 1); assert.equal(addon.parentCalls(), 0);
  assert.equal(await addon.__proto__(), 7, 'magic export names remain own properties');
  const data = { text: 'a\ud800\u0000字', integers: [9007199254740993n, 4294967295], binary: Buffer.from([1,2,3]), floats: new Float64Array([NaN,-0,Infinity]), buffer: new Uint8Array([4,5]).buffer, json: { value: [true, null] } };
  const expected = { ...data, binary: Buffer.from(data.binary), floats: new Float64Array(data.floats), buffer: data.buffer.slice(0), json: {value:[true,null]} };
  const copy = addon.echo(data);
  data.binary.fill(9); data.floats.fill(9); new Uint8Array(data.buffer).fill(9); data.json.value.push(9);
  assert.deepEqual(await copy, expected);
  const marker = new Error('getter identity');
  await assert.rejects(addon.echo({ get text() { throw marker; } }), error => error === marker);
  await assert.rejects(addon.compute(1.5), RangeError);
  const cyclic = { ...expected, json: {} }; cyclic.json.self = cyclic.json;
  await assert.rejects(addon.echo(cyclic));
  const shared = { ...expected, floats: new Float64Array(new SharedArrayBuffer(8)) };
  await assert.rejects(addon.echo(shared));
  const detached = new ArrayBuffer(1); structuredClone(detached, {transfer: [detached]});
  await assert.rejects(addon.echo({ ...expected, buffer: detached }));
  await assert.rejects(addon.failure(), error => error.name === 'Error' && error.code === 'ERR_NAPI_CALL' && /worker business failure/.test(error.message) && typeof error.stack === 'string');
  assert.equal(addon.parentCalls(), 0);
  const reason = { abort: true }, aborted = new AbortController(); aborted.abort(reason);
  await assert.rejects(addon.compute(100, {signal:aborted.signal}), e => e === reason);
  const active = new AbortController(), queued = new AbortController();
  const a = addon.compute(10000, { signal: active.signal });
  const b = addon.compute(250);
  const c = addon.compute(10000, { signal: queued.signal });
  const d = addon.compute(0);
  const aRejected = assert.rejects(a, e => e === reason), cRejected = assert.rejects(c, e => e === reason);
  await assert.rejects(addon.compute(0), { code: 'ERR_NAPI_WORKER_QUEUE_FULL' });
  queued.abort(reason); active.abort(reason);
  await Promise.all([aRejected, cRejected, b, d]);
  await assert.rejects(addon.compute(-1), { code: 'ERR_NAPI_WORKER_EXIT' });
  assert.ok((await addon.compute(0))[0] > 0, 'pool recovers after a crash without replay');
  const pid = await addon.processId();
  await delay(800); await gone(pid);
  assert.notEqual(await addon.processId(), pid, 'idle workers restart lazily');
  // Remove JS exit listeners and occupy the child with synchronous MoonBit work.
  // Its disconnect event cannot run; the native env hook must terminate it.
  for (let i = 0; i < 4; i++) {
    const worker = new Worker(`
      const {workerData,parentPort}=require('node:worker_threads');
      const a=require(workerData);
      (async()=>{ const pid=await a.processId(); a.compute(30000); process.removeAllListeners('exit'); setTimeout(()=>parentPort.postMessage(pid),50); })();
    `, { eval: true, workerData: path.join(dir, 'index.cjs') });
    const childPid = await new Promise((resolve,reject)=>{worker.once('message',resolve);worker.once('error',reject);});
    await worker.terminate();
    await gone(childPid);
  }
  console.log('Worker pools: parallelism, isolation, snapshot types, cancellation, crash recovery, idle and native teardown passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
