// Deliberately uses APIs available in Node 10.16, the N-API 4 CJS minimum.
var assert = require('assert')
var path = require('path')
var mode = process.argv[2]
var directory = path.resolve('.napi-mbt/minimum-' + mode)
var addon = require(path.join(directory, 'index.cjs'))
assert.strictEqual(addon.mbt_add(2, 3), 5)
if (mode !== 'cjs') {
  import(require('url').pathToFileURL(path.join(directory, 'index.mjs')).href).then(function (esm) {
    assert.strictEqual(esm.mbt_add(4, 5), 9)
  }).catch(function (error) { console.error(error); process.exitCode = 1 })
}
if (mode === 'async') {
  addon.delay(1, 'minimum').then(function (value) { assert.strictEqual(value, 'minimum') })
    .catch(function (error) { console.error(error); process.exitCode = 1 })
}
