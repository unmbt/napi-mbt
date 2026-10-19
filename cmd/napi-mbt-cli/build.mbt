///|
async fn build(
  directory : String,
  release : Bool,
  dry_run : Bool,
  target_override : String?,
  generator_override : String?,
) -> Unit {
  let dir = @fs.realpath(directory)
  let conf = config(dir, generator_override)
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
  let generated = generate(dir, false, generator_override)
  let workspace = @fs.tmpdir(prefix="napi-mbt-build-")
  defer @fs.rmdir(workspace, recursive=true)
  copy_build_workspace(dir, workspace, [])
  mkdirp(workspace + "/.napi-mbt/include")
  for name, text in @assets.files() {
    if !name.has_prefix("template/") {
      write_file(workspace + "/.napi-mbt/" + name, text)
    }
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
