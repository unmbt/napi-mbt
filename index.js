const os = require('os');
const path = require('path');

const platform = os.platform();
const arch = os.arch();
const pkgName = 'napi-mbt-' + platform + '-' + arch;

let addon;
try {
  // 1. Try to load from optional dependencies (production)
  addon = require(pkgName);
} catch (e) {
  try {
    // 2. Try to load from local build artifacts (development)
    const localPath = path.join(__dirname, 'artifacts', platform + '-' + arch, 'napi_mbt.node');
    addon = require(localPath);
  } catch (err) {
    throw new Error('Failed to load native module for ' + platform + '-' + arch + '. Ensure ' + pkgName + ' is installed, or build it locally.');
  }
}

module.exports = addon;
