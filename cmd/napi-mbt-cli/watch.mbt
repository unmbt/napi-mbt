///|
fn watch_ignored(path : String, output : String) -> Bool {
  if path == output || path.has_prefix(output + "/") {
    return true
  }
  for part in path.split("/") {
    if ignored_build_directories.contains(part.to_owned()) {
      return true
    }
  }
  if generated_input_files.contains(path) {
    return true
  }
  path.has_suffix(".mbti") ||
  path.has_suffix(".node") ||
  path.has_suffix(".tmp")
}

///|
async fn watch_package_identity(dir : String) -> String {
  let pkg = read_object(dir + "/package.json")
  Json([
    pkg.get("name").unwrap_or(Json::null()),
    pkg.get("version").unwrap_or(Json::null()),
  ]).stringify()
}

///|
async fn watch_input_snapshot(dir : String, excluded : Array[String]) -> String {
  stable_json(input_snapshot(dir, excluded)) catch {
    error => "error:" + error.to_string()
  }
}

///|
async fn watch_build(
  dir : String,
  release : Bool,
  target : String?,
  output : String?,
  no_cache~ : Bool = false,
) -> Unit {
  let dir = @fs.realpath(dir).replace_all(old="\\", new="/")
  // Resolve the output before constructing the watcher, including '..' and links.
  let out_path = output_path(dir, output)
  mkdirp(out_path)
  let excluded = [@fs.realpath(out_path)]
  let out = excluded[0].replace_all(old="\\", new="/")
  if out == dir {
    fail("Watch output directory must not be the project root")
  }
  let relative_output = if out.has_prefix(dir + "/") {
    out[dir.length() + 1:].to_owned()
  } else {
    "artifacts"
  }
  let watcher = @fs.Watcher(
    dir,
    debounce_timeout=150,
    max_debounce_delay=1000,
    report_child_event=true,
    ignored_paths=path => watch_ignored(path, relative_output),
  )
  defer watcher.close()
  let mut identity = watch_package_identity(dir) catch { _ => "invalid" }
  let mut last_snapshot = ""
  let mut dirty = true
  while true {
    if dirty {
      eprintln("[napi-mbt] watch: building")
      while true {
        let snapshot_before = watch_input_snapshot(dir, excluded)
        let mut retry = false
        build(dir, release, false, target, output_directory=output, no_cache~) catch {
          error => {
            let message = error.to_string()
            if message.contains("Project inputs changed during build") ||
              watch_input_snapshot(dir, excluded) != snapshot_before {
              retry = true
            } else {
              eprintln(
                "[napi-mbt] watch: build failed; keeping last successful artifact\n" +
                message,
              )
            }
          }
        }
        if !retry {
          last_snapshot = watch_input_snapshot(dir, excluded)
          break
        }
      }
      eprintln("[napi-mbt] watch: waiting for changes")
      dirty = false
    }
    for event in watcher.wait() {
      let paths = match event {
        Modify(path) | Create(path) | Remove(path) => [path]
        Rename(old~, new~) => [old, new]
      }
      for path in paths {
        if path == "package.json" {
          // Entry points and file lists are generated; name/version are inputs.
          let next = watch_package_identity(dir) catch {
            error => error.to_string()
          }
          if next != identity {
            identity = next
            dirty = true
          }
        } else if !watch_ignored(path, relative_output) {
          dirty = true
        }
      }
    }
    if dirty && watch_input_snapshot(dir, excluded) == last_snapshot {
      dirty = false
    }
  }
}
