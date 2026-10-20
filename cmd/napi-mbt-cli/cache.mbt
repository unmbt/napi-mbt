///|
type BuildLock

///|
#borrow(path, status)
extern "c" fn lock_file_raw(path : Bytes, status : Ref[Int32]) -> BuildLock = "napi_mbt_lock_file"

///|
#borrow(lock)
extern "c" fn BuildLock::close(lock : BuildLock) -> Unit = "napi_mbt_unlock_file"

///|
async fn project_lock(dir : String) -> BuildLock {
  let storage = dir + "/.napi-mbt"
  if @fs.exists(storage) && @fs.kind(storage, follow_symlink=false) != Directory {
    fail("Project .napi-mbt must be a real directory")
  }
  mkdirp(storage)
  if @fs.exists(storage + "/cache") &&
    @fs.kind(storage + "/cache", follow_symlink=false) != Directory {
    fail("Project cache must be a real directory")
  }
  let path = storage + "/cache.lock"
  if @fs.exists(path) && @fs.kind(path, follow_symlink=false) != Regular {
    fail("Build lock must be a regular file")
  }
  let status = Ref(0)
  let lock = lock_file_raw(@utf8.encode(path), status)
  if status.val != 0 {
    fail("Cannot lock build cache: OS status \{status.val}")
  }
  lock
}

///|
fn content_digest(bytes : Bytes) -> String {
  let mut value = 14695981039346656037UL
  for byte in bytes {
    value = (value ^ byte.to_uint64()) * 1099511628211UL
  }
  "\{bytes.length()}:" + value.to_string(radix=16)
}

///|
fn stable_json(value : Json) -> String {
  match value {
    Object(fields) => {
      let keys = fields.keys().to_array()
      keys.sort_by(lexical_compare)
      "{" +
      keys
      .map(key => Json(key).stringify() + ":" + stable_json(fields[key]))
      .join(",") +
      "}"
    }
    Array(values) => "[" + values.map(stable_json).join(",") + "]"
    _ => value.stringify()
  }
}

///|
let generated_input_files : Array[String] = [
  "napi_exports.mbt", "napi_glue.c", "napi_manifest.json", "napi-mbt.schema.json",
  "index.cjs", "index.mjs", "index.d.ts", "index.d.cts", "index.d.mts",
]

///|
async fn input_snapshot(dir : String, excluded : Array[String]) -> Json {
  let files : Map[String, Json] = Map([])
  async fn walk(
    path : String,
    relative : String,
    ancestors : Array[String],
  ) -> Unit {
    let canonical = @fs.realpath(path)
    if excluded.contains(canonical) {
      return
    }
    if ancestors.contains(canonical) {
      fail("Cyclic build input: " + path)
    }
    let parents = ancestors.copy()
    parents.push(canonical)
    for name in @fs.readdir(path, sort=true) {
      if [
          ".git", ".codegraph", ".napi-mbt", ".moonagent", "_build", "target", "node_modules",
          "artifacts", "dist", "npm", "licenses",
        ].contains(name) {
        continue
      }
      let key = relative + name
      if generated_input_files.contains(key) ||
        name.has_suffix(".mbti") ||
        name.has_suffix(".node") {
        continue
      }
      let full = path + "/" + name
      if @fs.kind(full) == Directory {
        walk(full, key + "/", parents)
      } else if key == "package.json" {
        let pkg = read_object(full)
        files[key] = Json(
          stable_json(
            Json([
              pkg.get("name").unwrap_or(Json::null()),
              pkg.get("version").unwrap_or(Json::null()),
            ]),
          ),
        )
      } else {
        files[key] = Json(content_digest(@fs.read_file(full).binary()))
      }
    }
  }
  walk(dir, "", [])
  Json(files)
}

///|
// Always construct the final overlay in a fresh staging directory. Synchronize
// only final bytes, so generation and async patching never churn cache mtimes.
async fn sync_cache_tree(
  source : String,
  destination : String,
  metadata : String,
) -> Unit {
  let previous = if @fs.exists(metadata) {
    try {
      let value = read_object(metadata, required=true)
      for key, digest in value {
        if key.is_empty() ||
          key.has_prefix("/") ||
          key.contains("\\") ||
          key.contains(":") ||
          key.has_prefix("_build/") ||
          key.split("/").any(p => p == ".." || p == ".") ||
          !(digest is String(_)) {
          fail("Invalid cache metadata")
        }
      }
      value
    } catch {
      _ => {
        if @fs.exists(destination) {
          @fs.rmdir(destination, recursive=true)
        }
        Map([])
      }
    }
  } else {
    if @fs.exists(destination) {
      @fs.rmdir(destination, recursive=true)
    }
    Map([])
  }
  let current : Map[String, Json] = Map([])
  let invalidate_native = Ref(false)
  // Remove vanished inputs before copying, including a file replaced by a
  // directory. Only paths from validated cache metadata can be removed.
  for key, _ in previous {
    if !@fs.exists(source + "/" + key) ||
      @fs.kind(source + "/" + key) == Directory {
      let obsolete = destination + "/" + key
      if @fs.exists(obsolete) {
        @fs.remove(obsolete)
      }
      if key.has_suffix(".h") || key.has_suffix(".hpp") {
        invalidate_native.val = true
      }
    }
  }
  async fn sync(relative : String) -> Unit {
    if @fs.exists(destination + "/" + relative) &&
      @fs.kind(destination + "/" + relative, follow_symlink=false) != Directory {
      fail("Unexpected directory link in build cache")
    }
    mkdirp(destination + "/" + relative)
    for name in @fs.readdir(source + "/" + relative, sort=true) {
      let key = relative + name
      let src = source + "/" + key
      let dst = destination + "/" + key
      if @fs.kind(src) == Directory {
        sync(key + "/")
      } else {
        let bytes = @fs.read_file(src).binary()
        current[key] = Json(content_digest(bytes))
        if @fs.exists(dst) && @fs.kind(dst, follow_symlink=false) == Directory {
          @fs.rmdir(dst, recursive=true)
        }
        if @fs.exists(dst) && @fs.kind(dst, follow_symlink=false) != Regular {
          fail("Unexpected non-file in build cache: " + key)
        }
        if previous.get(key) != Some(current[key]) &&
          (key.has_suffix(".h") || key.has_suffix(".hpp")) {
          invalidate_native.val = true
        }
        if !@fs.exists(dst) || @fs.read_file(dst).binary() != bytes {
          write_file(dst, bytes)
        }
        if !windows() && @fs.can_execute(src) {
          @fs.chmod(dst, 0o755)
        }
      }
    }
  }
  sync("")
  if invalidate_native.val && @fs.exists(destination + "/_build") {
    @fs.rmdir(destination + "/_build", recursive=true)
  }
  for key, _ in previous {
    if !current.contains(key) && @fs.exists(destination + "/" + key) {
      @fs.remove(destination + "/" + key)
    }
  }
  write_json(metadata, Json(current))
}

///|
async fn cache_identity(
  dir : String,
  toolchain : NativeToolchain,
  target : String,
  mode : String,
) -> Json {
  {
    "schema": 1,
    "target": Json(target),
    "mode": Json(mode),
    "toolchain": toolchain.report,
    "config": read_object(dir + "/napi-mbt.json"),
    "runtime": Json(@assets.runtime_version()),
    "hostInputs": toolchain_signature(
      dir,
      config(dir).builder,
      toolchain.report,
    ),
    "adapter": Json(
      content_digest(@utf8.encode(@assets.files()["async/manifest.json"])),
    ),
  }
}

///|
async fn cache_fallback(dir : String) -> String? {
  for name in ["dev_build.mbt", "dev-build.mbt"] {
    if @fs.exists(dir + "/" + name) {
      return Some(
        "custom build hook " + name + " may read inputs outside the project",
      )
    }
  }
  let pkg = read_text(dir + "/moon.pkg")
  if pkg.contains("${") ||
    pkg.contains("../") ||
    pkg.contains("pre-build") ||
    pkg.contains("pre_build") {
    return Some(
      "custom build variables, hooks or parent-directory inputs cannot be tracked reliably",
    )
  }
  // Relative project includes and standard system libraries use the tracked
  // source tree/toolchain. Explicit external include/library paths are opaque.
  if pkg.contains("-I/") ||
    pkg.contains("-L/") ||
    pkg.contains(":/") ||
    pkg.contains(":\\") {
    return Some("external native include/library path")
  }
  async fn dependencies(path : String, ancestors : Array[String]) -> String? {
    let canonical = @fs.realpath(path)
    if ancestors.contains(canonical) {
      fail("Cyclic build input: " + path)
    }
    let parents = ancestors.copy()
    parents.push(canonical)
    for name in @fs.readdir(path) {
      if [
          ".git", ".codegraph", ".napi-mbt", ".moonagent", "_build", "target", "node_modules",
          "artifacts", "dist", "npm",
        ].contains(name) {
        continue
      }
      let child = path + "/" + name
      if @fs.kind(child) == Directory {
        if dependencies(child, parents) is Some(reason) {
          return Some(reason)
        }
      } else if name == "dev_build.mbt" || name == "dev-build.mbt" {
        return Some("custom dependency build hook: " + child)
      } else if name == "moon.pkg" {
        let text = read_text(child)
        if text.contains("${") ||
          text.contains("../") ||
          text.contains("pre-build") ||
          text.contains("pre_build") ||
          text.contains("-I/") ||
          text.contains("-L/") ||
          text.contains(":/") ||
          text.contains(":\\") {
          return Some("untracked dependency build inputs: " + child)
        }
      }
    }
    None
  }
  if dependencies(dir, []) is Some(reason) {
    return Some(reason)
  }
  None
}

///|
async fn clean_cache(directory : String) -> Unit {
  let dir = @fs.realpath(directory)
  let lock = project_lock(dir)
  defer lock.close()
  let path = dir + "/.napi-mbt/cache"
  if @fs.exists(path) {
    if @fs.kind(path, follow_symlink=false) != Directory {
      fail("Cache must be a real directory")
    }
    @fs.rmdir(path, recursive=true)
  }
  println("[napi-mbt] removed current project's build cache")
}
