///|
fn loaders(
  exports : Array[String],
  package_name : String,
  package_version : String,
  version : Int32,
  workers~ : Bool = false,
) -> (String, String) {
  let name = Json(package_name + "-").stringify()
  let expected = Json(package_version).stringify()
  let body =
    $|const path = require('path');
    $|const fs = require('fs');
    $|const requiredNapi = \{version};
    $|const actualNapi = Number(process.versions && process.versions.napi || 0);
    $|let target = process.platform + '-' + process.arch;
    $|const attemptedPaths = [];
    $|function failure(code, detail, cause) {
    $|  const error = new Error(detail + ' [target=' + target + ', N-API=' + actualNapi + ', required=' + requiredNapi + ', paths=' + attemptedPaths.join(', ') + ']');
    $|  error.code = code;
    $|  error.target = target;
    $|  error.requiredNapiVersion = requiredNapi;
    $|  error.actualNapiVersion = actualNapi;
    $|  error.attemptedPaths = attemptedPaths.slice();
    $|  if (cause !== undefined) error.cause = cause;
    $|  return error;
    $|}
    $|if (process.platform === 'win32' && process.arch === 'x64') {
    $|  target += '-msvc';
    $|} else if (process.platform === 'darwin' && ['x64', 'arm64'].indexOf(process.arch) !== -1) {
    $|  // Both Darwin architectures use the system C library.
    $|} else if (process.platform === 'linux' && ['x64', 'arm64'].indexOf(process.arch) !== -1) {
    $|  let libc;
    $|  try {
    $|    if (process.report && process.report.getReport) {
    $|      const report = process.report.getReport();
    $|      if (report.header && report.header.glibcVersionRuntime) libc = 'gnu';
    $|      else if ((report.sharedObjects || []).some(file => /(?:ld-|libc[.])musl-/.test(file))) libc = 'musl';
    $|    } else {
    $|      const ldd = fs.readFileSync('/usr/bin/ldd', 'utf8');
    $|      if (/GNU C Library|GNU libc|GLIBC/.test(ldd)) libc = 'gnu';
    $|      else if (/musl/.test(ldd)) libc = 'musl';
    $|    }
    $|    if (!libc) {
    $|      const maps = fs.readFileSync('/proc/self/maps', 'utf8');
    $|      if (/(?:ld-|libc[.])musl-/.test(maps)) libc = 'musl';
    $|      else if (/libc(?:-[0-9.]+)?[.]so[.]6/.test(maps)) libc = 'gnu';
    $|    }
    $|  } catch (cause) {
    $|    throw failure('ERR_NAPI_PLATFORM', 'Cannot identify Linux libc', cause);
    $|  }
    $|  if (!libc) throw failure('ERR_NAPI_PLATFORM', 'Cannot identify Linux libc');
    $|  target += '-' + libc;
    $|} else {
    $|  throw failure('ERR_NAPI_PLATFORM', 'Unsupported OS or CPU');
    $|}
    $|if (actualNapi < requiredNapi) throw failure('ERR_NAPI_VERSION', 'Unsupported Node-API version');
    $|let outputDirectory = path.join(__dirname, 'artifacts');
    $|const buildLocation = path.join(__dirname, '.napi-mbt', 'build-output.json');
    $|if (fs.existsSync(buildLocation)) {
    $|  attemptedPaths.push(buildLocation);
    $|  try {
    $|    const location = JSON.parse(fs.readFileSync(buildLocation, 'utf8'));
    $|    if (!location || typeof location.directory !== 'string' || !path.isAbsolute(location.directory)) throw new TypeError('Invalid build output directory');
    $|    outputDirectory = location.directory;
    $|  } catch (cause) { throw failure('ERR_NAPI_LOAD', 'Cannot read local build location', cause); }
    $|}
    $|const local = path.join(outputDirectory, target, 'napi_mbt.node');
    $|attemptedPaths.push(local);
    $|let addon;
    $|if (fs.existsSync(local)) {
    $|  try { addon = require(local); }
    $|  catch (cause) { throw failure('ERR_NAPI_LOAD', 'Cannot load local addon', cause); }
    $|} else {
    $|  const packageName = \{name} + target;
    $|  const metadataPath = packageName + '/package.json';
    $|  attemptedPaths.push(metadataPath);
    $|  let metadata;
    $|  try { metadata = require(metadataPath); }
    $|  catch (cause) { throw failure('ERR_NAPI_PACKAGE', 'Cannot load platform package metadata', cause); }
    $|  if (metadata.name !== packageName || metadata.version !== \{expected} || metadata.napiVersion !== requiredNapi || metadata.napiTarget !== target) {
    $|    throw failure('ERR_NAPI_PACKAGE_VERSION', 'Platform package metadata mismatch; expected ' + packageName + '@' + \{expected});
    $|  }
    $|  attemptedPaths.push(packageName);
    $|  try { addon = require(packageName); }
    $|  catch (cause) { throw failure('ERR_NAPI_LOAD', 'Cannot load platform addon', cause); }
    $|}
    $|
  let body = if workers {
    body
    .replace_all(old="let addon;", new="let addon;\nlet nativePath = local;")
    .replace_all(
      old="try { addon = require(packageName); }",
      new="try { nativePath = require.resolve(packageName); addon = require(nativePath); }",
    ) +
    "addon = require('./napi_workers.cjs')(addon, nativePath);\n"
  } else {
    body
  }
  let cjs = body + "module.exports = addon;\n"
  let esm = "import { createRequire as $napiRequire } from 'module';\nimport { fileURLToPath as $napiFileURL } from 'url';\nimport { dirname as $napiDirname } from 'path';\nconst $napiAddon = (() => {\nconst require = $napiRequire(import.meta.url);\nconst __dirname = $napiDirname($napiFileURL(import.meta.url));\n" +
    body +
    "return addon;\n})();\nexport default $napiAddon;\n" +
    exports.map(item => "export const \{item} = $napiAddon.\{item};").join("\n") +
    "\n"
  (cjs, esm)
}
