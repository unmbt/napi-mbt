const os = require('os');
const path = require('path');

const platform = os.platform();
const arch = os.arch();

const addonPath = path.join(__dirname, '..', 'dist', `${platform}-${arch}`, 'napi_mbt.node');

try {
  const addon = require(addonPath);
  module.exports = addon;
} catch (err) {
  console.error(`Failed to load native addon from ${addonPath}.`);
  console.error(`Did you forget to build the project? Try running "npm run build".`);
  throw err;
}
