///|
// Find the end of a quoted option value or an array/object, respecting escapes.
fn option_end(text : String, start : Int) -> Int raise {
  let mut quoted = false
  let mut escaped = false
  let mut depth = 0
  for i in start..<text.length() {
    let c = text[i]
    if quoted {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = false
        if depth == 0 {
          return i + 1
        }
      }
    } else if c == '"' {
      quoted = true
    } else if c == '[' || c == '{' {
      depth += 1
    } else if c == ']' || c == '}' {
      depth -= 1
      if depth == 0 {
        return i + 1
      }
    }
  }
  fail("Invalid moon.pkg option value")
}

///|
fn replace_option(text : String, key : String, value : String) -> String raise {
  let marker = "\"" + key + "\""
  if text.find(marker) is Some(index) {
    let mut start = index + marker.length()
    while start < text.length() &&
          (
            text[start] == ':' ||
            text[start] == ' ' ||
            text[start] == '\r' ||
            text[start] == '\n'
          ) {
      start += 1
    }
    let end = option_end(text, start)
    text[:start].to_owned() + value + text[end:].to_owned()
  } else {
    guard text.find("\"native\"") is Some(index) else {
      fail("moon.pkg needs link: { \"native\": { ... } }")
    }
    guard text[index:].find("{") is Some(offset) else {
      fail("Invalid native link options")
    }
    let insert = index + offset + 1
    text[:insert].to_owned() +
    "\n    \"\{key}\": \{value}," +
    text[insert:].to_owned()
  }
}

///|
fn insert_package_option(text : String, field : String) -> String {
  if text.find("options(") is Some(index) {
    let start = index + "options(".length()
    text[:start].to_owned() + field + ",\n" + text[start:].to_owned()
  } else {
    text + "\noptions(" + field + ")\n"
  }
}

///|
async fn prepare_package(dir : String, generated : Generated) -> Unit {
  let path = dir + "/moon.pkg"
  let mut text = @fs.read_file(path).text()
  if !text.contains("pkgtype(kind: \"foreign_library\")") {
    text = "pkgtype(kind: \"foreign_library\")\n" + text
  }
  if !text.contains("\"native\"") {
    text = insert_package_option(text, "link: { \"native\": {} }")
  }
  if !text.contains("\"native-stub\"") {
    text = insert_package_option(
      text, "\"native-stub\": [\"stub.c\", \"napi_glue.c\"]",
    )
  } else if !text.contains("\"napi_glue.c\"") {
    let index = text.find("\"native-stub\"").unwrap()
    let start = index + text[index:].find("[").unwrap()
    text = text[:start + 1].to_owned() +
      "\"napi_glue.c\", " +
      text[start + 1:].to_owned()
  }
  let dynamic = text.contains("${build.NAPI_C_FLAGS}")
  let cflags = if dynamic {
    "${build.NAPI_C_FLAGS}"
  } else if windows() {
    "/utf-8"
  } else {
    "-fPIC"
  }
  let stubflags = cflags +
    " -I./.napi-mbt/include -DNAPI_VERSION=\{generated.config.napi_version}"
  let linkflags = if dynamic {
    "${build.NAPI_LINK_FLAGS}"
  } else if windows() {
    "/LD \"./.napi-mbt/napi.lib\""
  } else {
    "-c"
  }
  text = replace_option(text, "cc-flags", cflags.to_json().stringify())
  text = replace_option(text, "stub-cc-flags", stubflags.to_json().stringify())
  text = replace_option(text, "cc-link-flags", linkflags.to_json().stringify())
  let exports = ["moonbit_init"]
  for item in generated.exports {
    exports.push("napi_mbt_adapter_" + item.export_name)
  }
  text = replace_option(text, "exports", exports.to_json().stringify())
  write_file(path, text)
}
