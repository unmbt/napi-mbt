///|
async fn prepublish(dir : String, target_override : String?) -> Unit {
  let pkg = read_object(dir + "/package.json", required=true)
  let name = str(pkg, "name", "")
  let version = str(pkg, "version", "")
  if name.is_empty() || version.is_empty() {
    fail("package.json requires name and version")
  }
  let conf = config(dir, None)
  let targets = match target_override {
    Some(target) => [target]
    None => if conf.targets.is_empty() { [host_target()] } else { conf.targets }
  }
  for target in targets {
    if !supported_targets.contains(target) {
      fail("Unsupported target: \{target}")
    }
  }
  let optional = match pkg.get("optionalDependencies") {
    Some(value) => object(value)
    None => Map([])
  }
  if target_override is None {
    for key in optional.keys().to_array() {
      if key.has_prefix(name + "-") {
        optional.remove(key)
      }
    }
  }
  for target in targets {
    let child_name = name + "-" + target
    let path = dir + "/npm/" + target
    let parts = target.split("-").to_array()
    let child = object({
      "name": child_name,
      "version": version,
      "os": [parts[0].to_owned()],
      "cpu": [parts[1].to_owned()],
      "main": "napi_mbt.node",
      "files": ["napi_mbt.node", "index.mjs"],
      "exports": {
        ".": {
          "require": "./napi_mbt.node",
          "import": "./index.mjs",
          "default": "./napi_mbt.node",
        },
      },
      "engines": { "node": ">=8.6" },
      "napiVersion": conf.napi_version,
    })
    if parts[0] == "linux" {
      child["libc"] = ["glibc"]
    }
    mkdirp(path, recursive=true)
    let artifact = dir + "/artifacts/" + target + "/napi_mbt.node"
    if @fs.exists(artifact) {
      write_file(path + "/napi_mbt.node", @fs.read_file(artifact))
    } else {
      println(
        "[napi-mbt] no artifact for \{target}; metadata was generated for CI cross-builds",
      )
    }
    write_json(path + "/package.json", child.to_json())
    write_file(
      path + "/index.mjs",
      "import { createRequire } from 'module';\nconst require = createRequire(import.meta.url);\nexport default require('./napi_mbt.node');\n",
    )
    optional[child_name] = version.to_json()
  }
  pkg["optionalDependencies"] = optional.to_json()
  write_json(dir + "/package.json", pkg.to_json())
  println("[napi-mbt] prepared \{targets.length()} platform package(s)")
}
