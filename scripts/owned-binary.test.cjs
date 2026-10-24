const assert = require('node:assert/strict');
const { resolve } = require('node:path');
const { MessageChannel } = require('node:worker_threads');
const addon = require(resolve(process.argv[2] || '.napi-mbt/owned-binary-smoke/napi_mbt.node'));
function detach(buffer) {
  const { port1, port2 } = new MessageChannel();
  port1.postMessage(buffer, [buffer]); port1.close(); port2.close();
}
async function main() {
  for (const Type of [Uint8Array, Int32Array, Uint32Array, Float32Array, Float64Array, BigInt64Array, BigUint64Array]) {
    const echo = addon[`echo_${Type.name}`];
    const delayed = addon[`async_${Type.name}`];
    const floating = Type === Float32Array || Type === Float64Array;
    const original = new Type(floating ? [-0, NaN, Infinity, -Infinity, 1 / 3] : (Type === BigInt64Array ? [0n, 1n, -1n, 9223372036854775807n] : Type === BigUint64Array ? [0n, 1n, 18446744073709551615n] : [0, 1, -1, 2147483647, 4294967295]));
    const copy = echo(original);
    assert.ok(copy instanceof Type); assert.notEqual(copy.buffer, original.buffer);
    assert.deepEqual(copy, original);
    copy[0] = floating ? 12 : (Type === BigInt64Array || Type === BigUint64Array ? 12n : 12); assert.equal(original[0], floating ? -0 : (Type === BigInt64Array || Type === BigUint64Array ? 0n : 0));
    const view = original.subarray(1, 4);
    assert.deepEqual(echo(view), view);
    assert.equal(echo(new Type()).length, 0);
    for (const invalid of [null, undefined, [], {}, new DataView(new ArrayBuffer(8)), new Uint16Array(2)]) assert.throws(() => echo(invalid), TypeError);
    const shared = new Type(new SharedArrayBuffer(Type.BYTES_PER_ELEMENT * 2));
    assert.throws(() => echo(shared), TypeError);
    const transferred = new Type(2); detach(transferred.buffer);
    assert.throws(() => echo(transferred));
    const inputValues = Type === BigInt64Array || Type === BigUint64Array ? [1n, 2n] : [1, 2];
    const input = new Type(inputValues); const pending = delayed(input);
    input[0] = Type === BigInt64Array || Type === BigUint64Array ? 99n : 99; detach(input.buffer);
    assert.deepEqual(await pending, new Type(inputValues));
    await assert.rejects(delayed(shared), TypeError);
    for (let i = 0; i < 500; i++) echo(original);
  }
  const view = addon.echo_DataView(new DataView(new Uint8Array([1, 2, 3]).buffer, 1, 2));
  assert.ok(view instanceof DataView); assert.deepEqual(Array.from(new Uint8Array(view.buffer)), [2, 3]);
  assert.deepEqual(addon.construct(), new Int32Array([-1, 2]));
  const original = new Uint8Array([1, 2, 3]).buffer;
  const copied = addon.echo_ArrayBuffer(original);
  assert.ok(copied instanceof ArrayBuffer); assert.notEqual(copied, original);
  new Uint8Array(copied)[0] = 99; assert.equal(new Uint8Array(original)[0], 1);
  assert.equal(addon.echo_ArrayBuffer(new ArrayBuffer(0)).byteLength, 0);
  for (const invalid of [null, new Uint8Array(1), new SharedArrayBuffer(8)]) assert.throws(() => addon.echo_ArrayBuffer(invalid), TypeError);
  const pending = addon.async_ArrayBuffer(original); detach(original);
  assert.deepEqual(new Uint8Array(await pending), new Uint8Array([1, 2, 3]));
  assert.throws(() => addon.echo_ArrayBuffer(original));
  const nested = addon.nested({ x: [new Int32Array([4]), null] });
  assert.deepEqual(nested.x, [new Int32Array([4]), null]);
  if (global.gc) global.gc();
  console.log('Owned binary copies, offsets, detach/shared rejection and async snapshots passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
