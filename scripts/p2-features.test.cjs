const assert = require('node:assert');
const addon = require(process.argv[2]);

// 1. Labeled and optional labeled parameters with defaults
assert.strictEqual(addon.compute(10), 12);
assert.strictEqual(addon.compute(10, 5), 15);
assert.strictEqual(addon.compute(10, undefined), 12);
assert.strictEqual(addon.compute(10, 5, 'ok'), 15);

// 2. Enum @napi value("...")
assert.strictEqual(addon.echoRole('admin-role'), 'admin-role');
assert.strictEqual(addon.echoRole('guest-role'), 'guest-role');
assert.throws(() => addon.echoRole('Admin'), { code: 'ERR_NAPI_ENUM_TAG' });

// 3. Doc-directive class (@napi class / constructor / getter / setter / method / static)
const box = new addon.Box(4);
assert.strictEqual(box.value, 4);
box.value = 10;
assert.strictEqual(box.value, 10);
assert.strictEqual(box.bump(), 11);
assert.strictEqual(box.bump(9), 20);
box.dispose();

const defaultBox = addon.Box.fromDefault();
assert.strictEqual(defaultBox.value, 7);
defaultBox.dispose();

// 4. @napi module_exports hook
assert.strictEqual(addon.customFlag, 'initialized-by-hook');

console.log('P2 labeled/optional params, enum @napi value, doc-directive class, and module_exports passed');
