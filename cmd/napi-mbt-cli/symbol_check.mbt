///|
// Explicit native-link exports become ELF/Mach-O dynamic symbols. A libc name
// in that set participates in the platform's symbol lookup/interposition rules,
// so reject it before invoking MoonBit's native compiler. JavaScript export
// names are checked only after generation, where they have adapter prefixes.
fn parse_unix_symbols(output : String, darwin~ : Bool = false) -> Array[String] {
  let symbols = []
  for line in output.split("\n") {
    let fields = line
      .trim()
      .split(" ")
      .filter(field => !field.is_empty())
      .map(field => field.to_owned())
      .to_array()
    if fields.length() < 2 {
      continue
    }
    let kind = if fields.length() >= 3 {
      fields[fields.length() - 2]
    } else {
      fields[0]
    }
    if kind == "U" || kind == "u" {
      continue
    }
    let raw = fields[fields.length() - 1]
    let mut name = raw.split("@").to_array()[0].to_owned()
    if darwin && name.has_prefix("_") {
      name = name[1:].to_owned()
    }
    if !name.is_empty() && !symbols.contains(name) {
      symbols.push(name)
    }
  }
  symbols
}

///|
fn unix_symbol_collisions(
  exports : Array[String],
  libc_symbols : Array[String],
) -> Array[String] {
  exports.filter(name => libc_symbols.contains(name))
}

///|
async fn unix_libc_symbols(compiler : String, dir : String) -> Array[String] {
  let nm = require_command("nm")
  if host_target().has_prefix("darwin-") {
    let sdk = if @fs.exists("/usr/lib/libSystem.B.dylib") {
      ""
    } else {
      command(require_command("xcrun"), ["--show-sdk-path"], dir)
      .trim()
      .to_owned() +
      "/usr/lib"
    }
    let paths = [
      if sdk.is_empty() {
        "/usr/lib/libSystem.B.dylib"
      } else {
        sdk + "/libSystem.tbd"
      },
      if sdk.is_empty() {
        "/usr/lib/system/libsystem_kernel.dylib"
      } else {
        sdk + "/system/libsystem_kernel.tbd"
      },
      if sdk.is_empty() {
        "/usr/lib/system/libsystem_c.dylib"
      } else {
        sdk + "/system/libsystem_c.tbd"
      },
    ]
    let symbols = []
    for path in paths {
      if @fs.exists(path) {
        symbols.append(
          parse_unix_symbols(command(nm, ["-gU", path], dir), darwin=true),
        )
      }
    }
    if symbols.is_empty() {
      fail(
        "Unable to locate macOS system libraries for Unix export symbol validation",
      )
    }
    return symbols
  }
  for name in ["libc.so.6", "libc.so"] {
    let path = command(compiler, ["-print-file-name=" + name], dir)
      .trim()
      .to_owned()
    if path != name && @fs.exists(path) {
      return parse_unix_symbols(
        command(nm, ["-D", "--defined-only", path], dir),
      )
    }
  }
  fail("Unable to locate libc for Unix export symbol validation")
}

///|
async fn validate_unix_export_symbols(
  compiler : String,
  dir : String,
  exports : Array[String],
) -> Unit {
  let libc_symbols = unix_libc_symbols(compiler, dir)
  let collisions = unix_symbol_collisions(exports, libc_symbols)
  if !collisions.is_empty() {
    fail(
      "Unix libc symbol collision: " +
      collisions.join(", ") +
      ". Rename the exported function before building the addon",
    )
  }
}
