const assert = require('node:assert/strict')
const path = require('node:path')
const { pathToFileURL } = require('node:url')
const [directory, expected] = process.argv.slice(2)
assert.equal(require(path.join(directory, 'index.cjs')).answer(), Number(expected))
import(pathToFileURL(path.join(directory, 'index.mjs')).href).then(addon => {
  assert.equal(addon.answer(), Number(expected))
}).catch(error => { console.error(error); process.exitCode = 1 })
