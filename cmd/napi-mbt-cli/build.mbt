///|
async fn build(
  directory : String,
  release : Bool,
  dry_run : Bool,
  target_override : String?,
) -> Unit {
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
  let generated = generate(dir, false)
  let uses_async = conf.features.contains("async") ||
    generated.source.features.contains("async")
  let workspace = @fs.tmpdir(prefix="napi-mbt-build-")
  defer @fs.rmdir(workspace, recursive=true)
  copy_build_workspace(dir, workspace, [])
  if uses_async {
    patch_async_dependency(workspace)
  }
  mkdirp(workspace + "/.napi-mbt/include")
  for name, text in @assets.files() {
    if !name.has_prefix("template/") && !name.has_prefix("async/") {
      write_file(workspace + "/.napi-mbt/" + name, text)
    }
  }
  if uses_async {
    let definition = workspace + "/.napi-mbt/node_api.def"
    write_file(
      definition,
      @fs.read_file(definition).text() +
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
  let env : Map[String, String] = {
    "MOONBIT_NEW_NATIVE": "0",
    "MOONBIT_ALLOCATOR": "system",
  }
  if conf.builder == "clang" || conf.builder == "gcc" {
    guard toolchain.report
      is { "compiler": { "path": String(compiler), .. }, .. } else {
      fail("Missing compiler diagnostic")
    }
    env["MOON_CC"] = compiler
  }
  // Moon owns the package dependency graph and the complete linker invocation:
  // this includes every reachable stub archive, native dependency and user flag.
  println(
    command(
      toolchain.moon,
      ["build", "--target", "native", "--" + mode, "."],
      workspace,
      env~,
    ),
  )
  let artifacts = workspace + "/_build/native/" + mode + "/build"
  let binaries = @fs.readdir(artifacts, sort=true).filter(file => {
    file.has_suffix(".exe")
  })
  if binaries.length() != 1 {
    fail("Expected one MoonBit foreign-library artifact in \{artifacts}")
  }
  let output = dir + "/artifacts/" + target
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
  @fs.rename(pending, output + "/napi_mbt.node", replace=true)
  println("[napi-mbt] built \{output}/napi_mbt.node")
}
