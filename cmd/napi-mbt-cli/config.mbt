///|
let supported_targets : Array[String] = [
  "win32-x64-msvc", "darwin-x64", "darwin-arm64", "linux-x64-gnu", "linux-arm64-gnu",
]

///|
extern "c" fn host_raw() -> Bytes = "napi_mbt_host"

///|
fn host_target() -> String {
  let host = @utf8.decode_lossy(host_raw())
  if host.has_prefix("win32") {
    host + "-msvc"
  } else if host.has_prefix("linux") {
    host + "-gnu"
  } else {
    host
  }
}

///|
fn windows() -> Bool {
  host_target().has_prefix("win32")
}

///|
fn object(value : Json) -> Map[String, Json] raise {
  guard value is Object(items) else { fail("Expected a JSON object") }
  items
}

///|
fn str(
  items : Map[String, Json],
  key : String,
  default_value : String,
) -> String raise {
  match items.get(key) {
    None => default_value
    Some(String(value)) => value
    _ => fail("\{key} must be a string")
  }
}

///|
fn strings(items : Map[String, Json], key : String) -> Array[String] raise {
  match items.get(key) {
    None => []
    Some(Array(values)) =>
      values.map(value => {
        guard value is String(text) else { fail("\{key} must contain strings") }
        text
      })
    _ => fail("\{key} must be an array")
  }
}

///|
fn unique_strings(
  items : Map[String, Json],
  key : String,
) -> Array[String] raise {
  let values = strings(items, key)
  let seen : Map[String, Bool] = Map([])
  for value in values {
    if seen.contains(value) {
      fail("Duplicate \{key} value: \{value}")
    }
    seen[value] = true
  }
  values
}

///|
async fn read_object(
  path : String,
  required~ : Bool = false,
) -> Map[String, Json] {
  if !@fs.exists(path) {
    if required {
      fail("Missing \{path}")
    }
    return Map([])
  }
  object(@json.parse(@fs.read_file(path).text()))
}

///|
async fn write_json(path : String, value : Json) -> Unit {
  write_file(path, value.stringify(indent=2) + "\n")
}

///|
struct Config {
  napi_version : Int32
  builder : String
  targets : Array[String]
  features : Array[String]
  cjs : Bool
  esm : Bool
  classes : Array[@generator.ClassConfig]
}

///|
fn feature_version(name : String) -> Int32 raise {
  match name {
    "promise" => 1
    "threadsafe_function" => 4
    "bigint" => 6
    "buffer" => 7
    "class" | "callback" => 3
    _ => fail("Unknown N-API feature: \{name}")
  }
}

///|
fn parse_config(value : Json) -> Config raise {
  let items = object(value)
  for key in items.keys() {
    if ![
        "$schema", "napiVersion", "builder", "targets", "features", "cjs", "esm",
        "classes",
      ].contains(key) {
      fail("Unknown napi-mbt.json field: \{key}")
    }
  }
  ignore(str(items, "$schema", ""))
  let version = match items.get("napiVersion") {
    None => 4
    Some(Number(n, ..)) if n >= 1 && n <= 10 && n == n.to_int().to_double() =>
      n.to_int()
    _ => fail("napiVersion must be an integer from 1 to 10")
  }
  let cjs = boolean(items, "cjs", true)
  let esm = boolean(items, "esm", true)
  if !cjs && !esm {
    fail("At least one of cjs and esm must be enabled")
  }
  let builder = str(items, "builder", "auto")
  if !["auto", "cmake", "gcc", "clang", "msvc"].contains(builder) {
    fail("Unknown builder: \{builder}")
  }
  let targets = unique_strings(items, "targets")
  for target in targets {
    if !supported_targets.contains(target) {
      fail("Unsupported target: \{target}")
    }
  }
  let features = unique_strings(items, "features")
  for feature in features {
    let required = feature_version(feature)
    if version < required {
      fail(
        "napiVersion \{version} is lower than required feature level \{required}",
      )
    }
  }
  let classes = class_configurations(items.get("classes"))
  if !classes.is_empty() && version < 3 {
    fail("Classes require N-API 3 for environment cleanup")
  }
  { napi_version: version, builder, targets, features, cjs, esm, classes, }
}

///|
fn boolean(
  items : Map[String, Json],
  key : String,
  fallback : Bool,
) -> Bool raise {
  match items.get(key) {
    None => fallback
    Some(True) => true
    Some(False) => false
    _ => fail("\{key} must be a boolean")
  }
}

///|
async fn config(dir : String) -> Config {
  parse_config(Json(read_object(dir + "/napi-mbt.json")))
}
