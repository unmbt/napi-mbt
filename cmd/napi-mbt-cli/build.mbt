///|
fn moon_mod_name(text : String) -> String? raise {
  let tokens = package_tokens(text)
  for i, token in tokens {
    if !token.quoted &&
      token.value == "name" &&
      tokens.get(i + 1).map(t => t.value) == Some("=") {
      return tokens.get(i + 2).map(t => t.value)
    }
  }
  None
}

///|
fn moon_work_members(text : String) -> Array[String] raise {
  let tokens = package_tokens(text)
  let members = []
  for i, token in tokens {
    if !token.quoted &&
      token.value == "members" &&
      tokens.get(i + 1).map(t => t.value) == Some("=") &&
      tokens.get(i + 2).map(t => t.value) == Some("[") {
      let mut j = i + 3
      while j < tokens.length() && tokens[j].value != "]" {
        if tokens[j].quoted {
          members.push(tokens[j].value)
        }
        j += 1
      }
      break
    }
  }
  members
}

///|
async fn find_workspace_module(
  project_dir : String,
  target_name : String,
) -> String? {
  let mut cursor = project_dir.replace_all(old="\\", new="/")
  while true {
    let work_file = cursor + "/moon.work"
    if @fs.exists(work_file) {
      for m in moon_work_members(read_text(work_file)) {
        let candidate = if m == "." {
          cursor
        } else if m.has_prefix("/") || (m.length() >= 2 && m[1] == ':') {
          m
        } else {
          cursor + "/" + m
        }
        let mod_file = candidate + "/moon.mod"
        if @fs.exists(mod_file) &&
          moon_mod_name(read_text(mod_file)) == Some(target_name) &&
          @fs.exists(candidate + "/runtime/moon.pkg") {
          return Some(@fs.realpath(candidate))
        }
      }
    }
    match cursor.rev_find("/") {
      Some(slash) if slash > 0 => cursor = cursor[:slash].to_owned()
      _ => break
    }
  }
  None
}

///|
async fn stage_package_runtime(
  project_dir : String,
  staging : String,
  napi_version : Int32,
) -> Unit {
  let assets = @assets.files()
  for
    header in [
      "napi_callbacks.h", "napi_lifecycle.h", "napi_owned_binary.h", "napi_native_task.h",
      "napi_native_task_runtime.h", "napi_worker_lifecycle.h",
    ] {
    if assets.get("template/" + header) is Some(text) {
      write_text_file(staging + "/.napi-mbt/include/" + header, text)
    }
  }
  let mooncake_runtime = staging + "/.mooncakes/unmbt/napi-mbt/runtime"
  let runtime_dir = if @fs.exists(mooncake_runtime + "/moon.pkg") {
    mooncake_runtime
  } else {
    guard find_workspace_module(project_dir, "unmbt/napi-mbt") is Some(mod_dir) else {
      fail(
        "Package runtime requires unmbt/napi-mbt; run `moon add unmbt/napi-mbt` or link via moon.work",
      )
    }
    let staged_mod = staging + "/.napi-mbt/deps/napi-mbt"
    mkdirp(staged_mod, recursive=true)
    write_text_file(
      staged_mod + "/moon.mod",
      "name = \"unmbt/napi-mbt\"\n\nversion = \"0.3.7\"\n\npreferred_target = \"native\"\n\nsupported_targets = \"native\"\n",
    )
    copy_build_workspace(mod_dir + "/runtime", staged_mod + "/runtime", [])
    write_text_file(
      staging + "/moon.work",
      "members = [\n  \".\",\n  \"./.napi-mbt/deps/napi-mbt\",\n]\n",
    )
    staged_mod + "/runtime"
  }
  mkdirp(runtime_dir + "/.napi-mbt/include")
  for name, text in assets {
    if name.has_prefix("include/") {
      write_text_file(runtime_dir + "/.napi-mbt/" + name, text)
    }
  }
  let runtime_pkg = runtime_dir + "/moon.pkg"
  write_text_file(
    runtime_pkg,
    runtime_package_overlay(read_text(runtime_pkg), napi_version, windows()),
  )
}

///|
async fn build(
  directory : String,
  release : Bool,
  dry_run : Bool,
  target_override : String?,
  output_directory~ : String? = None,
  no_cache~ : Bool = false,
) -> Unit {
  let timer = BuildTimer::new()
  let dir = @fs.realpath(directory)
  let conf = config(dir)
  let target = target_override.unwrap_or(host_target())
  if !conf.targets.is_empty() && !conf.targets.contains(target) {
    fail("Target \{target} is not listed in napi-mbt.json")
  }
  if target != host_target() {
    fail(
      "Cross-compiling \{target} requires a matching host toolchain; current host is \{host_target()}",
    )
  }
  validate_builder(conf.builder, windows())
  let mode = if release { "release" } else { "debug" }
  if dry_run {
    println(
      "[napi-mbt] dry-run: check toolchain; generate bindings; copy isolated workspace; moon build --target native --\{mode} .; publish addon",
    )
    return
  }
  let lock = project_lock(dir)
  defer lock.close()
  let conf = config(dir)
  if !conf.targets.is_empty() && !conf.targets.contains(target) {
    fail("Target is no longer listed in napi-mbt.json")
  }
  validate_builder(conf.builder, windows())
  let package_before = if @fs.exists(dir + "/package.json") {
    Some(@fs.read_binary(dir + "/package.json"))
  } else {
    None
  }
  let artifact_root = output_path(dir, output_directory)
  let excluded = if @fs.exists(artifact_root) {
    [@fs.realpath(artifact_root)]
  } else {
    []
  }
  if excluded.contains(dir) {
    fail("Output directory must not be the project root")
  }
  let inputs = input_snapshot(dir, excluded)
  let fallback = cache_fallback(dir)
  let cached = !no_cache && fallback is None
  if !no_cache && fallback is Some(reason) {
    eprintln("[napi-mbt] cache disabled: " + reason)
  }
  let toolchain = build_toolchain(dir, conf.builder, cached)
  defer @async.protect_from_cancel(() => toolchain.close())
  timer.stage("toolchain")
  let staging = @fs.tmpdir(prefix="napi-mbt-build-")
  defer @fs.remove(staging, recursive=true)
  let identity = cache_identity(dir, toolchain, target, mode)
  let partition = dir +
    "/.napi-mbt/cache/" +
    adapter_checksum(stable_json(identity))
  let workspace = if cached { partition + "/workspace" } else { staging }
  copy_build_workspace(dir, staging, [], excluded~)
  let generated = generate(staging, false)
  timer.stage("generate")
  let uses_async = conf.features.contains("async") ||
    generated.source.features.contains("async")
  if uses_async {
    patch_async_dependency(
      staging,
      is_package_runtime=conf.runtime == "package",
    )
  }
  if !conf.native_tasks.is_empty() {
    prepare_native_tasks(staging)
  }
  mkdirp(staging + "/.napi-mbt/include")
  for name, text in @assets.files() {
    if !name.has_prefix("template/") &&
      !name.has_prefix("async/") &&
      !name.has_prefix("workers/") {
      write_text_file(staging + "/.napi-mbt/" + name, text)
    }
  }
  if conf.runtime == "package" {
    stage_package_runtime(dir, staging, conf.napi_version)
  }
  if uses_async {
    let definition = staging + "/.napi-mbt/node_api.def"
    write_text_file(
      definition,
      read_text(definition) +
      "\nuv_handle_size\nuv_handle_get_data\nuv_handle_set_data\nuv_async_init\nuv_async_send\nuv_timer_init\nuv_timer_start\nuv_timer_stop\nuv_ref\nuv_unref\nuv_close\n",
    )
  }
  if !windows() {
    guard toolchain.report
      is { "compiler": { "path": String(compiler), .. }, .. } else {
      fail("Missing compiler diagnostic")
    }
    let package_text = read_text(staging + "/moon.pkg")
    let configured_exports = package_strings(
      package_value(package_text, native_block(package_text), "exports"),
    )
    // The ELF/Mach-O dynamic symbol table contains generated adapter names,
    // not the JavaScript property names. A JS export called `read` is backed by
    // `napi_mbt_adapter_read` and cannot interpose libc's `read`; only explicit
    // native-link exports and generated native symbols belong in this check.
    let native_exports = generated.source.native_exports()
    native_exports.append(configured_exports)
    validate_unix_export_symbols(compiler, dir, native_exports)
  }
  prepare_package(staging, generated)
  if !windows() {
    guard toolchain.report
      is { "compiler": { "path": String(compiler), .. }, .. } else {
      fail("Missing compiler diagnostic")
    }
    validate_package_compilers(staging, compiler)
    let path = staging + "/moon.pkg"
    let pkg = read_text(path)
    write_text_file(
      path,
      package_set(
        pkg,
        native_block(pkg),
        "cc",
        Json(workspace + "/.napi-mbt/cc").stringify(),
      ),
    )
  }
  if cached {
    for path in [dir + "/.napi-mbt/cache", partition, workspace] {
      if @fs.exists(path) && @fs.kind(path, follow_symlink=false) != Directory {
        fail("Build cache must contain real directories")
      }
    }
    mkdirp(partition)
    sync_cache_tree(staging, workspace, partition + "/inputs.json")
    println("[napi-mbt] cache workspace: " + workspace)
  }
  if windows() {
    guard toolchain.librarian is Some(lib) else {
      fail("MSVC lib.exe is required")
    }
    let definition = read_text(workspace + "/.napi-mbt/node_api.def")
    let stamp = workspace + "/.napi-mbt/napi.lib.source"
    if !@fs.exists(workspace + "/.napi-mbt/napi.lib") ||
      !@fs.exists(stamp) ||
      read_text(stamp) != definition {
      ignore(
        command(
          lib,
          [
            "/DEF:" + workspace + "/.napi-mbt/node_api.def",
            "/OUT:" + workspace + "/.napi-mbt/napi.lib",
            "/MACHINE:X64",
          ],
          workspace,
        ),
      )
      write_text_file(stamp, definition)
    }
  }
  timer.stage("prepare")
  let env : Map[String, String] = {
    "MOONBIT_NEW_NATIVE": "0",
    "MOONBIT_ALLOCATOR": "system",
  }
  if !windows() {
    guard toolchain.report
      is { "compiler": { "path": String(compiler), .. }, .. } else {
      fail("Missing compiler diagnostic")
    }
    let driver = prepare_posix_compiler(workspace, compiler, validated=true)
    // Moon's runtime compilation ignores package cc as well as package flags.
    env["MOON_CC"] = driver
  } else if conf.builder == "clang" {
    guard toolchain.report
      is { "compiler": { "path": String(compiler), .. }, .. } else {
      fail("Missing compiler diagnostic")
    }
    env["MOON_CC"] = compiler
  }
  // Moon owns the package dependency graph and the complete linker invocation:
  // this includes every reachable stub archive, native dependency and user flag.
  let build_output = command(
    toolchain.moon,
    ["build", "--target", "native", "--" + mode, "."],
    workspace,
    env~,
  )
  if verbose_commands.val {
    println(build_output)
  }
  timer.stage("compile-link")
  let artifacts = if @fs.exists(workspace + "/moon.work") {
    match moon_mod_name(read_text(workspace + "/moon.mod")) {
      Some(mod_name) =>
        workspace + "/_build/native/" + mode + "/build/" + mod_name
      None => workspace + "/_build/native/" + mode + "/build"
    }
  } else {
    workspace + "/_build/native/" + mode + "/build"
  }
  let binaries = @fs.readdir(artifacts, sort=true).filter(file => {
    file.has_suffix(".exe")
  })
  if binaries.length() != 1 {
    fail("Expected one MoonBit foreign-library artifact in \{artifacts}")
  }
  let output = output_path(dir, output_directory) + "/" + target
  mkdirp(output)
  let workspace_parts = workspace
    .replace_all(old="\\", new="/")
    .split("/")
    .to_array()
  let pending = output +
    "/." +
    workspace_parts[workspace_parts.length() - 1].to_owned() +
    ".node"
  let binary_data = @fs.read_binary(artifacts + "/" + binaries[0])
  validate_artifact(binary_data, target)
  if target.has_prefix("linux-") {
    ignore(validate_linux_libc(binary_data, target))
  }
  write_file(pending, binary_data)
  errdefer @async.protect_from_cancel(() => {
    if @fs.exists(pending) {
      @fs.remove(pending)
    }
  })
  let package_after = if @fs.exists(dir + "/package.json") {
    Some(@fs.read_binary(dir + "/package.json"))
  } else {
    None
  }
  if package_before != package_after ||
    input_snapshot(dir, excluded) != inputs ||
    cache_identity(dir, toolchain, target, mode) != identity {
    fail(
      "Project inputs changed during build; retry to preserve the previous artifacts",
    )
  }
  let destination = output + "/napi_mbt.node"
  let backup = pending + ".previous"
  let had_binary = @fs.exists(destination)
  if had_binary {
    write_file(backup, @fs.read_binary(destination))
  }
  errdefer @async.protect_from_cancel(() => {
    if had_binary {
      @fs.rename(backup, destination, replace=true)
    } else if @fs.exists(destination) {
      @fs.remove(destination)
    }
  })
  @fs.rename(pending, destination, replace=true)
  mkdirp(dir + "/.napi-mbt")
  let location_text = (
      { "directory": @fs.realpath(output_path(dir, output_directory)) } : Json).stringify(
      indent=2,
    ) +
    "\n"
  let outputs = generated.outputs.copy()
  let output_digests : Map[String, Json] = Map([])
  for (name, text) in generated.outputs {
    if name != "package.json" {
      output_digests[name] = Json(content_digest(@utf8.encode(text)))
    }
  }
  let receipt : Json = {
    "schema": 1,
    "target": Json(target),
    "mode": Json(mode),
    "inputs": inputs,
    "identity": identity,
    "outputs": Json(output_digests),
    "binary": Json(content_digest(@fs.read_binary(destination))),
  }
  outputs.push(
    (
      ".napi-mbt/receipt-" + target + ".json",
      receipt.stringify(indent=2) + "\n",
    ),
  )
  outputs.push((".napi-mbt/build-output.json", location_text))
  install_outputs(dir, outputs, false, removals=generated.removals)
  if had_binary {
    @fs.remove(backup) catch {
      error => eprintln("[napi-mbt] backup cleanup: " + error.to_string())
    }
  }
  timer.stage("publish-artifact")
  println("[napi-mbt] built \{output}/napi_mbt.node")
  if verbose_commands.val {
    eprintln("[napi-mbt] total: \{@env.now() - timer.start} ms")
  }
}
