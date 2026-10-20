'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const directory = path.resolve(process.argv[2] || '.napi-mbt/combined-smoke');
const a = require(path.join(directory, 'index.cjs'));
(async () => {
  const esm = await import(pathToFileURL(path.join(directory,'index.mjs')).href);
  assert.strictEqual(a.pipeline, esm.pipeline);
  assert.equal((await a.settle(Promise.resolve(Buffer.from('moonbit')))).toString(),'MOONBIT');
  const error = {source:'reject'};
  await assert.rejects(a.settle(Promise.reject(error)), e=>e===error);
  const collected = [];
  async function* source() { yield Buffer.from('ab'); yield Buffer.from('cd'); }
  for await (const chunk of a.pipeline(source()).toReadableStream()) {
    const copied = new Uint8Array(chunk);
    const pending = a.digest(copied);
    copied.fill(0);
    collected.push([chunk.toString(), (await pending).__proto__]);
  }
  assert.deepEqual(collected,[['AB',[131,2]],['CD',[135,2]]]);
  assert.equal(a.closed(),1);
  let cancelled = 0;
  const controller = new AbortController();
  const stream = a.pipeline(new ReadableStream({cancel(){cancelled++;}})).toReadableStream({signal:controller.signal});
  const reader = stream.getReader();
  const pending = reader.read();
  await new Promise(r=>setTimeout(r,20));
  controller.abort(error);
  await assert.rejects(pending,e=>e===error);
  reader.releaseLock();
  for(let i=0;i<50 && cancelled===0;i++) await new Promise(r=>setTimeout(r,5));
  assert.equal(cancelled,1);
  assert.equal(a.closed(),2);
  assert.equal((await esm.uppercase(Buffer.from('recover'))).toString(),'RECOVER');
  assert.deepEqual((await a.digest(new Uint8Array([255]))).__proto__,[255,1]);
  console.log('Combined Promise/native-task/stream/worker consumers passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
