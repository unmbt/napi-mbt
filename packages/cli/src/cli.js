#!/usr/bin/env node

import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import generate from './generate.js';
import build from './index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const args = process.argv.slice(2);
const command = args[0];

async function main() {
  if (command === 'build') {
    const cwd = process.cwd();
    console.log(`[napi-mbt] Generating bindings...`);
    await generate(cwd);
    console.log(`[napi-mbt] Building native extension...`);
    await build(cwd);
    console.log(`[napi-mbt] Build successful.`);
  } else if (command === 'prepublish') {
    const cwd = process.cwd();
    const pkgPath = path.join(cwd, 'package.json');
    if (!fs.existsSync(pkgPath)) {
      console.error('No package.json found');
      process.exit(1);
    }
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    const platforms = [
      { os: 'win32', cpu: 'x64' },
      { os: 'darwin', cpu: 'x64' },
      { os: 'darwin', cpu: 'arm64' },
      { os: 'linux', cpu: 'x64' },
      { os: 'linux', cpu: 'arm64' }
    ];

    pkg.optionalDependencies = pkg.optionalDependencies || {};

    platforms.forEach(p => {
      const subPkgName = `${pkg.name}-${p.os}-${p.cpu}`;
      const subPkgDir = path.join(cwd, 'npm', `${p.os}-${p.cpu}`);
      fs.mkdirSync(subPkgDir, { recursive: true });

      const subPkg = {
        name: subPkgName,
        version: pkg.version,
        os: [p.os],
        cpu: [p.cpu],
        main: "napi_mbt.node",
        description: `${p.os} ${p.cpu} binary for ${pkg.name}`
      };
      
      fs.writeFileSync(path.join(subPkgDir, 'package.json'), JSON.stringify(subPkg, null, 2));
      pkg.optionalDependencies[subPkgName] = pkg.version;
    });

    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));

    const indexJsContent = `
const os = require('os');
const path = require('path');

const platform = os.platform();
const arch = os.arch();
const pkgName = '${pkg.name}-' + platform + '-' + arch;

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
`;
    fs.writeFileSync(path.join(cwd, 'index.js'), indexJsContent.trim() + '\n');
    console.log('[napi-mbt] Generated optional dependencies packages in npm/ and index.js loader.');

  } else {
    console.log(`Usage: napi-mbt <command>
Commands:
  build       Generate bindings and compile native Addon
  prepublish  Generate optional dependencies packages`);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
