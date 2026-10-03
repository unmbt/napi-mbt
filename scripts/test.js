const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const childProcess = require('child_process');
const addon = require('../index.cjs');

assert.strictEqual(addon.add(10, 20), 30);
assert.strictEqual(addon.concat('Hello ', 'MoonBit'), 'Hello MoonBit');
assert.strictEqual(addon.check_double(2.5), 5.0);
assert.strictEqual(addon.check_bool(true), false);
assert.strictEqual(addon.check_bool(false), true);
const buffer = Buffer.from('Hello');
assert.strictEqual(addon.roundtrip_bytes(buffer).toString(), 'Hello');
const mutable = Buffer.from([10, 20, 30]);
addon.mutate_buffer(mutable);
assert.strictEqual(mutable[0], 11);
assert.throws(() => addon.add(10), /Missing argument/);
assert.throws(() => addon.add('10', 20), /Invalid argument, expected Int/);

const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'napi-mbt-'));
fs.writeFileSync(path.join(fixture, 'napi-mbt.json'), JSON.stringify({ napiVersion: 1, features: ['bigint'] }));
fs.writeFileSync(path.join(fixture, 'lib.mbt'), '#export_name("fixture")\npub fn fixture() -> Unit { () }\n');
const gated = childProcess.spawnSync(process.execPath, [path.join(__dirname, '..', 'cli', 'bin', 'napi-mbt.js'), 'generate', fixture], { encoding: 'utf8' });
assert.notStrictEqual(gated.status, 0);
assert.ok(/lower than required feature level 6/.test(gated.stderr));
function removeTree(dir) {
  for (const entry of fs.readdirSync(dir)) {
    const item = path.join(dir, entry);
    if (fs.statSync(item).isDirectory()) removeTree(item);
    else fs.unlinkSync(item);
  }
  fs.rmdirSync(dir);
}
removeTree(fixture);

for (const target of ['win32-x64-msvc', 'darwin-x64', 'darwin-arm64', 'linux-x64-gnu', 'linux-arm64-gnu']) {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'npm', target, 'package.json'), 'utf8'));
  assert.ok(manifest.main === 'napi_mbt.node');
  assert.ok(manifest.os && manifest.cpu && manifest.files.indexOf('napi_mbt.node') >= 0);
}
console.log('napi-mbt tests passed');
