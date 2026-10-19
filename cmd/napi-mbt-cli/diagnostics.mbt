///|
struct BuildTimer {
  start : UInt64
  mut previous : UInt64
}

///|
fn BuildTimer::new() -> BuildTimer {
  let now = @env.now()
  { start: now, previous: now, }
}

///|
fn BuildTimer::stage(self : BuildTimer, name : String) -> Unit {
  let now = @env.now()
  if verbose_commands.val {
    eprintln("[napi-mbt] stage \{name}: \{now - self.previous} ms")
  }
  self.previous = now
}

///|
fn output_path(dir : String, requested : String?) -> String {
  let path = requested.unwrap_or("artifacts").replace_all(old="\\", new="/")
  if path.has_prefix("/") || (path.length() > 1 && path[1] == ':') {
    path
  } else {
    dir + "/" + path
  }
}

///|
async fn local_artifact_root(dir : String) -> String {
  let path = dir + "/.napi-mbt/build-output.json"
  if !@fs.exists(path) {
    return dir + "/artifacts"
  }
  guard @json.parse(@fs.read_file(path).text())
    is { "directory": String(directory), .. } else {
    fail("Invalid local build output record: \{path}")
  }
  if !(directory.has_prefix("/") ||
    directory.has_prefix("\\") ||
    (directory.length() > 1 && directory[1] == ':')) {
    fail("Build output directory must be absolute: \{path}")
  }
  directory
}
