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
    Some(@fs.read_file(dir + "/package.json").binary())
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
  defer toolchain.close()
  timer.stage("toolchain")
  let staging = @fs.tmpdir(prefix="napi-mbt-build-")
  defer @fs.rmdir(staging, recursive=true)
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
    patch_async_dependency(staging)
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
  if uses_async {
    let definition = staging + "/.napi-mbt/node_api.def"
    write_text_file(
      definition,
      read_text(definition) +
      "\nuv_handle_size\nuv_handle_get_data\nuv_handle_set_data\nuv_timer_init\nuv_timer_start\nuv_timer_stop\nuv_close\n",
    )
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
  let artifacts = workspace + "/_build/native/" + mode + "/build"
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
  write_file(pending, @fs.read_file(artifacts + "/" + binaries[0]))
  errdefer (if @fs.exists(pending) { @fs.remove(pending) })
  let package_after = if @fs.exists(dir + "/package.json") {
    Some(@fs.read_file(dir + "/package.json").binary())
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
    write_file(backup, @fs.read_file(destination))
  }
  errdefer (if had_binary {
    @fs.rename(backup, destination, replace=true)
  } else if @fs.exists(destination) {
    @fs.remove(destination)
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
    "binary": Json(content_digest(@fs.read_file(destination).binary())),
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
