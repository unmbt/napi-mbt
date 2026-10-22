const assert = require('node:assert/strict');
const { resolve } = require('node:path');
const addon = require(resolve(process.argv[2]));
assert.equal(addon.answer(), Number(process.argv[3]));
