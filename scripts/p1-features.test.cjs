const assert = require('node:assert');
const addon = require(process.argv[2]);

// 1. Primitive NapiEither<number, string>
assert.strictEqual(addon.eitherPrimitive(42), 42);
assert.strictEqual(addon.eitherPrimitive('hello'), 'hello');
assert.throws(() => addon.eitherPrimitive(true), { name: 'TypeError' });

// 2. Struct union NapiEither<LeftItem, RightItem>
assert.deepStrictEqual(addon.eitherStruct({ count: 7 }), { count: 7 });
assert.deepStrictEqual(addon.eitherStruct({ label: 'ok' }), { label: 'ok' });

// Verify JS getter / pending exception is preserved rather than masked by fallback B
const getterErr = new RangeError('boom from getter');
const poison = {
  get count() {
    throw getterErr;
  },
  label: 'fallback',
};
assert.throws(
  () => addon.eitherStruct(poison),
  err => err === getterErr,
);

// 3. Class & object interop under runtime: "package"
const boxed = new addon.Boxed(10);
assert.strictEqual(boxed.get(), 10);
assert.strictEqual(addon.eitherBox(boxed), 10);
assert.strictEqual(addon.eitherBox('str'), 3);
boxed.dispose();

console.log('NapiEither and package runtime E2E checks passed');
