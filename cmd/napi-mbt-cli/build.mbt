///|
async fn build(
  directory : String,
  release : Bool,
  dry_run : Bool,
  target_override : String?,
  output_directory~ : String? = None,
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
  let toolchain = detect_toolchain(dir, conf.builder)
  defer toolchain.close()
  timer.stage("toolchain")
  let workspace = @fs.tmpdir(prefix="napi-mbt-build-")
  defer @fs.rmdir(workspace, recursive=true)
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
  copy_build_workspace(dir, workspace, [], excluded~)
  let generated = generate(workspace, false)
  timer.stage("generate")
  let uses_async = conf.features.contains("async") ||
    generated.source.features.contains("async")
  if uses_async {
    patch_async_dependency(workspace)
  }
  mkdirp(workspace + "/.napi-mbt/include")
  for name, text in @assets.files() {
    if !name.has_prefix("template/") && !name.has_prefix("async/") {
      write_text_file(workspace + "/.napi-mbt/" + name, text)
    }
  }
  if uses_async {
    let definition = workspace + "/.napi-mbt/node_api.def"
    write_text_file(
      definition,
      read_text(definition) +
      "\nuv_handle_size\nuv_handle_get_data\nuv_handle_set_data\nuv_timer_init\nuv_timer_start\nuv_timer_stop\nuv_close\n",
    )
  }
  if windows() {
    guard toolchain.librarian is Some(lib) else {
      fail("MSVC lib.exe is required")
    }
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
  }
  prepare_package(workspace, generated)
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
    let driver = prepare_posix_compiler(workspace, compiler)
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
  if package_before != package_after {
    fail(
      "package.json changed during build; retry to preserve the new configuration",
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
