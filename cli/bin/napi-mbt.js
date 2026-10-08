#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const generate = require('../src/generate');
const build = require('../src/build');
const VERSION = require('../package.json').version;
const SUPPORTED_TARGETS = ['win32-x64-msvc', 'darwin-x64', 'darwin-arm64', 'linux-x64-gnu', 'linux-arm64-gnu'];

function mkdirp(dir) {
  if (fs.existsSync(dir)) return;
  const parent = path.dirname(dir);
  if (parent !== dir) mkdirp(parent);
  try { fs.mkdirSync(dir); } catch (e) { if (!fs.existsSync(dir)) throw e; }
}

function writeFile(filename, content, force) {
  if (fs.existsSync(filename) && !force) throw new Error(`Refusing to overwrite ${filename}; use --force`);
  mkdirp(path.dirname(filename));
  fs.writeFileSync(filename, content);
}

function positionalDirectory(args) {
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--generator' || args[i] === '--target' || args[i] === '--name') { i++; continue; }
    if (args[i].indexOf('--') !== 0) return args[i];
  }
  return null;
}

async function init(dir, args) {
  const force = args.indexOf('--force') >= 0;
  const nameIndex = args.indexOf('--name');
  const name = nameIndex >= 0 && args[nameIndex + 1] ? args[nameIndex + 1] : path.basename(path.resolve(dir));
  const pkg = {
    name,
    version: '0.1.0',
    main: 'index.cjs',
    module: 'index.mjs',
    types: 'index.d.ts',
    exports: { '.': { types: './index.d.ts', require: './index.cjs', import: './index.mjs', default: './index.cjs' } },
    scripts: { generate: 'napi-mbt-cli generate', build: 'napi-mbt-cli build --release', test: 'node test/smoke.cjs' },
    dependencies: { 'node-api-headers': '^1.9.0' }
  };
  writeFile(path.join(dir, 'package.json'), JSON.stringify(pkg, null, 2) + '\n', force);
  writeFile(path.join(dir, 'napi-mbt.json'), JSON.stringify({ napiVersion: 1, generator: 'auto', builder: 'auto', targets: ['win32-x64-msvc', 'darwin-x64', 'darwin-arm64', 'linux-x64-gnu', 'linux-arm64-gnu'], features: [], cjs: true, esm: true }, null, 2) + '\n', force);
  writeFile(path.join(dir, 'bump.config.json'), JSON.stringify({ execute: 'npm run build && npm test', all: true }, null, 2) + '\n', force);
  writeFile(path.join(dir, 'moon.mod'), `name = "${name.replace(/^@/, '')}"
version = "0.1.0"
supported_targets = "native"
`, force);
  writeFile(path.join(dir, 'moon.pkg'), `pkgtype(kind: "foreign_library")
import {
  "moonbitlang/core/encoding/utf8",
}
options(
  "native-stub": ["stub.c", "napi_glue.c"],
  link: { "native": { "stub-cc-flags": "-I./node_modules/node-api-headers/include" } },
)
`, force);
  writeFile(path.join(dir, 'lib.mbt'), `#export_name("mbt_add")
pub fn add(a : Int, b : Int) -> Int {
  a + b
}
`, force);
  const templateDir = path.join(__dirname, '..', 'template');
  ['napi_types.mbt', 'napi_bindings.mbt', 'napi_features.mbt', 'napi_runtime.mbt', 'stub.c'].forEach(file => {
    const source = path.join(templateDir, file);
    if (fs.existsSync(source)) writeFile(path.join(dir, file), fs.readFileSync(source, 'utf8'), force);
  });
  writeFile(path.join(dir, 'test', 'smoke.cjs'), `const assert = require('assert');
const addon = require('../index.cjs');
assert.strictEqual(addon.mbt_add(2, 3), 5);
console.log('napi-mbt template smoke test passed');
`, force);
  writeFile(path.join(dir, 'test', 'smoke.mjs'), `import assert from 'assert';
import addon, { mbt_add } from '../index.mjs';
assert.strictEqual(mbt_add(2, 3), 5);
assert.strictEqual(addon.mbt_add, mbt_add);
`, force);
  writeFile(path.join(dir, '.github', 'workflows', 'build.yml'), `name: build
on: [push, pull_request]
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: ['8.6', '12', '18', '26']
    runs-on: \${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: \${{ matrix.node }} }
      - run: npm install
      - run: npm run build
      - run: npm test
`, force);
  // Keep the official template immediately buildable and inspectable.
  await generate(path.resolve(dir), { generator: 'node' });
  console.log(`[napi-mbt] initialized ${path.resolve(dir)}`);
}

function prepublish(cwd, targetOverride) {
  const pkgFile = path.join(cwd, 'package.json');
  if (!fs.existsSync(pkgFile)) throw new Error('No package.json found');
  const pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));
  const configFile = path.join(cwd, 'napi-mbt.json');
  const config = fs.existsSync(configFile) ? JSON.parse(fs.readFileSync(configFile, 'utf8')) : {};
  const targets = targetOverride ? [targetOverride] : (config.targets && config.targets.length ? config.targets : [`${process.platform}-${process.arch}`]);
  targets.forEach(target => {
    if (SUPPORTED_TARGETS.indexOf(target) < 0) throw new Error(`Unsupported target: ${target}`);
  });
  pkg.optionalDependencies = pkg.optionalDependencies || {};
  if (!targetOverride) Object.keys(pkg.optionalDependencies).forEach(key => { if (key.indexOf(`${pkg.name}-`) === 0) delete pkg.optionalDependencies[key]; });
  targets.forEach(target => {
    const child = `${pkg.name}-${target}`;
    const dir = path.join(cwd, 'npm', target);
    mkdirp(dir);
    const parts = target.split('-');
    const platform = parts[0];
    const cpu = parts[1];
    const libc = parts[2] === 'gnu' ? 'glibc' : parts[2];
    const childPkg = { name: child, version: pkg.version, os: [platform], cpu: [cpu], main: 'napi_mbt.node', files: ['napi_mbt.node', 'index.mjs'], exports: { '.': { require: './napi_mbt.node', import: './index.mjs', default: './napi_mbt.node' } }, engines: { node: '>=8.6' }, napiVersion: config.napiVersion || 1 };
    if (libc && platform === 'linux') childPkg.libc = [libc];
    const artifact = path.join(cwd, 'artifacts', target, 'napi_mbt.node');
    if (fs.existsSync(artifact)) fs.copyFileSync(artifact, path.join(dir, 'napi_mbt.node'));
    else console.warn(`[napi-mbt] no artifact for ${target}; metadata was generated for CI cross-builds`);
    fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify(childPkg, null, 2) + '\n');
    fs.writeFileSync(path.join(dir, 'index.mjs'), "import { createRequire } from 'module';\nconst require = createRequire(import.meta.url);\nexport default require('./napi_mbt.node');\n");
    pkg.optionalDependencies[child] = pkg.version;
  });
  fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2) + '\n');
  console.log(`[napi-mbt] prepared ${targets.length} platform package(s)`);
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const cwd = process.cwd();
  if (command === '--version' || command === '-V') console.log(VERSION);
  else if (command === 'init') await init(args[1] || '.', args.slice(2));
  else if (command === 'generate') {
    const generatedDir = positionalDirectory(args.slice(1)) || cwd;
    const generatorIndex = args.indexOf('--generator');
    await generate(generatedDir, { check: args.indexOf('--check') >= 0, generator: generatorIndex >= 0 ? args[generatorIndex + 1] : undefined });
  }
  else if (command === 'build') {
    const generatorIndex = args.indexOf('--generator');
    const targetIndex = args.indexOf('--target');
    const buildDir = positionalDirectory(args.slice(1)) || cwd;
    await build(buildDir, { release: args.indexOf('--release') >= 0, dryRun: args.indexOf('--dry-run') >= 0, generator: generatorIndex >= 0 ? args[generatorIndex + 1] : undefined, target: targetIndex >= 0 ? args[targetIndex + 1] : undefined });
  }
  else if (command === 'prepublish') {
    const targetIndex = args.indexOf('--target');
    const publishDir = positionalDirectory(args.slice(1)) || cwd;
    prepublish(publishDir, targetIndex >= 0 ? args[targetIndex + 1] : undefined);
  }
  else if (command === 'targets') console.log(SUPPORTED_TARGETS.join('\n'));
  else console.log('Usage: napi-mbt <init|generate|build|prepublish|targets>');
}

main().catch(err => { console.error(`[napi-mbt] ${err.message}`); process.exit(1); });
