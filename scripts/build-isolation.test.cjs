const assert = require('node:assert/strict');
const addon = require('../.napi-mbt/isolation-smoke/napi_mbt.node');
assert.equal(addon.answer(), 42);
console.log('Isolated addon linked the additional stub and native dependency');
