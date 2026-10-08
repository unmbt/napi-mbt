///|
async fn initialize(
  directory : String,
  requested_name : String?,
  force : Bool,
) -> Unit {
  mkdirp(directory, recursive=true)
  let dir = @fs.realpath(directory)
  let components = dir.replace_all(old="\\", new="/").split("/").to_array()
  let name = requested_name.unwrap_or(
    components[components.length() - 1].to_owned(),
  )
  if name.is_empty() || name.contains("\n") || name.contains("\r") {
    fail("Invalid package name")
  }
  let pkg_json : Json = {
    "name": name,
    "version": "0.1.0",
    "main": "index.cjs",
    "module": "index.mjs",
    "types": "index.d.ts",
    "exports": {
      ".": {
        "types": "./index.d.ts",
        "require": "./index.cjs",
        "import": "./index.mjs",
        "default": "./index.cjs",
      },
    },
    "scripts": { "test": "node test/smoke.cjs && node test/smoke.mjs" },
  }
  let files : Map[String, String] = Map([])
  for name, text in @assets.files() {
    if name.has_prefix("template/") {
      files[name[9:].to_owned()] = text
    }
  }
  files["package.json"] = pkg_json.stringify(indent=2) + "\n"
  files["napi-mbt.json"] = (
      {
        "napiVersion": 1,
        "generator": "auto",
        "builder": "auto",
        "targets": ["win32-x64-msvc", "darwin-arm64", "linux-x64-gnu"],
        "features": [],
        "cjs": true,
        "esm": true,
      } : Json).stringify(indent=2) +
    "\n"
  files["bump.config.json"] = (
      { "execute": "napi-mbt-cli build --release && npm test", "all": true } :
      Json).stringify(indent=2) +
    "\n"
  files["moon.mod"] = "name = " +
    name.replace_all(old="@", new="").to_json().stringify() +
    "\nversion = \"0.1.0\"\npreferred_target = \"native\"\nsupported_targets = \"native\"\n"
  let moon_package =
    #|import { "moonbitlang/core/encoding/utf8" }
    #|pkgtype(kind: "foreign_library")
    #|options(
    #|  "native-stub": ["stub.c", "napi_glue.c"],
    #|  link: { "native": {
    #|    "cc-flags": "",
    #|    "stub-cc-flags": "",
    #|    "cc-link-flags": "",
    #|    "exports": [],
    #|  } },
    #|)
    #|
  files["moon.pkg"] = moon_package
  files["lib.mbt"] = "///|\n#export_name(\"mbt_add\")\npub fn add(a : Int, b : Int) -> Int { a + b }\n"
  files[".gitignore"] = "_build/\n.mooncakes/\n.napi-mbt/\nartifacts/\nnode_modules/\n"
  files["test/smoke.cjs"] = "const assert = require('assert');\nconst addon = require('../index.cjs');\nassert.strictEqual(addon.mbt_add(2, 3), 5);\nconsole.log('napi-mbt template smoke test passed');\n"
  files["test/smoke.mjs"] = "import assert from 'assert';\nimport addon, { mbt_add } from '../index.mjs';\nassert.strictEqual(mbt_add(2, 3), 5);\nassert.strictEqual(addon.mbt_add, mbt_add);\n"
  let workflow =
    #|name: build
    #|on: [push, pull_request]
    #|jobs:
    #|  build:
    #|    strategy:
    #|      matrix:
    #|        os: [ubuntu-latest, macos-latest, windows-latest]
    #|    runs-on: ${{ matrix.os }}
    #|    steps:
    #|      - uses: actions/checkout@v4
    #|      - uses: hustcer/setup-moonbit@v1
    #|      - run: moon install unmbt/napi-mbt/cmd/napi-mbt-cli
    #|      - run: napi-mbt-cli build --release
    #|      - uses: actions/setup-node@v4
    #|        with: { node-version: 20 }
    #|      - run: npm test
    #|
  files[".github/workflows/build.yml"] = workflow
  if !force {
    let names = files.keys().to_array()
    names.append([
      "napi_exports.mbt", "napi_glue.c", "napi_manifest.json", "index.d.ts", "index.cjs",
      "index.mjs",
    ])
    for name in names {
      if @fs.exists(dir + "/" + name) {
        fail("Refusing to overwrite \{name}; use --force")
      }
      let parts = name.split("/").to_array()
      for count in 1..<parts.length() {
        let parent = dir + "/" + parts[:count].map(p => p.to_owned()).join("/")
        if @fs.exists(parent) && @fs.kind(parent) != Directory {
          fail("Not a directory: \{parent}")
        }
      }
    }
  }
  for name, text in files {
    let path = dir + "/" + name
    if name.find("/") is Some(_) {
      let parts = path.split("/").to_array()
      mkdirp(
        parts[:parts.length() - 1].map(p => p.to_owned()).join("/"),
        recursive=true,
      )
    }
    write_file(path, text)
  }
  ignore(generate(dir, false, None))
  println("[napi-mbt] initialized \{dir}")
}
