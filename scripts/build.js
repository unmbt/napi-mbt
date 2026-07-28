const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const PKG_PATH = path.join(__dirname, '..', 'moon.pkg');
const CACHE_DIR = path.join(__dirname, '..', 'node_modules', '.cache', 'napi-mbt');
const NAPI_LIB_PATH = path.join(CACHE_DIR, 'napi.lib');

// 探测本机 MSVC 工具链中的 lib.exe
function findLibExe() {
  try {
    const vswhere = path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Microsoft Visual Studio', 'Installer', 'vswhere.exe');
    const vsPath = execSync(`"${vswhere}" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`, { encoding: 'utf8' }).trim();
    if (!vsPath) return null;
    
    const msvcPath = path.join(vsPath, 'VC', 'Tools', 'MSVC');
    const versions = fs.readdirSync(msvcPath);
    // 取最新的工具链版本
    versions.sort().reverse();
    for (const v of versions) {
      const libPath = path.join(msvcPath, v, 'bin', 'Hostx64', 'x64', 'lib.exe');
      if (fs.existsSync(libPath)) return libPath;
    }
  } catch (e) {
    return null;
  }
  return null;
}

// 通过 .def 动态提炼极简的 napi.lib，干掉臃肿的 node.lib
function generateNapiLib() {
  if (!fs.existsSync(CACHE_DIR)) {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
  }
  
  if (fs.existsSync(NAPI_LIB_PATH)) {
    return; // 已经生成过，直接复用万能库
  }

  const libExe = findLibExe();
  if (!libExe) {
    throw new Error('找不到 lib.exe，请确保安装了 Visual Studio 的 C++ 构建工具。');
  }

  const defPath = path.join(__dirname, '..', 'node_modules', 'node-api-headers', 'def', 'node_api.def');
  if (!fs.existsSync(defPath)) {
    throw new Error('未找到 node_api.def，请确保已经执行 npm install。');
  }

  console.log(`\n[魔法炼金] 正在通过 lib.exe 从 node_api.def 极速生成万能存根库...`);
  execSync(`"${libExe}" /DEF:"${defPath}" /OUT:"${NAPI_LIB_PATH}" /MACHINE:X64`, { stdio: 'inherit' });
}

async function main() {
  const platform = os.platform();
  let ccLinkFlags = "";

  if (platform === 'win32') {
    generateNapiLib();
    // Use relative path for cc-link-flags to avoid absolute paths in moon.pkg
    const relativeLibPath = path.relative(path.join(__dirname, '..'), NAPI_LIB_PATH).replace(/\\/g, '/');
    ccLinkFlags = `/LD "./${relativeLibPath}"`;
  } else if (platform === 'darwin') {
    ccLinkFlags = "-shared -undefined dynamic_lookup";
  } else {
    ccLinkFlags = "-shared";
  }

  // Generate moon.pkg in KDL format natively
  const pkgContent = `import {
  "moonbitlang/core/encoding/utf8",
}

options(
  "is-main": false,
  "native-stub": [ "stub.c" ],
  link: {
    "native": {
      "stub-cc-flags": "-I./node_modules/node-api-headers/include",
      "cc-link-flags": "${ccLinkFlags.replace(/"/g, '\\"')}",
      "exports": [
        "moonbit_napi_init",
        "moonbit_napi_dispatcher",
        "moonbit_release_handle",
      ],
    },
  },
)
`;

  fs.writeFileSync(PKG_PATH, pkgContent);
  
  // Remove moon.pkg.json if it exists to avoid conflicts
  const oldPkgJsonPath = path.join(__dirname, '..', 'moon.pkg.json');
  if (fs.existsSync(oldPkgJsonPath)) {
    fs.unlinkSync(oldPkgJsonPath);
  }

  console.log(`[构建] 正在执行 moon build --target native...`);
  execSync('moon build --target native', { stdio: 'inherit', cwd: path.join(__dirname, '..') });

  const buildDir = path.join(__dirname, '..', '_build', 'native', 'debug', 'build');
  if (!fs.existsSync(buildDir)) {
    console.error("未找到构建目录:", buildDir);
    process.exit(1);
  }
  
  const files = fs.readdirSync(buildDir);
  let artifact = files.find(f => {
    if (!f.startsWith('napi-mbt')) return false;
    if (f.endsWith('.lib') || f.endsWith('.obj') || f.endsWith('.o') || f.endsWith('.a') || f.endsWith('.pdb') || f.endsWith('.ilk') || f.endsWith('.exp') || f.endsWith('.core') || f.endsWith('.c') || f.endsWith('.mi')) {
      return false;
    }
    return true;
  });
  
  if (artifact) {
    const src = path.join(buildDir, artifact);
    const targetDir = path.join(__dirname, '..', 'dist', `${platform}-${os.arch()}`);
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    
    const dest = path.join(targetDir, 'napi_mbt.node');
    fs.copyFileSync(src, dest);
    console.log(`\n[成功] 跨版本万能插件已就绪: ${dest}`);
  } else {
    console.error("未能从构建目录中找到二进制产物。");
    process.exit(1);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
