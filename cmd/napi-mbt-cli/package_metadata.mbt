///|
// Node-API introduction versions, matching napi-rs/cli/src/utils/version.ts.
fn node_engine(version : Int32, esm : Bool) -> String {
  if esm && version <= 7 {
    return ">=12.20.0 <13 || >=14.13.1"
  }
  let versions = match version {
    1 => ["8.6.0", "9.0.0", "10.0.0"]
    2 => ["8.10.0", "9.3.0", "10.0.0"]
    3 => ["6.14.2", "8.11.2", "9.11.0", "10.0.0"]
    4 => ["10.16.0", "11.8.0", "12.0.0"]
    5 => ["10.17.0", "12.11.0", "13.0.0"]
    6 => ["10.20.0", "12.17.0", "14.0.0"]
    7 => ["10.23.0", "12.19.0", "14.12.0", "15.0.0"]
    8 => ["12.22.0", "14.17.0", "15.12.0", "16.0.0"]
    9 => ["18.17.0", "20.3.0", "21.1.0"]
    _ => ["22.14.0", "23.6.0"]
  }
  let ranges = []
  for i, value in versions {
    let last = i == versions.length() - 1
    let major = value.split(".").to_array()[0].to_owned()
    let upper = match major {
      "6" => 7
      "8" => 9
      "9" => 10
      "10" => 11
      "11" => 12
      "12" => 13
      "13" => 14
      "14" => 15
      "15" => 16
      "18" => 19
      "20" => 21
      "21" => 22
      "22" => 23
      _ => 24
    }
    let range = ">=" + value + (if last { "" } else { " <\{upper}" })
    ranges.push(range)
  }
  ranges.join(" || ")
}

///|
let managed_package_files : Array[String] = [
  "index.cjs", "index.mjs", "index.d.ts", "index.d.cts", "index.d.mts", "napi_manifest.json",
]

///|
fn package_metadata(pkg : Map[String, Json], conf : Config) -> Json raise {
  pkg["main"] = Json(if conf.cjs { "index.cjs" } else { "index.mjs" })
  if conf.esm {
    pkg["module"] = "index.mjs"
  } else {
    pkg.remove("module")
  }
  pkg["types"] = "index.d.ts"
  let root : Map[String, Json] = Map([])
  if conf.cjs {
    root["require"] = { "types": "./index.d.cts", "default": "./index.cjs" }
  }
  if conf.esm {
    root["import"] = { "types": "./index.d.mts", "default": "./index.mjs" }
  }
  root["default"] = Json(if conf.cjs { "./index.cjs" } else { "./index.mjs" })
  let exports = match pkg.get("exports") {
    Some(Object(values)) if values.keys().any(key => key.has_prefix(".")) =>
      values
    _ => Map([])
  }
  exports["."] = Json(root)
  pkg["exports"] = Json(exports)
  let files = strings(pkg, "files").filter(file => {
    !managed_package_files.contains(file)
  })
  if !files.contains("licenses") {
    files.push("licenses")
  }
  files.append(["index.d.ts", "napi_manifest.json"])
  if conf.cjs {
    files.append(["index.cjs", "index.d.cts"])
  }
  if conf.esm {
    files.append(["index.mjs", "index.d.mts"])
  }
  pkg["files"] = Json(files)
  let engines = match pkg.get("engines") {
    Some(value) => object(value)
    None => Map([])
  }
  engines["node"] = Json(node_engine(conf.napi_version, conf.esm))
  pkg["engines"] = Json(engines)
  Json(pkg)
}
