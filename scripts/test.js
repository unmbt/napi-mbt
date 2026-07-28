const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const os = require('node:os');

const addon = require('../index.js');

test('N-API Addon Tests', async (t) => {
  await t.test('Number addition', () => {
    assert.strictEqual(addon.add(10, 20), 30);
  });

  await t.test('String concat', () => {
    assert.strictEqual(addon.concat("Hello ", "MoonBit"), "Hello MoonBit");
  });

  await t.test('Double operations', () => {
    assert.strictEqual(addon.check_double(2.5), 5.0);
  });

  await t.test('Boolean operations', () => {
    assert.strictEqual(addon.check_bool(true), false);
    assert.strictEqual(addon.check_bool(false), true);
  });

  await t.test('Buffer operations (Bytes roundtrip)', () => {
    const buf = Buffer.from("Hello");
    const res = addon.roundtrip_bytes(buf);
    assert.strictEqual(Buffer.isBuffer(res), true);
    assert.strictEqual(res.toString(), "Hello");
  });

  await t.test('Zero-copy Buffer mutation (NapiBufferView)', () => {
    const buf = Buffer.from([10, 20, 30]);
    addon.mutate_buffer(buf);
    assert.strictEqual(buf[0], 11);
  });

  await t.test('Error handling (Missing parameters)', () => {
    assert.throws(() => {
      addon.add(10);
    }, /Missing argument/);
  });

  await t.test('Error handling (Invalid type)', () => {
    assert.throws(() => {
      addon.add("10", 20);
    }, /Invalid argument, expected Int/);
  });
});
