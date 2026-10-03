const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const generate = require('./generate');

function commandExists(command) {
  try { execFileSync(process.platform === 'win32' ? 'where.exe' : 'which', [command], { stdio: 'ignore' }); return true; } catch (_) { return false; }
}

function mkdirp(dir) {
  if (fs.existsSync(dir)) return;
  const parent = path.dirname(dir);
  if (parent !== dir) mkdirp(parent);
  try { fs.mkdirSync(dir); } catch (error) { if (!fs.existsSync(dir)) throw error; }
}

function findLibExe() {
  if (process.platform !== 'win32') return null;
  try {
    const pf = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
    const vswhere = path.join(pf, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe');
    const root = execFileSync(vswhere, ['-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'], { encoding: 'utf8' }).trim();
    const msvc = path.join(root, 'VC', 'Tools', 'MSVC');
    const versions = fs.readdirSync(msvc).sort().reverse();
    for (const version of versions) {
      const candidate = path.join(msvc, version, 'bin', 'Hostx64', 'x64', 'lib.exe');
      if (fs.existsSync(candidate)) return candidate;
    }
  } catch (_) {}
  return null;
}

function napiImportLibrary(pkgDir) {
  if (process.platform !== 'win32') return null;
  const cache = path.join(pkgDir, 'node_modules', '.cache', 'napi-mbt');
  mkdirp(cache);
  const output = path.join(cache, 'napi.lib');
  if (fs.existsSync(output)) return output;
  const lib = findLibExe();
  if (!lib) throw new Error('MSVC lib.exe is required to create the Node-API import library');
  const headers = path.dirname(require.resolve('node-api-headers/package.json'));
  const def = path.join(headers, 'def', 'node_api.def');
  execFileSync(lib, [`/DEF:${def}`, `/OUT:${output}`, '/MACHINE:X64'], { stdio: 'inherit' });
  return output;
}

function quoteCMake(value) { return value.replace(/\\/g, '/').replace(/"/g, '\\"'); }

function targetName(requested) {
  if (requested) return requested;
  if (process.platform === 'linux') return `linux-${process.arch}-gnu`;
  if (process.platform === 'darwin') return `darwin-${process.arch}`;
  return `${process.platform}-${process.arch}-msvc`;
}

function locateMoonArtifacts(pkgDir, mode) {
  const dir = path.join(pkgDir, '_build', 'native', mode, 'build');
  if (!fs.existsSync(dir)) throw new Error(`MoonBit build directory not found: ${dir}`);
  const pick = names => names.map(name => path.join(dir, name)).find(fs.existsSync);
  const object = pick(process.platform === 'win32' ? ['napi-mbt.obj'] : ['napi-mbt.o']);
  const stub = pick(process.platform === 'win32' ? ['stub.obj'] : ['stub.o']);
  const runtime = pick(process.platform === 'win32' ? ['libruntime.lib'] : ['libruntime.a', 'runtime.o']);
  if (!object || !stub || !runtime) throw new Error('MoonBit native artifacts are incomplete');
  return { dir, object, stub, runtime };
}

function cmakeFile(pkgDir, artifacts, config, mode, napiLib) {
  const include = path.join(pkgDir, 'node_modules', 'node-api-headers', 'include');
  const lines = [
    'cmake_minimum_required(VERSION 3.20)',
    'project(napi_mbt C)',
    'add_library(napi_mbt MODULE "' + quoteCMake(path.join(pkgDir, 'napi_glue.c')) + '")',
    'target_include_directories(napi_mbt PRIVATE "' + quoteCMake(include) + '")',
    'target_compile_definitions(napi_mbt PRIVATE NAPI_VERSION=' + String(config.napiVersion) + ')',
    'target_link_libraries(napi_mbt PRIVATE "' + quoteCMake(artifacts.object) + '" "' + quoteCMake(artifacts.stub) + '" "' + quoteCMake(artifacts.runtime) + '"' + (napiLib ? ' "' + quoteCMake(napiLib) + '"' : '') + ')',
    'set_target_properties(napi_mbt PROPERTIES PREFIX "" SUFFIX ".node")'
  ];
  if (process.platform !== 'win32') {
    lines.push('set_target_properties(napi_mbt PROPERTIES POSITION_INDEPENDENT_CODE ON)');
    if (process.platform === 'darwin') lines.push('target_link_options(napi_mbt PRIVATE "-undefined" "dynamic_lookup")');
  }
  return lines.join('\n') + '\n';
}

function ensureMoonPackage(pkgDir, manifest, config, napiLib) {
  const filename = path.join(pkgDir, 'moon.pkg');
  if (!fs.existsSync(filename)) throw new Error('moon.pkg is required for a native N-API package');
  let text = fs.readFileSync(filename, 'utf8');
  if (text.indexOf('pkgtype(kind: "foreign_library")') < 0) text = 'pkgtype(kind: "foreign_library")\n' + text;
  if (text.indexOf('napi_glue.c') < 0) text = text.replace(/"native-stub"\s*:\s*\[([^\]]*)\]/, '"native-stub": ["stub.c", "napi_glue.c"]');
  const napiFlags = `-I./node_modules/node-api-headers/include -DNAPI_VERSION=${Number(config.napiVersion || 1)}`;
  if (text.indexOf('"stub-cc-flags"') >= 0) text = text.replace(/"stub-cc-flags"\s*:\s*"[^"]*"/, `"stub-cc-flags": "${napiFlags}"`);
  else text = text.replace(/(link\s*:\s*\{\s*"native"\s*:\s*\{)/, `$1\n      "stub-cc-flags": "${napiFlags}",`);
  // MoonBit's foreign-library step still needs a shared-library link action.
  // CMake performs the final .node link afterward.
  const moonLinkFlags = process.platform === 'win32'
    ? `/LD "./node_modules/.cache/napi-mbt/napi.lib"`
    : process.platform === 'darwin' ? '-shared -undefined dynamic_lookup' : '-shared';
  const encodedMoonLinkFlags = moonLinkFlags.replace(/"/g, '\\"');
  if (text.indexOf('"cc-link-flags"') >= 0) {
    text = text.replace(/"cc-link-flags"\s*:\s*"(?:\\.|[^"\\])*"/, `"cc-link-flags": "${encodedMoonLinkFlags}"`);
  } else {
    text = text.replace(/("stub-cc-flags"\s*:\s*"(?:\\.|[^"\\])*"),?/, `$1,\n      "cc-link-flags": "${encodedMoonLinkFlags}",`);
  }
  const exports = ['moonbit_init'].concat(manifest.exports.map(item => `napi_mbt_adapter_${item.exportName}`));
  const replacement = '"exports": [\n' + exports.map(name => `        "${name}",`).join('\n') + '\n      ]';
  if (text.indexOf('"exports"') >= 0) text = text.replace(/"exports"\s*:\s*\[[\s\S]*?\]/, replacement);
  else text = text.replace(/(link\s*:\s*\{\s*"native"\s*:\s*\{)/, `$1\n      ${replacement},`);
  fs.writeFileSync(filename, text);
}

async function main(pkgDir = '.', options = {}) {
  pkgDir = path.resolve(pkgDir);
  const configPath = path.join(pkgDir, 'napi-mbt.json');
  const config = fs.existsSync(configPath) ? JSON.parse(fs.readFileSync(configPath, 'utf8')) : { napiVersion: 1, builder: 'auto' };
  const mode = options.release || process.argv.includes('--release') ? 'release' : 'debug';
  const dryRun = options.dryRun || process.argv.includes('--dry-run');
  const manifest = await generate(pkgDir, { generator: options.generator });
  const napiLib = dryRun ? null : napiImportLibrary(pkgDir);
  ensureMoonPackage(pkgDir, manifest, config, napiLib);
  const outputTarget = options.target || targetName();
  const configuredTargets = config.targets || [];
  if (configuredTargets.length && configuredTargets.indexOf(outputTarget) < 0) throw new Error(`Target ${outputTarget} is not listed in napi-mbt.json`);
  if (outputTarget !== targetName()) throw new Error(`Cross-compiling ${outputTarget} requires a matching MoonBit target and toolchain; current host is ${targetName()}`);
  if (dryRun) { console.log(`[napi-mbt] dry-run: moon build --target native --${mode}`); return; }
  execFileSync('moon', ['build', '--target', 'native', mode === 'release' ? '--release' : '--debug'], { cwd: pkgDir, stdio: 'inherit' });
  const artifacts = locateMoonArtifacts(pkgDir, mode);
  const buildRoot = path.join(pkgDir, '.napi-mbt', 'cmake', mode);
  mkdirp(buildRoot);
  fs.writeFileSync(path.join(pkgDir, '.napi-mbt', 'CMakeLists.txt'), cmakeFile(pkgDir, artifacts, config, mode, napiLib));
  const generatorArgs = commandExists('ninja') ? ['-G', 'Ninja'] : [];
  const builder = config.builder || 'auto';
  if (builder !== 'auto' && builder !== 'cmake' && builder !== 'clang' && builder !== 'gcc' && builder !== 'msvc') throw new Error(`Unknown builder: ${builder}`);
  if (builder === 'clang') generatorArgs.push('-DCMAKE_C_COMPILER=clang');
  if (builder === 'gcc') generatorArgs.push('-DCMAKE_C_COMPILER=gcc');
  if (builder === 'msvc' && commandExists('clang-cl')) generatorArgs.push('-DCMAKE_C_COMPILER=clang-cl');
  execFileSync('cmake', ['-S', path.join(pkgDir, '.napi-mbt'), '-B', buildRoot].concat(generatorArgs), { cwd: pkgDir, stdio: 'inherit' });
  execFileSync('cmake', ['--build', buildRoot, '--config', mode], { cwd: pkgDir, stdio: 'inherit' });
  const built = path.join(buildRoot, 'napi_mbt.node');
  if (!fs.existsSync(built)) throw new Error(`CMake did not produce ${built}`);
  const outputDir = path.join(pkgDir, 'artifacts', outputTarget);
  mkdirp(outputDir);
  fs.copyFileSync(built, path.join(outputDir, 'napi_mbt.node'));
  console.log(`[napi-mbt] built ${path.join(outputDir, 'napi_mbt.node')}`);
}

module.exports = main;
