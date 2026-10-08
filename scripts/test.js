// Node is used only to load and exercise the already-built addons.
const assert = require('assert');
const path = require('path');
const addon = require('../index.cjs');

assert.strictEqual(addon.add(10, 20), 30);
assert.strictEqual(addon.concat('Hello ', 'MoonBit'), 'Hello MoonBit');
assert.strictEqual(addon.check_double(2.5), 5.0);
assert.strictEqual(addon.check_bool(true), false);
assert.strictEqual(addon.check_bool(false), true);
assert.strictEqual(addon.roundtrip_bytes(Buffer.from('Hello')).toString(), 'Hello');
const mutable = Buffer.from([10, 20, 30]);
addon.mutate_buffer(mutable);
assert.strictEqual(mutable[0], 11);
assert.throws(() => addon.add(10), /Missing argument/);
assert.throws(() => addon.add('10', 20), /Invalid argument, expected Int/);
assert.throws(() => addon.mutate_buffer('not a buffer'), /expected Buffer/);
assert.throws(() => addon.roundtrip_bytes(null), /expected Buffer/);

(async () => {
  const esm = await import('../index.mjs');
  assert.strictEqual(esm.add(2, 3), 5);
  for (const label of ['release', 'installed']) {
    const root = path.join(__dirname, '../.napi-mbt/native-smoke', label);
    const fixture = require(path.join(root, 'index.cjs'));
    assert.strictEqual(fixture.mbt_add(2, 3), 5);
    assert.throws(() => fixture.failure(), /native fixture failure/);
    const buffer = Buffer.from([41]);
    fixture.touch(buffer);
    assert.strictEqual(buffer[0], 42);
    fixture.save_buffer(buffer);
    assert.strictEqual(fixture.saved_alive(), false);
    assert.throws(() => fixture.save_failure(buffer), /saved failure/);
    assert.strictEqual(fixture.saved_alive(), false);
    const fixtureEsm = await import(require('url').pathToFileURL(path.join(root, 'index.mjs')).href);
    assert.strictEqual(fixtureEsm.mbt_add(3, 4), 7);
    assert.strictEqual(fixtureEsm.default.mbt_add, fixtureEsm.mbt_add);
  }
  console.log('Native addon CJS/ESM load tests passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
