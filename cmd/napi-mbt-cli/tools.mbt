///|
fn lexical_compare(a : String, b : String) -> Int {
  let length = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<length {
    let difference = a[i].to_int() - b[i].to_int()
    if difference != 0 {
      return difference
    }
  }
  a.length() - b.length()
}

///|
async fn mkdirp(path : String, recursive? : Bool = true) -> Unit {
  if @fs.exists(path) {
    if @fs.kind(path) != Directory {
      fail("Not a directory: \{path}")
    }
  } else {
    @fs.mkdir(path, recursive~)
  }
}

///|
async fn write_file(path : String, data : &@io.Data) -> Unit {
  @fs.write_file(path, data, create_mode=CreateOrTruncate)
}

///|
// Text emitted by the CLI always goes through the UTF-8 encoder explicitly.
// This keeps project files portable across Windows code pages and prevents a
// native build from later failing while MoonBit decodes a generated source.
async fn write_text_file(path : String, text : String) -> Unit {
  @fs.write_file(path, @utf8.encode(text), create_mode=CreateOrTruncate)
}

///|
// Native Windows tools may write diagnostics in the active code page instead
// of UTF-8. Their output is informational, so invalid byte sequences must not
// abort the build while being decoded.
fn command_output(data : &@io.Data) -> String {
  @utf8.decode_lossy(data.binary())
}

///|
// Keep malformed source files from surfacing as the unhelpful
// `Malformed.Malformed` exception from the UTF-8 decoder.  Project source is
// required to be UTF-8 because the generator parses it as MoonBit text.
async fn read_text(path : String) -> String {
  @fs.read_file(path).text() catch {
    _ => fail("File is not valid UTF-8: \{path}")
  }
}

///|
async fn command(
  program : String,
  args : Array[String],
  dir : String,
  env? : Map[String, String],
) -> String {
  let (code, out, err) = @process.collect_output(
    program,
    args,
    cwd=dir,
    extra_env=env.unwrap_or(Map([])),
  )
  if code != 0 {
    fail(
      "\{program} exited with status \{code}:\n\{command_output(out)}\{command_output(err)}",
    )
  }
  command_output(out) + command_output(err)
}

///|
async fn find_command(name : String) -> String? {
  let suffixes = if windows() { [".exe", ""] } else { [""] }
  for
    dir in @env.get_env_var("PATH")
    .unwrap_or("")
    .split(if windows() { ";" } else { ":" }) {
    for suffix in suffixes {
      let path = dir.to_owned() + "/" + name + suffix
      if @fs.exists(path) && @fs.can_execute(path) {
        return Some(@fs.realpath(path))
      }
    }
  }
  None
}

///|
async fn require_command(name : String) -> String {
  guard find_command(name) is Some(path) else {
    fail("Required tool not found on PATH: \{name}")
  }
  path
}

///|
fn cmake_quote(value : String) -> String {
  "\"" +
  value
  .replace_all(old="\\", new="/")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="$", new="\\$")
  .replace_all(old=";", new="\\;") +
  "\""
}

///|
fn visual_studio_generator(
  version : String,
  capabilities : Json,
) -> String raise {
  let major = version.split(".").to_array()[0]
  guard capabilities is { "generators": Array(items), .. } else {
    fail("Invalid CMake capabilities")
  }
  for item in items {
    if item is { "name": String(name), .. } &&
      name.has_prefix("Visual Studio \{major} ") {
      return name
    }
  }
  fail("CMake has no generator for Visual Studio \{major}; update CMake")
}

///|
async fn visual_studio(dir : String) -> (String, String) {
  let pf = @env.get_env_var("ProgramFiles(x86)").unwrap_or(
    "C:/Program Files (x86)",
  )
  let data = command(
    pf + "/Microsoft Visual Studio/Installer/vswhere.exe",
    [
      "-latest", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
      "-format", "json", "-utf8",
    ],
    dir,
  )
  guard @json.parse(data)
    is [
      {
        "installationPath": String(path),
        "installationVersion": String(version),
        ..
      },
      ..,
    ] else {
    fail("Visual Studio C++ build tools are required")
  }
  (path, version)
}
