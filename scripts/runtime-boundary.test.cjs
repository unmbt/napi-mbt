const assert = require('node:assert/strict');
const path = require('node:path');
const binary = path.resolve(process.argv[2] || path.join(__dirname, '../.napi-mbt/boundary-smoke/napi_mbt.node'));
const addon = require(binary);
assert.throws(() => require(path.join(path.dirname(binary), 'registration-failure.node')), error => error.code === 'ERR_NAPI_REGISTER' && /Creating export/.test(error.context));
function fails(fn, kind, code) {
  assert.throws(fn, error => error instanceof kind && error.code === code && typeof error.status === 'number' && typeof error.context === 'string');
  assert.equal(addon.view_count(), 0);
}
for (const value of ['1', null, undefined, {}, [], true, 1n]) {
  const before = addon.effect_count();
  fails(() => addon.identity(value), TypeError, 'ERR_NAPI_TYPE');
  assert.equal(addon.effect_count(), before);
}
for (const value of [0.1, -0.5, NaN, Infinity, -Infinity, 2147483648, -2147483649]) {
  const before = addon.effect_count();
  fails(() => addon.borrow(Buffer.alloc(1), value), RangeError, 'ERR_NAPI_INT_RANGE');
  fails(() => addon.two_borrows(Buffer.alloc(1), Buffer.alloc(1), value), RangeError, 'ERR_NAPI_INT_RANGE');
  assert.equal(addon.effect_count(), before);
}
for (const value of [-2147483648, 2147483647, 0, 42]) assert.equal(addon.identity(value), value);
for (const value of [NaN, Infinity, -Infinity, -0]) assert.ok(Object.is(addon.echo_double(value), value));
assert.equal(addon.tsfn_statuses(), true);
fails(() => addon.tsfn_failure(), Error, 'ERR_NAPI_TSFN');
fails(() => addon.identity(), TypeError, 'ERR_NAPI_ARGUMENTS');
const before = addon.effect_count();
fails(() => addon.borrow(Buffer.alloc(1), 888), Error, 'ERR_NAPI_STATUS');
assert.equal(addon.effect_count(), before);
global.boundaryOriginal = new SyntaxError('original exception');
assert.throws(() => addon.borrow(Buffer.alloc(1), 777), error => error === global.boundaryOriginal);
assert.equal(addon.view_count(), 0);
assert.equal(addon.effect_count(), before);
delete global.boundaryOriginal;
fails(() => addon.borrow(Buffer.alloc(1), 999), Error, 'ERR_NAPI_STATUS');
assert.equal(addon.effect_count(), before + 1);
fails(() => addon.saved_load(), Error, 'ERR_NAPI_BUFFER_EXPIRED');
fails(() => addon.throw_borrow(Buffer.alloc(1)), Error, 'ERR_NAPI_CALL');
fails(() => addon.saved_load(), Error, 'ERR_NAPI_BUFFER_EXPIRED');
fails(() => addon.load(Buffer.alloc(1), -1), RangeError, 'ERR_NAPI_BUFFER_BOUNDS');
fails(() => addon.load(Buffer.alloc(0), 0), RangeError, 'ERR_NAPI_BUFFER_BOUNDS');
assert.deepEqual(addon.bytes(Buffer.alloc(0)), Buffer.alloc(0));
assert.deepEqual(addon.bytes(Buffer.from([1, 2, 3, 4]).subarray(1, 3)), Buffer.from([2, 3]));
const backing = new ArrayBuffer(8);
const detached = Buffer.from(backing);
structuredClone(backing, { transfer: [backing] });
fails(() => addon.bytes(detached), Error, 'ERR_NAPI_BUFFER_DETACHED');
fails(() => addon.load(detached, 0), Error, 'ERR_NAPI_BUFFER_DETACHED');
for (let i = 0; i < 10000; i++) {
  assert.equal(addon.borrow(Buffer.alloc(4), 42), 42);
  fails(() => addon.borrow(Buffer.alloc(4), 0.5), RangeError, 'ERR_NAPI_INT_RANGE');
}
assert.equal(addon.view_count(), 0);
console.log('Runtime conversion, pending exception, borrow cleanup and detachment tests passed');
