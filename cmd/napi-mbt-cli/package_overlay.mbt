///|
struct PackageToken {
  value : String
  start : Int32
  end : Int32
  quoted : Bool
}

///|
// Preserve comments and all unrelated fields; quoted strings are opaque.
fn package_tokens(text : String) -> Array[PackageToken] raise {
  let tokens = []
  let mut i = 0
  while i < text.length() {
    let start = i
    let c = text[i]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      i += 1
      continue
    }
    if c == '/' && i + 1 < text.length() && text[i + 1] == '/' {
      while i < text.length() && text[i] != '\n' {
        i += 1
      }
      continue
    }
    if c == '/' && i + 1 < text.length() && text[i + 1] == '*' {
      i += 2
      while i + 1 < text.length() && !(text[i] == '*' && text[i + 1] == '/') {
        i += 1
      }
      if i + 1 >= text.length() {
        fail("Unterminated comment in moon.pkg")
      }
      i += 2
      continue
    }
    if c == '"' {
      i += 1
      while i < text.length() && text[i] != '"' {
        if text[i] == '\\' {
          i += 1
        }
        i += 1
      }
      if i >= text.length() {
        fail("Unterminated string in moon.pkg")
      }
      i += 1
      guard @json.parse(text[start:i].to_owned()) is String(value) else {
        fail("Invalid package string")
      }
      tokens.push({ value, start, end: i, quoted: true, })
    } else if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' {
      i += 1
      while i < text.length() &&
            (
              (text[i] >= 'a' && text[i] <= 'z') ||
              (text[i] >= 'A' && text[i] <= 'Z') ||
              (text[i] >= '0' && text[i] <= '9') ||
              text[i] == '_'
            ) {
        i += 1
      }
      tokens.push({
        value: text[start:i].to_owned(),
        start,
        end: i,
        quoted: false,
      })
    } else {
      i += 1
      tokens.push({
        value: text[start:i].to_owned(),
        start,
        end: i,
        quoted: false,
      })
    }
  }
  tokens
}

///|
fn package_close(tokens : Array[PackageToken], open : Int32) -> Int32 raise {
  let mut depth = 0
  for i in open..<tokens.length() {
    if tokens[i].quoted {
      continue
    }
    match tokens[i].value {
      "(" | "[" | "{" => depth += 1
      ")" | "]" | "}" => {
        depth -= 1
        if depth == 0 {
          return i
        }
      }
      _ => ()
    }
  }
  fail("Unbalanced moon.pkg configuration")
}

///|
fn package_call(tokens : Array[PackageToken], name : String) -> Int32? raise {
  let mut i = 0
  while i + 1 < tokens.length() {
    if !tokens[i].quoted &&
      tokens[i].value == name &&
      tokens[i + 1].value == "(" {
      return Some(i + 1)
    }
    if !tokens[i].quoted && ["(", "[", "{"].contains(tokens[i].value) {
      i = package_close(tokens, i) + 1
    } else {
      i += 1
    }
  }
  None
}

///|
fn package_field(
  tokens : Array[PackageToken],
  open : Int32,
  key : String,
) -> (Int32, Int32)? raise {
  let close = package_close(tokens, open)
  let mut i = open + 1
  let mut found = None
  while i < close {
    if i + 2 < close && tokens[i].value == key && tokens[i + 1].value == ":" {
      if found is Some(_) {
        fail("Duplicate moon.pkg field: \{key}")
      }
      let start = i + 2
      let end = if !tokens[start].quoted &&
        ["(", "[", "{"].contains(tokens[start].value) {
        package_close(tokens, start)
      } else {
        start
      }
      found = Some((start, end))
      i = end + 1
    } else if !tokens[i].quoted && ["(", "[", "{"].contains(tokens[i].value) {
      i = package_close(tokens, i) + 1
    } else {
      i += 1
    }
  }
  found
}

///|
fn package_set(
  text : String,
  open : Int32,
  key : String,
  value : String,
) -> String raise {
  let tokens = package_tokens(text)
  if package_field(tokens, open, key) is Some((start, end)) {
    text[:tokens[start].start].to_owned() +
    value +
    text[tokens[end].end:].to_owned()
  } else {
    let insert = tokens[open].end
    text[:insert].to_owned() +
    "\n\"\{key}\": \{value}," +
    text[insert:].to_owned()
  }
}

///|
fn native_block(text : String) -> Int32 raise {
  let tokens = package_tokens(text)
  if package_call(tokens, "link") is Some(open) {
    if package_call(tokens, "options") is Some(options) &&
      package_field(tokens, options, "link") is Some(_) {
      fail("Conflicting link and options(link:) configuration")
    }
    if tokens[open + 1].value == "native" && tokens[open + 2].value == "(" {
      return open + 2
    }
    fail("Expected link(native(...)) in moon.pkg")
  }
  guard package_call(tokens, "options") is Some(options) &&
    package_field(tokens, options, "link") is Some((link, _)) &&
    package_field(tokens, link, "native") is Some((native, _)) else {
    fail("Missing native link configuration")
  }
  native
}

///|
fn package_value(text : String, open : Int32, key : String) -> String? raise {
  let tokens = package_tokens(text)
  package_field(tokens, open, key).map(pair => {
    text[tokens[pair.0].start:tokens[pair.1].end].to_owned()
  })
}

///|
fn package_strings(text : String?) -> Array[String] raise {
  guard text is Some(text) else { return [] }
  let tokens = package_tokens(text)
  if tokens.length() < 2 ||
    tokens[0].value != "[" ||
    tokens[tokens.length() - 1].value != "]" {
    fail("Expected string array in moon.pkg")
  }
  let values = []
  for token in tokens[1:tokens.length() - 1] {
    if !token.quoted && token.value == "," {
      continue
    }
    if text[token.start] != '"' {
      fail("Expected string array in moon.pkg")
    }
    values.push(token.value)
  }
  values
}

///|
fn append_native_flag(
  text : String,
  key : String,
  extra : String,
) -> String raise {
  let open = native_block(text)
  let existing = match package_value(text, open, key) {
    None => ""
    Some(raw) => {
      guard @json.parse(raw) is String(value) else {
        fail("\{key} must be a string")
      }
      value
    }
  }
  package_set(
    text,
    open,
    key,
    Json((existing + " " + extra).trim().to_owned()).stringify(),
  )
}

///|
// Since MoonBit 0.10.17 the native backend lowers a foreign-library package to
// a static archive and no longer links it with the package's native link flags.
// Building the isolated workspace as an executable keeps the linker flags,
// configured exports and generated registration code intact, so the shared
// link flags produce the loadable addon that the CLI validates and publishes.
// Executable initialization leaves `moonbit_runtime_init` to `main`, which a
// loaded addon never runs; the generated lifecycle calls it explicitly.
fn foreign_library_executable_overlay(text : String) -> String raise {
  let tokens = package_tokens(text)
  guard package_call(tokens, "pkgtype") is Some(open) else {
    fail("Missing pkgtype configuration")
  }
  guard package_value(text, open, "kind") == Some("\"foreign_library\"") else {
    fail("Expected foreign-library package before executable fallback")
  }
  package_set(text, open, "kind", "\"executable\"")
}

///|
// Moonc rejects `#export_name` attributes outside `foreign_library` packages,
// while the isolated executable build exports adapters through `moon.pkg`
// `link.native.exports`. Blank `#export_name(...)` attributes in the isolated
// workspace without changing line numbers, comments or string literals.
fn strip_export_name_attributes(text : String) -> String {
  let out = StringBuilder()
  let n = text.length()
  let mut last = 0
  let mut i = 0
  while i < n {
    let c = text[i]
    if (c == '/' && i + 1 < n && text[i + 1] == '/') ||
      ((c == '#' || c == '$') && i + 1 < n && text[i + 1] == '|') {
      while i < n && text[i] != '\n' {
        i += 1
      }
      continue
    }
    if c == '"' || c == '\'' {
      let quote = c
      i += 1
      while i < n && text[i] != quote && text[i] != '\n' {
        if text[i] == '\\' && i + 1 < n {
          i += 1
        }
        i += 1
      }
      if i < n {
        i += 1
      }
      continue
    }
    if c == '#' &&
      i + 12 <= n &&
      text[i:i + 12] == "#export_name" &&
      (
        i + 12 == n ||
        !((text[i + 12] >= 'a' && text[i + 12] <= 'z') ||
        (text[i + 12] >= 'A' && text[i + 12] <= 'Z') ||
        (text[i + 12] >= '0' && text[i + 12] <= '9') ||
        text[i + 12] == '_')
      ) {
      let start = i
      let mut j = i + 12
      while j < n &&
            (
              text[j] == ' ' ||
              text[j] == '\t' ||
              text[j] == '\r' ||
              text[j] == '\n'
            ) {
        j += 1
      }
      if j < n && text[j] == '(' {
        let mut depth = 1
        j += 1
        while j < n && depth > 0 {
          let ch = text[j]
          if ch == '"' || ch == '\'' {
            let quote = ch
            j += 1
            while j < n && text[j] != quote && text[j] != '\n' {
              if text[j] == '\\' && j + 1 < n {
                j += 1
              }
              j += 1
            }
          } else if ch == '(' {
            depth += 1
          } else if ch == ')' {
            depth -= 1
          }
          j += 1
        }
        if depth == 0 {
          out.write_string(text[last:start].to_owned())
          for k in start..<j {
            if text[k] == '\n' {
              out.write_string("\n")
            } else if text[k] == '\r' {
              out.write_string("\r")
            } else {
              out.write_string(" ")
            }
          }
          last = j
          i = j
          continue
        }
      }
    }
    i += 1
  }
  if last == 0 {
    return text
  }
  out.write_string(text[last:n].to_owned())
  out.to_string()
}

///|
fn dependency_pic_overlay(text : String) -> String raise {
  let tokens = package_tokens(text)
  guard package_call(tokens, "options") is Some(options) &&
    package_field(tokens, options, "native-stub") is Some(_) else {
    return text
  }
  let mut text = text
  if package_call(tokens, "link") is None {
    match package_field(tokens, options, "link") {
      None => text = package_set(text, options, "link", "{\"native\": {}}")
      Some((link, _)) =>
        if package_field(tokens, link, "native") is None {
          text = package_set(text, link, "native", "{}")
        }
    }
  }
  if package_value(text, native_block(text), "stub-cc-flags") is Some(raw) {
    guard @json.parse(raw) is String(flags) else {
      fail("stub-cc-flags must be a string")
    }
    if flags
      .split(" ")
      .any(flag => ["-fno-pic", "-fno-PIC"].contains(flag.to_owned())) {
      fail(
        "Native dependency disables position-independent code required by an addon",
      )
    }
  }
  append_native_flag(text, "stub-cc-flags", "-fPIC")
}

///|
fn build_package_overlay(
  text : String,
  exports : Array[String],
  napi_version : Int32,
  is_windows : Bool,
) -> String raise {
  let mut text = text
  let tokens = package_tokens(text)
  if package_call(tokens, "pkgtype") is Some(open) {
    if package_value(text, open, "kind") != Some("\"foreign_library\"") {
      fail("Addon package must have pkgtype(kind: \"foreign_library\")")
    }
  } else {
    text += "\npkgtype(kind: \"foreign_library\")\n"
  }
  if package_call(package_tokens(text), "options") is None {
    text += "\noptions()\n"
  }
  let tokens = package_tokens(text)
  let options = package_call(tokens, "options").unwrap()
  if package_call(tokens, "link") is None {
    match package_field(tokens, options, "link") {
      None => text = package_set(text, options, "link", "{\"native\": {}}")
      Some((link, _)) =>
        if package_field(tokens, link, "native") is None {
          text = package_set(text, link, "native", "{}")
        }
    }
  }
  let options = package_call(package_tokens(text), "options").unwrap()
  let stubs = package_strings(package_value(text, options, "native-stub"))
  for name in ["stub.c", "napi_glue.c"] {
    if !stubs.contains(name) {
      stubs.push(name)
    }
  }
  text = package_set(text, options, "native-stub", Json(stubs).stringify())
  let open = native_block(text)
  let user_exports = package_strings(package_value(text, open, "exports"))
  for name in exports {
    if !user_exports.contains(name) {
      user_exports.push(name)
    }
  }
  text = package_set(text, open, "exports", Json(user_exports).stringify())
  for key in ["cc-flags", "stub-cc-flags"] {
    if package_value(text, native_block(text), key) is Some(raw) {
      guard @json.parse(raw) is String(flags) else {
        fail("\{key} must be a string")
      }
      for token in flags.split(" ") {
        if !is_windows && ["-fno-pic", "-fno-PIC"].contains(token.to_owned()) {
          fail("\{key} disables position-independent code required by an addon")
        }
        if token.contains("NAPI_VERSION=") &&
          !token.has_suffix("NAPI_VERSION=\{napi_version}") {
          fail("\{key} conflicts with napiVersion \{napi_version}: \{token}")
        }
      }
    }
  }
  text = append_native_flag(
    text,
    "cc-flags",
    if is_windows {
      "/utf-8"
    } else {
      "-fPIC"
    },
  )
  text = append_native_flag(
    text,
    "stub-cc-flags",
    (if is_windows { "/utf-8" } else { "-fPIC" }) +
    " -I./.napi-mbt/include -DNAPI_VERSION=\{napi_version}",
  )
  text = append_native_flag(
    text,
    "cc-link-flags",
    if is_windows {
      "/DLL \"./.napi-mbt/napi.lib\""
    } else {
      "-shared -fPIC"
    },
  )
  text
}
