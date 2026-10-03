const path = require('path');
const requiredNapi = 1;
const actualNapi = Number(process.versions && process.versions.napi || 0);
if (actualNapi < requiredNapi) throw new Error('This native module requires N-API ' + requiredNapi + ', found ' + actualNapi);
let target = process.platform + '-' + process.arch;
if (process.platform === 'win32') target += '-msvc';
if (process.platform === 'linux') target += '-gnu';
let addon;
try { addon = require("napi-mbt-" + target); } catch (e) { addon = require(path.join(__dirname, 'artifacts', target, 'napi_mbt.node')); }
module.exports = addon;
