// Exercises generated loaders, including OS/libc branches through a VM context.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { pathToFileURL } = require('url');
const [dir, mode, target] = process.argv.slice(2);
const cjs = mode !== 'esm';
const esm = mode !== 'cjs';
const local = path.join(dir, 'artifacts', target, 'napi_mbt.node');
const metadata = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
assert.strictEqual(fs.existsSync(path.join(dir, 'index.cjs')), cjs);
assert.strictEqual(fs.existsSync(path.join(dir, 'index.mjs')), esm);
assert.strictEqual(Boolean(metadata.exports['.'].require), cjs);
assert.strictEqual(Boolean(metadata.exports['.'].import), esm);

function loadVirtual(source, options = {}) {
  const addon = { marker: true };
  const cause = new Error('original native loading failure');
  const loads = [];
  const context = {
    __dirname: dir, module: { exports: {} },
    process: { platform: options.platform || 'win32', arch: options.arch || 'x64', versions: { napi: options.napi || '4' },
      report: { getReport: () => ({ header: options.musl ? {} : { glibcVersionRuntime: '2.36' } }) } },
    require(name) {
      if (name === 'path') return path;
      if (name === 'fs') return { existsSync: () => Boolean(options.local) };
      loads.push(name);
      if (name.endsWith('/package.json')) {
        if (options.missing) throw cause;
        return { name: 'loader-fixture-win32-x64-msvc', version: options.wrongVersion ? '9.0.0' : '0.1.0', napiVersion: 4, napiTarget: 'win32-x64-msvc' };
      }
      if (options.broken) throw cause;
      return addon;
    },
  };
  try { vm.runInNewContext(source, context); return { result: context.module.exports, addon, loads }; }
  catch (error) { return { error, cause, loads }; }
}

(async () => {
  if (cjs) assert.strictEqual(require(path.join(dir, 'index.cjs')).mbt_add(2, 3), 5);
  if (esm) {
    const addon = await import(pathToFileURL(path.join(dir, 'index.mjs')).href);
    assert.strictEqual(addon.mbt_add(2, 3), 5);
    assert.strictEqual(addon.default.mbt_add, addon.mbt_add);
  }
  // Existing broken local builds must never silently fall through to a package.
  if (cjs) {
    const source = fs.readFileSync(path.join(dir, 'index.cjs'), 'utf8');
    const localSuccess = loadVirtual(source, { local: true });
    assert.strictEqual(localSuccess.result, localSuccess.addon);
    assert.strictEqual(localSuccess.loads.length, 1);
    for (const options of [{ local: true, broken: true }, { broken: true }, { missing: true }]) {
      const { error, cause } = loadVirtual(source, options);
      assert.strictEqual(error.cause, cause);
      assert.strictEqual(error.target, 'win32-x64-msvc');
      assert.strictEqual(error.requiredNapiVersion, 4);
      assert(error.attemptedPaths.length > 0);
    }
    assert.strictEqual(loadVirtual(source, { wrongVersion: true }).error.code, 'ERR_NAPI_PACKAGE_VERSION');
    assert.strictEqual(loadVirtual(source, { napi: '3' }).error.code, 'ERR_NAPI_VERSION');
    assert.strictEqual(loadVirtual(source, { platform: 'freebsd' }).error.code, 'ERR_NAPI_PLATFORM');
    assert.strictEqual(loadVirtual(source, { arch: 'ia32' }).error.code, 'ERR_NAPI_PLATFORM');
    assert.strictEqual(loadVirtual(source, { platform: 'linux', musl: true }).error.code, 'ERR_NAPI_PLATFORM');
    const linux = loadVirtual(source, { platform: 'linux', local: true });
    assert.strictEqual(linux.result, linux.addon);
  }
  // Exercise package metadata resolution and the real native entry with no local artifact.
  const child = path.join(dir, 'node_modules', 'loader-fixture-' + target);
  fs.mkdirSync(child, { recursive: true });
  for (const file of ['package.json', 'napi_mbt.node']) fs.copyFileSync(path.join(dir, 'npm', target, file), path.join(child, file));
  fs.renameSync(local, local + '.saved');
  try {
    if (cjs) {
      delete require.cache[require.resolve(path.join(dir, 'index.cjs'))];
      assert.strictEqual(require(path.join(dir, 'index.cjs')).mbt_add(3, 4), 7);
    }
    if (esm) assert.strictEqual((await import(pathToFileURL(path.join(dir, 'index.mjs')).href + '?package')).mbt_add(3, 4), 7);
    fs.writeFileSync(local, 'broken native binary');
    // Native library handles survive require.cache removal; use a fresh process.
    const code = `const assert = require('assert');
      const verify = e => e.code === 'ERR_NAPI_LOAD' && e.cause.code === 'ERR_DLOPEN_FAILED';
      if (process.argv[2] === 'cjs') assert.throws(() => require(process.argv[1]), verify);
      else assert.rejects(import(require('url').pathToFileURL(process.argv[1]).href), verify).catch(e => { console.error(e); process.exitCode = 1; });`;
    for (const entry of [...(cjs ? ['cjs'] : []), ...(esm ? ['mjs'] : [])]) {
      const child = require('child_process').spawnSync(process.execPath, ['-e', code, path.join(dir, 'index.' + entry), entry], { timeout: 10000, encoding: 'utf8' });
      assert.strictEqual(child.status, 0, String(child.error || child.stderr));
    }
  } finally {
    if (fs.existsSync(local)) fs.unlinkSync(local);
    fs.renameSync(local + '.saved', local);
  }
  console.log('Loader assertions passed: ' + mode);
})().catch(error => { console.error(error); process.exitCode = 1; });
