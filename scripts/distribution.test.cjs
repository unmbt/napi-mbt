const assert = require('assert')
const path = require('path')
const { pathToFileURL } = require('url')
const directory = path.join(process.argv[2], 'node_modules', process.argv[3])
const name = process.argv[4]
assert.equal(require(directory)[name](1, 2), 3)
import(pathToFileURL(path.join(directory, 'index.mjs')).href).then(addon => {
  assert.equal(addon[name](4, 5), 9)
}).catch(error => { console.error(error); process.exitCode = 1 })
