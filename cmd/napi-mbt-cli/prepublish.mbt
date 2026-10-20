///|
async fn prepublish(dir : String, target_override : String?) -> Unit {
  let dir = @fs.realpath(dir)
  let lock = project_lock(dir)
  defer lock.close()
  let pkg = read_object(dir + "/package.json", required=true)
  let name = str(pkg, "name", "")
  let version = str(pkg, "version", "")
  if name.is_empty() || version.is_empty() {
    fail("package.json requires name and version")
  }
  validate_package_version(dir, version)
  let conf = config(dir)
  let artifact_root = local_artifact_root(dir)
  let targets = match target_override {
    Some(target) => [target]
    None => if conf.targets.is_empty() { [host_target()] } else { conf.targets }
  }
  for target in targets {
    if !supported_targets.contains(target) {
      fail("Unsupported target: \{target}")
    }
    if !@fs.exists(artifact_root + "/" + target + "/napi_mbt.node") {
      fail(
        "Missing release artifact for \{target}; build every requested target before prepublish",
      )
    }
    validate_artifact(
      @fs.read_file(artifact_root + "/" + target + "/napi_mbt.node").binary(),
      target,
    )
    verify_receipt(dir, target, artifact_root)
  }
  // Release preparation must not hide stale declarations or changed signatures.
  let conf = generate(dir, true, check_package=false).config
  let assets = @assets.files()
  mkdirp(dir + "/licenses")
  let licenses = [
    ("napi-mbt.txt", "RUNTIME-LICENSE"),
    ("node-api.txt", "NODE-API-LICENSE"),
    ("moonbit-async.txt", "async/LICENSE"),
    ("libuv.txt", "async/LIBUV-LICENSE"),
  ]
  for (filename, key) in licenses {
    write_text_file(dir + "/licenses/" + filename, assets[key])
  }
  let optional = match pkg.get("optionalDependencies") {
    Some(value) => object(value)
    None => Map([])
  }
  if target_override is None {
    for key in optional.keys().to_array() {
      if supported_targets.any(target => key == name + "-" + target) {
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
      "files": ["napi_mbt.node", "licenses"],
      "exports": { ".": "./napi_mbt.node", "./package.json": "./package.json" },
      "engines": {
        "node": node_engine(
          conf.napi_version,
          false,
          streams=conf.features.contains("streams"),
        ),
      },
      "napiVersion": conf.napi_version,
      "napiTarget": target,
    })
    if parts[0] == "linux" {
      child["libc"] = ["glibc"]
    }
    mkdirp(path, recursive=true)
    mkdirp(path + "/licenses")
    for (filename, key) in licenses {
      write_text_file(path + "/licenses/" + filename, assets[key])
    }
    if pkg.get("license") is Some(license) {
      child["license"] = license
    }
    if @fs.exists(dir + "/LICENSE") {
      write_file(path + "/LICENSE", @fs.read_file(dir + "/LICENSE"))
    }
    let artifact = artifact_root + "/" + target + "/napi_mbt.node"
    write_file(path + "/napi_mbt.node", @fs.read_file(artifact))
    write_json(path + "/package.json", Json(child))
    if @fs.exists(path + "/index.mjs") {
      @fs.remove(path + "/index.mjs")
    }
    optional[child_name] = Json(version)
  }
  pkg["optionalDependencies"] = Json(optional)
  write_json(dir + "/package.json", package_metadata(pkg, conf))
  println("[napi-mbt] prepared \{targets.length()} platform package(s)")
}
