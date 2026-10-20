'use strict';
const assert = require('node:assert/strict');
const { Worker } = require('node:worker_threads');
const { setTimeout: delay } = require('node:timers/promises');
const path = require('node:path');
const file = path.resolve(process.argv[2] || '.napi-mbt/native-tasks-smoke/napi_mbt.node');
const addon = require(file);
const trace = message => { if (process.env.NAPI_MBT_TEST_TRACE) console.log(message); };
async function until(predicate) {
  for (let i = 0; i < 400; i++) { if (predicate()) return; await delay(5); }
  assert.fail('native task did not reach expected state');
}
(async () => {
  for (const run of [addon.compute, addon.wrapped]) {
    trace(`entry ${run.name}: copies and errors`);
    assert.deepEqual(await run(Buffer.alloc(0)), Buffer.alloc(0));
    const backing = Buffer.from([0, 5, 6, 7]);
    const pending = run(backing.subarray(1));
    backing.fill(9);
    assert.deepEqual(await pending, Buffer.from([5, 6, 7]));
    await assert.rejects(run('bad'), TypeError);
    await assert.rejects(run(Buffer.from([3])), { code: 'E_FIXTURE', message: 'Native failure' });
    await assert.rejects(run(Buffer.from([4])), { code: 'ERR_NAPI_NATIVE_TASK' });
    assert.deepEqual(await run(Buffer.from([0, 42])), Buffer.from([0, 42]));
    const before = addon.started();
    trace('already aborted');
    const controller = new AbortController(), reason = { cancelled: true };
    controller.abort(reason);
    await assert.rejects(run(Buffer.from([1]), { signal: controller.signal }), e => e === reason);
    assert.equal(addon.started(), before);
    const c = new AbortController();
    trace('running cancellation');
    const running = run(Buffer.from([1]), { signal: c.signal });
    const rejected = assert.rejects(running, e => e === reason);
    await until(() => addon.started() > before);
    c.abort(reason);
    await rejected;
    await until(() => addon.started() === addon.finished());
  }
  await assert.rejects(addon.unknown(Buffer.alloc(0)));
  trace('unknown and throwing getter');
  const marker = new Error('getter identity');
  await assert.rejects(addon.compute(Buffer.alloc(0), { get signal() { throw marker; } }), e => e === marker);
  // One libuv worker: this second task must be cancelled while queued.
  const before = addon.started();
  trace('queued cancellation');
  const slow = addon.compute(Buffer.from([2]));
  await until(() => addon.started() === before + 1);
  let ticks = 0;
  const timer = setInterval(() => { ticks++; }, 5);
  const controller = new AbortController();
  const reason = new Error('queued');
  const queued = addon.compute(Buffer.from([0]), { signal: controller.signal });
  const rejected = assert.rejects(queued, e => e === reason);
  await delay(20);
  controller.abort(reason);
  await rejected;
  await slow;
  clearInterval(timer);
  assert.ok(ticks >= 5, `main event loop must remain responsive (${ticks})`);
  assert.equal(addon.started(), before + 1);
  await Promise.all(Array.from({ length: 100 }, () => addon.compute(Buffer.from([0]))));
  trace('parallel completion done');
  for (let i = 0; i < 12; i++) {
    trace(`teardown ${i}`);
    const worker = new Worker(`
      const { parentPort, workerData } = require('node:worker_threads');
      const a = require(workerData);
      const n = a.started();
      a.compute(Buffer.from([2]));
      const timer = setInterval(() => {
        if (a.started() > n) { clearInterval(timer); parentPort.postMessage('started'); }
      }, 2);
    `, { eval: true, workerData: file });
    await new Promise((resolve, reject) => { worker.once('message', resolve); worker.once('error', reject); });
    await worker.terminate();
    await until(() => addon.started() === addon.finished());
  }
  global.gc?.();
  assert.equal(addon.started(), addon.finished());
  console.log('Native tasks: C-owned copies, cancellation, errors, event loop and 12 teardowns passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
