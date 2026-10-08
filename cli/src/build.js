const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const generate = require('./generate');
const visualStudioGenerator = require('./cmake-generator');

function commandExists(command) {
  try { execFileSync(process.platform === 'win32' ? 'where.exe' : 'which', [command], { stdio: 'ignore' }); return true; } catch (_) { return false; }
}

function mkdirp(dir) {
  if (fs.existsSync(dir)) return;
  const parent = path.dirname(dir);
  if (parent !== dir) mkdirp(parent);
  try { fs.mkdirSync(dir); } catch (error) { if (!fs.existsSync(dir)) throw error; }
}

function findVisualStudio() {
  if (process.platform !== 'win32') return null;
  try {
    const pf = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
    const vswhere = path.join(pf, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe');
    const instances = JSON.parse(execFileSync(vswhere, ['-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-format', 'json', '-utf8'], { encoding: 'utf8' }));
    return instances[0] || null;
  } catch (_) {}
  return null;
}

function findLibExe() {
  const instance = findVisualStudio();
  if (!instance) return null;
  try {
    const root = instance.installationPath;
    const msvc = path.join(root, 'VC', 'Tools', 'MSVC');
    const versions = fs.readdirSync(msvc).sort().reverse();
    for (const version of versions) {
      const candidate = path.join(msvc, version, 'bin', 'Hostx64', 'x64', 'lib.exe');
      if (fs.existsSync(candidate)) return candidate;
    }
  } catch (_) {}
  return null;
}

function cmakeGeneratorArgs(builder) {
  if (!['auto', 'cmake', 'clang', 'gcc', 'msvc'].includes(builder)) throw new Error(`Unknown builder: ${builder}`);
  if (process.platform === 'win32') {
    if (builder === 'gcc') throw new Error('Windows builds require an MSVC-compatible toolchain; MinGW GCC cannot link the MoonBit MSVC artifacts');
    const instance = findVisualStudio();
    if (!instance) throw new Error('Visual Studio with the C++ build tools is required on Windows');
    const capabilities = JSON.parse(execFileSync('cmake', ['-E', 'capabilities'], { encoding: 'utf8' }));
    const generator = visualStudioGenerator(instance, capabilities);
    // Ninja autodetection can select MinGW even though Moon produced MSVC
    // objects. A VS generator also works outside a Developer Command Prompt.
    return ['-G', generator, '-A', 'x64',
      `-DCMAKE_GENERATOR_INSTANCE=${instance.installationPath}`,
      '-T', builder === 'clang' ? 'ClangCL,host=x64' : 'host=x64'];
  }
  const args = commandExists('ninja') ? ['-G', 'Ninja'] : [];
  if (builder === 'clang') args.push('-DCMAKE_C_COMPILER=clang');
  if (builder === 'gcc') args.push('-DCMAKE_C_COMPILER=gcc');
  if (builder === 'msvc' && commandExists('clang-cl')) args.push('-DCMAKE_C_COMPILER=clang-cl');
  return args;
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
  if (process.platform !== 'win32') {
    const source = pick(['napi-mbt.c']);
    const moonc = execFileSync('which', ['moonc'], { encoding: 'utf8' }).trim();
    const moonHome = process.env.MOON_HOME || path.dirname(path.dirname(fs.realpathSync(moonc)));
    const runtimeDir = path.join(moonHome, 'lib', 'runtime');
    const runtimeSources = fs.existsSync(runtimeDir)
      ? fs.readdirSync(runtimeDir).filter(name => name.endsWith('.c')).sort().map(name => path.join(runtimeDir, name))
      : [path.join(moonHome, 'lib', 'runtime.c')].filter(fs.existsSync);
    if (!source || !runtimeSources.length) throw new Error('MoonBit generated C or runtime sources are missing');
    return { dir, source, runtimeSources, moonInclude: path.join(moonHome, 'include') };
  }
  const object = pick(['napi-mbt.obj']);
  const stub = pick(['stub.obj']);
  const runtime = pick(['libruntime.lib']);
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
    'set_target_properties(napi_mbt PROPERTIES PREFIX "" SUFFIX ".node")'
  ];
  if (process.platform !== 'win32') {
    // Package cc-flags do not reach Moon's runtime compilation. Recompile its
    // sources here so every object in the Node addon is position independent.
    const sources = [artifacts.source, path.join(pkgDir, 'stub.c')].concat(artifacts.runtimeSources);
    lines.push('target_sources(napi_mbt PRIVATE ' + sources.map(file => '"' + quoteCMake(file) + '"').join(' ') + ')');
    lines.push('target_include_directories(napi_mbt PRIVATE "' + quoteCMake(artifacts.moonInclude) + '")');
    lines.push('target_compile_definitions(napi_mbt PRIVATE MOONBIT_ALLOCATOR=MOONBIT_ALLOCATOR_SYSTEM)');
    lines.push('target_compile_options(napi_mbt PRIVATE -fwrapv -fno-strict-aliasing)');
    lines.push('target_link_libraries(napi_mbt PRIVATE m)');
    lines.push('set_target_properties(napi_mbt PROPERTIES POSITION_INDEPENDENT_CODE ON)');
    if (process.platform === 'darwin') lines.push('target_link_options(napi_mbt PRIVATE "-undefined" "dynamic_lookup")');
  } else {
    lines.push('if(NOT MSVC)');
    lines.push('  message(FATAL_ERROR "Windows builds require an MSVC-compatible compiler")');
    lines.push('endif()');
    // Moon uses /MT for its objects and runtime in both debug and release.
    lines.push('set_property(TARGET napi_mbt PROPERTY MSVC_RUNTIME_LIBRARY MultiThreaded)');
    lines.push('target_link_libraries(napi_mbt PRIVATE "' + quoteCMake(artifacts.object) + '" "' + quoteCMake(artifacts.stub) + '" "' + quoteCMake(artifacts.runtime) + '" "' + quoteCMake(napiLib) + '")');
  }
  return lines.join('\n') + '\n';
}

function ensureMoonPackage(pkgDir, manifest, config, napiLib) {
  const filename = path.join(pkgDir, 'moon.pkg');
  if (!fs.existsSync(filename)) throw new Error('moon.pkg is required for a native N-API package');
  let text = fs.readFileSync(filename, 'utf8');
  if (text.indexOf('pkgtype(kind: "foreign_library")') < 0) text = 'pkgtype(kind: "foreign_library")\n' + text;
  if (text.indexOf('napi_glue.c') < 0) text = text.replace(/"native-stub"\s*:\s*\[([^\]]*)\]/, '"native-stub": ["stub.c", "napi_glue.c"]');
  const dynamicFlags = text.includes('${build.NAPI_C_FLAGS}');
  const cFlags = dynamicFlags ? '${build.NAPI_C_FLAGS}' : process.platform === 'win32' ? '/utf-8' : '-fPIC';
  const napiFlags = `${cFlags} -I./node_modules/node-api-headers/include -DNAPI_VERSION=${Number(config.napiVersion || 1)}`;
  if (text.indexOf('"stub-cc-flags"') >= 0) text = text.replace(/"stub-cc-flags"\s*:\s*"[^"]*"/, `"stub-cc-flags": "${napiFlags}"`);
  else text = text.replace(/(link\s*:\s*\{\s*"native"\s*:\s*\{)/, `$1\n      "stub-cc-flags": "${napiFlags}",`);
  // On Unix, stop at compilation: Moon's runtime archive is not PIC. CMake
  // rebuilds the generated C and runtime sources for the final .node link.
  const moonLinkFlags = dynamicFlags ? '${build.NAPI_LINK_FLAGS}' : process.platform === 'win32'
    ? `/LD "./node_modules/.cache/napi-mbt/napi.lib"`
    : '-c';
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
  const builder = config.builder || 'auto';
  const generatorArgs = dryRun ? [] : cmakeGeneratorArgs(builder);
  const manifest = await generate(pkgDir, { generator: options.generator });
  const napiLib = dryRun ? null : napiImportLibrary(pkgDir);
  ensureMoonPackage(pkgDir, manifest, config, napiLib);
  const outputTarget = options.target || targetName();
  const configuredTargets = config.targets || [];
  if (configuredTargets.length && configuredTargets.indexOf(outputTarget) < 0) throw new Error(`Target ${outputTarget} is not listed in napi-mbt.json`);
  if (outputTarget !== targetName()) throw new Error(`Cross-compiling ${outputTarget} requires a matching MoonBit target and toolchain; current host is ${targetName()}`);
  if (dryRun) { console.log(`[napi-mbt] dry-run: moon build --target native --${mode}`); return; }
  // Use generated C on every host and the same allocator in both build stages.
  const moonEnv = Object.assign({}, process.env, { MOONBIT_NEW_NATIVE: '0', MOONBIT_ALLOCATOR: 'system' });
  execFileSync('moon', ['build', '--target', 'native', mode === 'release' ? '--release' : '--debug', '.'], { cwd: pkgDir, stdio: 'inherit', env: moonEnv });
  const artifacts = locateMoonArtifacts(pkgDir, mode);
  // Keep VS configurations separate from old Ninja/MinGW CMake caches.
  const buildRoot = path.join(pkgDir, '.napi-mbt', 'cmake', process.platform === 'win32' ? `${mode}-${builder === 'clang' ? 'clangcl' : 'msvc'}` : mode);
  mkdirp(buildRoot);
  fs.writeFileSync(path.join(pkgDir, '.napi-mbt', 'CMakeLists.txt'), cmakeFile(pkgDir, artifacts, config, mode, napiLib));
  const configuration = mode === 'release' ? 'Release' : 'Debug';
  if (process.platform !== 'win32') generatorArgs.push(`-DCMAKE_BUILD_TYPE=${configuration}`);
  execFileSync('cmake', ['-S', path.join(pkgDir, '.napi-mbt'), '-B', buildRoot].concat(generatorArgs), { cwd: pkgDir, stdio: 'inherit' });
  execFileSync('cmake', ['--build', buildRoot, '--config', configuration], { cwd: pkgDir, stdio: 'inherit' });
  const built = process.platform === 'win32' ? path.join(buildRoot, configuration, 'napi_mbt.node') : path.join(buildRoot, 'napi_mbt.node');
  if (!fs.existsSync(built)) throw new Error(`CMake did not produce ${built}`);
  const outputDir = path.join(pkgDir, 'artifacts', outputTarget);
  mkdirp(outputDir);
  fs.copyFileSync(built, path.join(outputDir, 'napi_mbt.node'));
  console.log(`[napi-mbt] built ${path.join(outputDir, 'napi_mbt.node')}`);
}

module.exports = main;
