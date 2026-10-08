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
fn validate_generator(value : String) -> Unit raise {
  if value == "node" {
    fail("The Node generator was removed; use --generator=auto or moonbit")
  }
  if value != "auto" && value != "moonbit" {
    fail("Unknown generator: \{value}; expected auto or moonbit")
  }
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
async fn read_object(
  path : String,
  required? : Bool = false,
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
  napi_version : Int
  generator : String
  builder : String
  targets : Array[String]
  features : Array[String]
}

///|
fn feature_version(name : String) -> Int raise {
  match name {
    "promise" => 1
    "threadsafe_function" => 4
    "bigint" => 6
    _ => fail("Unknown N-API feature: \{name}")
  }
}

///|
async fn config(dir : String, override_generator : String?) -> Config {
  let items = read_object(dir + "/napi-mbt.json")
  let version = match items.get("napiVersion") {
    None => 1
    Some(Number(n, ..)) if n >= 1 &&
      n <= 2147483647.0 &&
      n == n.to_int().to_double() => n.to_int()
    _ => fail("napiVersion must be a positive integer")
  }
  let generator = override_generator.unwrap_or(str(items, "generator", "auto"))
  validate_generator(generator)
  let features = strings(items, "features")
  for feature in features {
    let required = feature_version(feature)
    if version < required {
      fail(
        "napiVersion \{version} is lower than required feature level \{required}",
      )
    }
  }
  {
    napi_version: version,
    generator,
    builder: str(items, "builder", "auto"),
    targets: strings(items, "targets"),
    features,
  }
}
