import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { Worker } from 'node:worker_threads';
import { once } from 'node:events';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);

const input = { name: 'demo', add(value) { return value + 40; } };
assert.deepEqual(addon.objectInfo(input), { name: 'demo', keyCount: 2 });
assert.equal(addon.callMethod(input), 42);
assert.deepEqual(addon.makeArray(7), [7, 'from-moonbit']);
assert.equal(addon.escapeValue('scoped 🚀'), 'scoped 🚀');
class Box { constructor(value) { this.value = value; } }
const box = addon.construct(Box);
assert.equal(box instanceof Box, true);
assert.equal(box.value, 42);
addon.defineAnswer(box);
assert.deepEqual(Object.getOwnPropertyDescriptor(box, 'answer'), {
  value: 42, writable: false, enumerable: true, configurable: false,
});
const inherited = Object.create({ inherited: true });
inherited.name = 'own';
assert.equal(addon.objectInfo(inherited).keyCount, 2);
const getterError = new Error('getter identity');
assert.throws(() => addon.objectInfo({ get name() { throw getterError; } }), e => e === getterError);
assert.throws(() => addon.objectInfo(42));

const externalBuffer = addon.externalBuffer();
assert.equal(Buffer.isBuffer(externalBuffer), true);
externalBuffer[0] = 'E'.charCodeAt(0);
assert.equal(externalBuffer.toString(), 'External');
const externalArrayBuffer = addon.externalArrayBuffer();
assert.equal(externalArrayBuffer instanceof ArrayBuffer, true);
new Uint8Array(externalArrayBuffer)[0] = 'A'.charCodeAt(0);
assert.equal(new TextDecoder().decode(externalArrayBuffer), 'Arraybuffer');
assert.equal(addon.externalString(), 'café');
const literal = addon.literalBuffer();
literal[0] = 76;
assert.equal(literal.toString(), 'Literal');
assert.equal(addon.literalBuffer().toString(), 'literal');
new Uint8Array(addon.literalArrayBuffer())[0] = 76;
assert.equal(new TextDecoder().decode(addon.literalArrayBuffer()), 'literal');

let external = addon.makeExternal();
assert.equal(addon.externalIdentity(external), external);
assert.throws(() => addon.externalIdentity({}));
// Release the ESM top-level root so GC can reclaim Node's ExternalWrapper too.
// Its weak callback does not run for a still-rooted value at isolate disposal.
external = null;

const view = addon.dataViewRoundtrip(new DataView(Uint8Array.from([1, 2, 3]).buffer));
assert.deepEqual([...new Uint8Array(view.buffer)], [1, 2, 3]);
assert.deepEqual([...addon.bigInt64Roundtrip(new BigInt64Array([-2n, 3n]))], [-2n, 3n]);
assert.deepEqual([...addon.bigUint64Roundtrip(new BigUint64Array([2n, 3n]))], [2n, 3n]);
const offsetInput = new DataView(Uint8Array.from([9, 1, 2, 9]).buffer, 1, 2);
const snapshot = addon.dataViewRoundtrip(offsetInput);
offsetInput.setUint8(0, 99);
assert.deepEqual([...new Uint8Array(snapshot.buffer)], [1, 2]);
snapshot.setUint8(1, 88);
assert.equal(offsetInput.getUint8(1), 2);
assert.equal(addon.dataViewRoundtrip(new DataView(new ArrayBuffer(0))).byteLength, 0);
for (const length of [0, 4]) {
  const buffer = new ArrayBuffer(length);
  const detachedView = new DataView(buffer);
  addon.detachArrayBuffer(buffer);
  assert.throws(() => addon.dataViewRoundtrip(detachedView));
  assert.throws(() => addon.dataViewRoundtrip(new DataView(new SharedArrayBuffer(length))));
}
assert.throws(() => addon.dataViewRoundtrip(new Uint8Array(3)));
assert.throws(() => addon.bigInt64Roundtrip(new BigUint64Array(1)));
assert.deepEqual([...addon.bigInt64Roundtrip(new BigInt64Array([-(2n ** 63n), 2n ** 63n - 1n]))], [-(2n ** 63n), 2n ** 63n - 1n]);

const tagged = {};
assert.equal(addon.freezeAndTag(tagged), true);
assert.equal(Object.isFrozen(tagged), true);
const sealed = { value: 1 };
addon.seal(sealed);
assert.equal(Object.isSealed(sealed), true);
sealed.value = 2;
assert.equal(addon.globalSymbol(), Symbol.for('napi-mbt-example'));
const syntax = addon.syntaxError();
assert.equal(syntax instanceof SyntaxError, true);
assert.equal(syntax.code, 'ERR_语法\0');
assert.equal(syntax.message, '示例 syntax 🚀\0error');
assert.throws(() => addon.throwSyntaxError(), e => e instanceof SyntaxError && e.code === syntax.code && e.message === syntax.message);
const filename = addon.moduleFileName();
assert.equal(existsSync(filename.startsWith('file:') ? fileURLToPath(filename) : filename), true);
assert.equal(addon.propertyKey('属性\0🚀'), '属性\0🚀');

const source = Uint8Array.from([10, 20, 30, 40]).buffer;
assert.deepEqual([...addon.bufferFromArrayBuffer(source)], [20, 30]);
addon.bufferFromArrayBuffer(source)[0] = 99;
assert.equal(new Uint8Array(source)[1], 99);
assert.throws(() => addon.bufferFromArrayBuffer(new ArrayBuffer(1)));
const detached = new ArrayBuffer(8);
assert.equal(addon.detachArrayBuffer(detached), true);
assert.equal(addon.instanceData(), true);
assert.equal(addon.instanceData(), true);
assert.equal(addon.napiVersion() >= 10, true);

// Wait for actual callback delivery, not a particular event-loop phase.
async function delivered(start) {
  let timer;
  try {
    return await new Promise((resolve, reject) => {
      timer = setTimeout(() => reject(new Error('TSFN delivery timeout')), 5000);
      start(resolve);
    });
  } finally { clearTimeout(timer); }
}
assert.equal((await delivered(callback => {
  assert.equal(addon.typedTsfn(callback, 42), 'accepted');
})).toString(), '42');
assert.equal((await delivered(callback => {
  assert.equal(addon.boundedTsfn(callback, false), 'queue-full');
})).toString(), '1');
for (let i = 0; i < 32; i++) {
  assert.equal(addon.boundedTsfn(() => assert.fail('Aborted callback'), true), 'queue-full');
}
assert.throws(() => addon.typedTsfn(123, 1));

// Terminate with accepted payloads still queued to exercise the null-env drain.
for (let i = 0; i < 4; i++) {
  const worker = new Worker(`
    const { parentPort, workerData } = require('node:worker_threads');
    const addon = require(workerData);
    addon.boundedTsfn(() => {}, false);
    parentPort.postMessage('queued');
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);
  `, { eval: true, workerData: fileURLToPath(new URL('./index.cjs', import.meta.url)) });
  let timer;
  try {
    await Promise.race([once(worker, 'message'), new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('Worker startup timeout')), 10000);
    })]);
  } finally { clearTimeout(timer); await worker.terminate(); }
}

// Drop temporary external values and collect; finalizers also run at process exit.
for (let i = 0; i < 256; i++) {
  addon.externalBuffer(); addon.externalArrayBuffer(); addon.externalString();
  addon.literalBuffer(); addon.literalArrayBuffer();
}
for (let i = 0; i < 3; i++) {
  global.gc?.();
  await new Promise(resolve => setImmediate(resolve));
}

console.log('advanced-api passed');
