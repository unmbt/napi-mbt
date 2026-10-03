// Integration contracts: run on Node 8.6+ without node:test.
var assert = require('assert');
var fs = require('fs');
var path = require('path');
var os = require('os');
var cp = require('child_process');
var root = path.resolve(__dirname, '..');
var cli = path.join(root, 'cli/bin/napi-mbt.js');
var fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'napi-mbt-cli-'));
function run(args) {
  return cp.spawnSync(process.execPath, [cli].concat(args), { encoding: 'utf8' });
}
function ok(args) {
  var result = run(args);
  assert.strictEqual(result.status, 0, result.stdout + result.stderr);
}
function remove(dir) {
  fs.readdirSync(dir).forEach(function (name) {
    var item = path.join(dir, name);
    if (fs.lstatSync(item).isDirectory()) remove(item);
    else fs.unlinkSync(item);
  });
  fs.rmdirSync(dir);
}
try {
  ok(['init', fixture, '--name', 'fixture-addon']);
  ['moon.mod', 'bump.config.json', 'napi_exports.mbt', 'napi_glue.c', 'index.d.ts', 'index.cjs', 'index.mjs', 'test/smoke.mjs'].forEach(function (name) {
    assert.ok(fs.existsSync(path.join(fixture, name)), name);
  });
  assert.ok(/name\s*=\s*"fixture-addon"/.test(fs.readFileSync(path.join(fixture, 'moon.mod'), 'utf8')));
  ok(['generate', fixture, '--check']);
  fs.appendFileSync(path.join(fixture, 'index.d.ts'), '// dirty');
  assert.notStrictEqual(run(['generate', fixture, '--check']).status, 0);
  assert.notStrictEqual(run(['init', fixture]).status, 0);
  assert.ok(/dirty/.test(fs.readFileSync(path.join(fixture, 'index.d.ts'), 'utf8')));
  ok(['generate', fixture]);
  ok(['build', fixture, '--dry-run']);
  var invalid = run(['build', fixture, '--target', 'not-a-target', '--dry-run']);
  assert.notStrictEqual(invalid.status, 0);
  ok(['prepublish', fixture]);
  var pkg = JSON.parse(fs.readFileSync(path.join(fixture, 'package.json'), 'utf8'));
  assert.strictEqual(Object.keys(pkg.optionalDependencies).length, 5);
  var child = JSON.parse(fs.readFileSync(path.join(fixture, 'npm/win32-x64-msvc/package.json'), 'utf8'));
  assert.strictEqual(child.exports['.'].import, './index.mjs');
  assert.ok(child.files.indexOf('index.mjs') >= 0);
  // Comments must neither create exports nor infer an advanced N-API version.
  fs.appendFileSync(path.join(fixture, 'lib.mbt'), '\n/// @napi napi_bigint_from_int64 anything\n');
  ok(['generate', fixture]);
  console.log('CLI integration contracts passed');
} finally {
  remove(fixture);
}
