import assert from 'node:assert/strict';
import addon from './index.mjs';
import { createRequire } from 'node:module';
const cjs = createRequire(import.meta.url)('./index.cjs');
for (const name of Object.keys(addon)) assert.equal(cjs[name], addon[name]);
const original = Buffer.from([1, 2]); const copy = addon.copy(original);
addon.increment(copy);
assert.deepEqual(original, Buffer.from([1, 2]));
assert.deepEqual(copy, Buffer.from([2, 2]));
assert.deepEqual(addon.copy(Buffer.alloc(0)), Buffer.alloc(0));
assert.throws(() => addon.copy('not binary data'));
for (const [name, Type, values] of [
  ['int8', Int8Array, [-128, 127]], ['uint8', Uint8Array, [0, 255]],
  ['clamped', Uint8ClampedArray, [0, 255]], ['int16', Int16Array, [-32768, 32767]],
  ['uint16', Uint16Array, [0, 65535]], ['int32', Int32Array, [-2147483648, 2147483647]],
  ['uint32', Uint32Array, [0, 4294967295]], ['float32', Float32Array, [NaN, -0, Infinity]],
  ['float64', Float64Array, [NaN, -0, Infinity]],
]) {
  const source = new Type([0, ...values, 0]).subarray(1, 1 + values.length);
  const result = addon[name](source);
  assert.equal(result instanceof Type, true);
  assert.deepEqual([...result], values);
  assert.notEqual(result.buffer, source.buffer);
  result[0] = 1;
  assert.deepEqual([...source], values);
  assert.equal(addon[name](new Type()).length, 0);
}
const buffer = Uint8Array.from([1, 2]).buffer;
const bufferCopy = addon.arrayBuffer(buffer);
new Uint8Array(bufferCopy)[0] = 99;
assert.equal(new Uint8Array(buffer)[0], 1);
assert.throws(() => addon.int16(new Uint16Array(2)));
console.log('binary-processing passed');
