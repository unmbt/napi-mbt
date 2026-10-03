const fs = require('fs');
const path = require('path');
const webTreeSitter = require('web-tree-sitter');
const Parser = webTreeSitter.Parser || webTreeSitter;
const Language = webTreeSitter.Language || Parser.Language;

const TYPES = new Set(['Int', 'Double', 'Bool', 'String', 'Bytes', 'NapiBufferView']);
const RETURNS = new Set(['Int', 'Double', 'Bool', 'String', 'Bytes', 'Unit']);
const C_KEYWORDS = new Set(('auto break case char const continue default do double else enum extern float for goto if int long register return short signed sizeof static struct switch typedef union unsigned void volatile while inline restrict _Bool _Complex _Imaginary').split(' '));
const JS_KEYWORDS = new Set(('await break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new return super switch this throw try typeof var void while with yield enum implements interface package private protected public static null true false').split(' '));

function fail(message) { const error = new Error(message); error.code = 'NAPI_MBT_GENERATE_ERROR'; throw error; }
function isValidExportName(name) { return /^[A-Za-z_][A-Za-z0-9_]*$/.test(name) && !C_KEYWORDS.has(name) && !JS_KEYWORDS.has(name); }

function parseConfig(pkgDir) {
  const filename = path.join(pkgDir, 'napi-mbt.json');
  let config = {};
  if (fs.existsSync(filename)) { try { config = JSON.parse(fs.readFileSync(filename, 'utf8')); } catch (e) { fail(`Invalid napi-mbt.json: ${e.message}`); } }
  const version = config.napiVersion === undefined ? 1 : Number(config.napiVersion);
  if (!Number.isInteger(version) || version < 1) fail('napiVersion must be a positive integer');
  const features = Array.isArray(config.features) ? config.features : [];
  const required = { promise: 1, threadsafe_function: 4, bigint: 6 };
  let requiredVersion = 1;
  features.forEach(feature => { if (!Object.prototype.hasOwnProperty.call(required, feature)) fail(`Unknown N-API feature: ${feature}`); requiredVersion = Math.max(requiredVersion, required[feature]); });
  if (version < requiredVersion) fail(`napiVersion ${version} is lower than required feature level ${requiredVersion}`);
  return Object.assign({ napiVersion: version, generator: 'auto', builder: 'auto', targets: [], features: [], cjs: true, esm: true }, config);
}

function parseParameter(node, filename) {
  const text = node.text.trim();
  const colon = text.indexOf(':');
  if (colon < 0) fail(`${filename}:${node.startPosition.row + 1}: parameter must have a type`);
  const name = text.slice(0, colon).trim();
  const type = text.slice(colon + 1).trim();
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) || !TYPES.has(type)) fail(`${filename}:${node.startPosition.row + 1}: unsupported parameter ${text}`);
  return { name, type };
}

function findAttribute(functionNode) {
  const attributes = functionNode.children.find(c => c.type === 'attributes');
  if (!attributes) return null;
  const attr = attributes.children.find(c => c.type === 'attribute' && c.text.indexOf('#export_name') === 0);
  if (!attr) return null;
  const match = attr.text.match(/^#export_name\(\s*"((?:\\.|[^"\\])*)"\s*\)$/);
  if (!match) fail(`${attr.startPosition.row + 1}: malformed #export_name attribute`);
  let name;
  try { name = JSON.parse('"' + match[1] + '"'); } catch (_) { fail(`${attr.startPosition.row + 1}: malformed export name`); }
  if (!isValidExportName(name)) fail(`${attr.startPosition.row + 1}: invalid export name ${JSON.stringify(name)}`);
  return { name, line: attr.startPosition.row + 1 };
}

function collectFunctions(root, filename) {
  const result = [];
  function visit(node) {
    if (node.type === 'function_definition') {
      const attr = findAttribute(node);
      if (attr) {
        const nameNode = node.children.find(c => c.type === 'function_identifier' || c.type === 'identifier');
        const paramsNode = node.children.find(c => c.type === 'parameters');
        const returnNode = node.children.find(c => c.type === 'return_type');
        if (!nameNode || !paramsNode) fail(`${filename}:${node.startPosition.row + 1}: #export_name must decorate a function`);
        const params = paramsNode.children.filter(c => c.type === 'parameter').map(p => parseParameter(p, filename));
        const ret = returnNode ? returnNode.text.replace(/^->\s*/, '').replace(/!.*$/, '').trim() : 'Unit';
        if (!RETURNS.has(ret)) fail(`${filename}:${node.startPosition.row + 1}: unsupported return type ${ret}`);
        result.push({ sourceName: nameNode.text, exportName: attr.name, params, ret, throws: !!returnNode && returnNode.text.indexOf('!') >= 0, line: attr.line, filename });
      }
    }
    for (let i = 0; i < node.childCount; i++) visit(node.child(i));
  }
  visit(root);
  return result;
}

function tsType(type) { if (type === 'Int' || type === 'Double') return 'number'; if (type === 'Bool') return 'boolean'; if (type === 'String') return 'string'; if (type === 'Bytes' || type === 'NapiBufferView') return 'Buffer'; return 'unknown'; }

function adapterCode(fn) {
  const adapter = `napi_mbt_adapter_${fn.exportName}`;
  const args = fn.params.map((p, i) => `a${i} : NapiValue`).join(', ');
  let signature;
  let declaration;
  const oneLineSignature = `pub fn ${adapter}(${['env : NapiEnv'].concat(fn.params.map((p, i) => `a${i} : NapiValue`)).join(', ')}) -> NapiValue {`;
  if (fn.params.length <= 1 && oneLineSignature.length <= 80) {
    signature = ['env : NapiEnv'].concat(fn.params.map((p, i) => `a${i} : NapiValue`)).join(', ');
    declaration = `pub fn ${adapter}(${signature}) -> NapiValue {`;
  } else {
    signature = ['  env : NapiEnv'].concat(fn.params.map((p, i) => `  a${i} : NapiValue`)).join(',\n');
    declaration = `pub fn ${adapter}(\n${signature},\n) -> NapiValue {`;
  }
  let out = `\n///|\n#export_name("${adapter}")\n${declaration}\n`;
  fn.params.forEach((p, i) => { out += `  let p${i} = get_${p.type}(env, a${i})\n`; });
  const call = `${fn.sourceName}(${fn.params.map((_, i) => `p${i}`).join(', ')})`;
  if (fn.throws) out += `  let result = ${call} catch {\n    e => { let _ = napi_throw_error(env, b"", @utf8.encode(e.to_string())); return moonbit_dummy_napi_value() }\n  }\n`;
  else out += `  let result : ${fn.ret} = ${call}\n`;
  fn.params.forEach((p, i) => { if (p.type === 'NapiBufferView') out += `  p${i}.invalidate()\n`; });
  out += `  set_${fn.ret}(env, result)\n}\n`;
  return out;
}

function cGlueCode(functions) {
  let out = `/* Auto-generated by napi-mbt. DO NOT EDIT. */\n#include <node_api.h>\n#include <stddef.h>\n#include <stdint.h>\n\nextern void moonbit_init(void);\n`;
  functions.forEach(fn => { const params = fn.params.map(() => 'napi_value').join(', '); out += `extern napi_value napi_mbt_adapter_${fn.exportName}(napi_env env${params ? ', ' + params : ''});\n`; });
  functions.forEach(fn => {
    const n = fn.params.length;
    out += `\nstatic napi_value napi_mbt_callback_${fn.exportName}(napi_env env, napi_callback_info info) {\n  size_t argc = ${n};\n  napi_value argv[${Math.max(n, 1)}];\n  napi_status status = napi_get_cb_info(env, info, &argc, argv, NULL, NULL);\n  if (status != napi_ok) return NULL;\n  if (argc < ${n}) { napi_throw_error(env, NULL, "Missing argument"); return NULL; }\n  return napi_mbt_adapter_${fn.exportName}(env${n ? ', ' + fn.params.map((_, i) => `argv[${i}]`).join(', ') : ''});\n}\n`;
  });
  out += `\n#if defined(_WIN32)\n#define NAPI_MBT_EXPORT __declspec(dllexport)\n#else\n#define NAPI_MBT_EXPORT __attribute__((visibility("default")))\n#endif\n\nNAPI_MBT_EXPORT napi_value napi_register_module_v1(napi_env env, napi_value exports) {\n  moonbit_init();\n`;
  functions.forEach(fn => { out += `  napi_value fn_${fn.exportName};\n  napi_create_function(env, "${fn.exportName}", NAPI_AUTO_LENGTH, napi_mbt_callback_${fn.exportName}, NULL, &fn_${fn.exportName});\n  napi_set_named_property(env, exports, "${fn.exportName}", fn_${fn.exportName});\n`; });
  out += `  return exports;\n}\n`;
  return out;
}

function loaders(pkgDir, config, functions) {
  const pkgFile = path.join(pkgDir, 'package.json');
  let pkg = {};
  if (fs.existsSync(pkgFile)) { try { pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8')); } catch (_) {} }
  const packageName = pkg.name || 'napi-mbt-package';
  const required = Number(config.napiVersion || 1);
  const cjs = `const path = require('path');\nconst requiredNapi = ${required};\nconst actualNapi = Number(process.versions && process.versions.napi || 0);\nif (actualNapi < requiredNapi) throw new Error('This native module requires N-API ' + requiredNapi + ', found ' + actualNapi);\nlet target = process.platform + '-' + process.arch;\nif (process.platform === 'win32') target += '-msvc';\nif (process.platform === 'linux') target += '-gnu';\nlet addon;\ntry { addon = require(${JSON.stringify(packageName + '-')} + target); } catch (e) { addon = require(path.join(__dirname, 'artifacts', target, 'napi_mbt.node')); }\nmodule.exports = addon;\n`;
  const named = (functions || []).map(fn => `export const ${fn.exportName} = addon.${fn.exportName};`).join('\n');
  const esm = `import { createRequire } from 'module';\nconst require = createRequire(import.meta.url);\nconst addon = require('./index.cjs');\nexport default addon;\n${named}\n`;
  return { cjs, esm };
}

async function main(overridePkgDir, options) {
  const pkgDir = path.resolve(overridePkgDir || '.');
  options = options || {};
  const isCheck = !!options.check || process.argv.includes('--check');
  const config = parseConfig(pkgDir);
  const generator = options.generator || config.generator || 'auto';
  if (generator !== 'auto' && generator !== 'moonbit' && generator !== 'node') fail(`Unknown generator: ${generator}`);
  // The MoonBit scanner/emitter is kept as a pure package in generator/. A
  // filesystem/process bridge is not available on every MoonBit target, so
  // auto mode uses the Node transport while still keeping the same contract.
  // Explicit moonbit mode performs a native check before using that transport.
  if (generator === 'moonbit') {
    const localProject = path.join(pkgDir, 'generator', 'moon.pkg');
    const projectDir = fs.existsSync(localProject) ? pkgDir : path.resolve(__dirname, '../..');
    try { require('child_process').execFileSync('moon', ['check', '--target', 'native', 'generator'], { cwd: projectDir, stdio: 'inherit' }); }
    catch (error) { fail(`MoonBit generator check failed: ${error.message}`); }
  }
  await Parser.init();
  const parser = new Parser();
  let wasmPath;
  try { wasmPath = path.join(path.dirname(require.resolve('@unmbt/tree-sitter-moonbit/package.json')), 'tree-sitter-moonbit.wasm'); }
  catch (_) { wasmPath = path.resolve(__dirname, '../../node_modules/@unmbt/tree-sitter-moonbit/tree-sitter-moonbit.wasm'); }
  parser.setLanguage(await Language.load(wasmPath));
  const files = fs.readdirSync(pkgDir).filter(f => f.endsWith('.mbt') && !f.endsWith('_test.mbt') && !f.endsWith('_wbtest.mbt') && f !== 'napi_exports.mbt' && f !== '_napi_bindings.mbt' && f !== 'napi_bindings.mbt' && f !== 'napi_features.mbt' && f !== 'napi_types.mbt' && f !== 'napi_runtime.mbt');
  const functions = [];
  const userSources = [];
  for (const file of files) {
    const source = fs.readFileSync(path.join(pkgDir, file), 'utf8');
    userSources.push(source);
    const tree = parser.parse(source);
    if (tree.rootNode.hasError) fail(`${file} contains MoonBit syntax errors`);
    functions.push(...collectFunctions(tree.rootNode, file));
  }
  functions.sort((a, b) => a.exportName.localeCompare(b.exportName));
  const inferred = [];
  // Documentation comments are intentionally outside the scanner contract.
  const allUserSource = userSources.join('\n').replace(/^\s*\/\/\/.*$/gm, '');
  if (/\bnapi_threadsafe_function(?:_|\b)/i.test(allUserSource)) inferred.push('threadsafe_function');
  if (/\bnapi_bigint(?:_|\b)/i.test(allUserSource)) inferred.push('bigint');
  if (/\bnapi_promise(?:_|\b)/i.test(allUserSource)) inferred.push('promise');
  const featureMin = { promise: 1, threadsafe_function: 4, bigint: 6 };
  const required = config.features.concat(inferred).reduce((m, f) => Math.max(m, featureMin[f] || 1), 1);
  if (config.napiVersion < required) fail(`napiVersion ${config.napiVersion} is lower than inferred API requirement ${required}`);
  const seen = new Set();
  functions.forEach(fn => { if (seen.has(fn.exportName)) fail(`duplicate export name: ${fn.exportName}`); seen.add(fn.exportName); });
  let mbt = '// Auto-generated by napi-mbt. DO NOT EDIT.\n\n';
  functions.forEach(fn => { mbt += adapterCode(fn); });
  const dts = '// Auto-generated by napi-mbt. DO NOT EDIT.\n\n' + functions.map(fn => `export function ${fn.exportName}(${fn.params.map(p => `${p.name}: ${tsType(p.type)}`).join(', ')}): ${fn.ret === 'Unit' ? 'void' : tsType(fn.ret)};`).join('\n') + '\n';
  const manifestFeatures = Array.from(new Set(config.features.concat(inferred))).sort();
  const manifest = {
    napiVersion: config.napiVersion,
    requiredNapiVersion: Math.max(config.napiVersion, required),
    features: manifestFeatures,
    targets: config.targets || [],
    generator: config.generator || 'auto',
    builder: config.builder || 'auto',
    exports: functions
  };
  const loader = loaders(pkgDir, config, functions);
  const outputs = { 'napi_exports.mbt': mbt, 'napi_glue.c': cGlueCode(functions), 'napi_manifest.json': JSON.stringify(manifest, null, 2) + '\n', 'index.d.ts': dts, 'index.cjs': loader.cjs, 'index.mjs': loader.esm };
  for (const name of Object.keys(outputs)) {
    const target = path.join(pkgDir, name);
    if (isCheck) { if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8') !== outputs[name]) fail(`Generated file is not up-to-date: ${name}`); }
    else fs.writeFileSync(target, outputs[name]);
  }
  if (!isCheck) console.log(`Generated ${functions.length} N-API export(s).`);
  return manifest;
}

if (require.main === module) main(process.argv.slice(2).find(a => !a.startsWith('--'))).catch(err => { console.error('[napi-mbt]', err.message); process.exit(1); });
module.exports = main;
