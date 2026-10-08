'use strict';

// Publish addon platform packages and the root facade in dependency order.
// This script only runs npm publish when explicitly invoked by a release job.
var fs = require('fs');
var path = require('path');
var childProcess = require('child_process');

var root = path.resolve(__dirname, '..');
var platformRoot = path.join(root, 'npm');
// npm is a .cmd shim on Windows. `execFileSync('npm.cmd', ...)` is rejected
// by some Node/Windows combinations, so let the platform shell resolve it.
var npmCommand = 'npm';
var dryRun = process.argv.indexOf('--dry-run') >= 0;
var platformsOnly = process.argv.indexOf('--platforms-only') >= 0;
var tagIndex = process.argv.indexOf('--tag');
var tag = tagIndex >= 0 ? process.argv[tagIndex + 1] : null;

function runPublish(directory) {
  if (!dryRun && directory.indexOf(platformRoot + path.sep) === 0 && !fs.existsSync(path.join(directory, 'napi_mbt.node'))) {
    throw new Error('Missing napi_mbt.node for ' + path.basename(directory) + '; build that target before publishing.');
  }
  // `npm publish --dry-run` still performs registry version checks on some
  // npm releases. `npm pack --dry-run` is the deterministic inspection mode
  // we want for CI and local verification.
  var args = [dryRun ? 'pack' : 'publish', directory];
  if (dryRun) args.push('--dry-run');
  else args.push('--access', 'public');
  if (tag) args.push('--tag', tag);
  if (process.platform === 'win32') {
    var quote = function (value) {
      var text = String(value);
      return /\s/.test(text) ? '"' + text.replace(/"/g, '\\"') + '"' : text;
    };
    var commandLine = npmCommand + ' ' + args.map(quote).join(' ');
    childProcess.execFileSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', commandLine], { cwd: root, stdio: 'inherit' });
  } else {
    childProcess.execFileSync(npmCommand, args, { cwd: root, stdio: 'inherit' });
  }
}

function packageDirectories() {
  if (!fs.existsSync(platformRoot)) return [];
  // prepublish refreshes this list from napi-mbt.json. Retained metadata for
  // paused targets must not cause those packages to be published again.
  var optionalDependencies = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).optionalDependencies || {};
  return fs.readdirSync(platformRoot).map(function (name) {
    return path.join(platformRoot, name);
  }).filter(function (directory) {
    var manifest = path.join(directory, 'package.json');
    return fs.existsSync(manifest) && Object.prototype.hasOwnProperty.call(
      optionalDependencies, JSON.parse(fs.readFileSync(manifest, 'utf8')).name
    );
  }).sort();
}

function main() {
  const local = path.join(root, '_build/native/release/build/cmd/napi-mbt-cli/napi-mbt-cli.exe');
  const cli = process.env.NAPI_MBT_CLI || (fs.existsSync(local) ? local : 'napi-mbt-cli');
  childProcess.execFileSync(cli, ['prepublish'], { cwd: root, stdio: 'inherit' });
  packageDirectories().forEach(runPublish);
  if (!platformsOnly) {
    runPublish(root);
  }
}

main();
