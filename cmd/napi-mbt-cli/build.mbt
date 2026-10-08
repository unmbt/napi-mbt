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
  if !["auto", "cmake", "gcc", "clang", "msvc"].contains(conf.builder) {
    fail("Unknown builder: \{conf.builder}")
  }
  if windows() && conf.builder == "gcc" {
    fail(
      "Windows requires an MSVC-compatible toolchain; MinGW GCC cannot link MoonBit artifacts",
    )
  }
  if !windows() && conf.builder == "msvc" {
    fail("MSVC builds require Windows")
  }
  let mode = if release { "release" } else { "debug" }
  let configuration = if release { "Release" } else { "Debug" }
  if dry_run {
    println(
      "[napi-mbt] dry-run: generate bindings; moon build --target native --\{mode} .; cmake configure and build (\{configuration})",
    )
    return
  }
  let moon = require_command("moon")
  let cmake = require_command("cmake")
  let generator_args = []
  let mut vs_root = ""
  if windows() {
    let (root, version) = visual_studio(dir)
    vs_root = root
    let capabilities = @json.parse(command(cmake, ["-E", "capabilities"], dir))
    let generator = visual_studio_generator(version, capabilities)
    let toolset = if conf.builder == "clang" {
      "ClangCL,host=x64"
    } else {
      "host=x64"
    }
    generator_args.append([
      "-G",
      generator,
      "-A",
      "x64",
      "-DCMAKE_GENERATOR_INSTANCE=" + root,
      "-T",
      toolset,
    ])
  } else {
    if find_command("ninja") is Some(_) {
      generator_args.append(["-G", "Ninja"])
    }
    if conf.builder == "gcc" || conf.builder == "clang" {
      generator_args.push("-DCMAKE_C_COMPILER=" + require_command(conf.builder))
    }
    generator_args.push("-DCMAKE_BUILD_TYPE=" + configuration)
  }
  let generated = generate(dir, false, generator_override)
  let resources = @assets.files()
  mkdirp(dir + "/.napi-mbt/include", recursive=true)
  for name, text in resources {
    if !name.has_prefix("template/") {
      write_file(dir + "/.napi-mbt/" + name, text)
    }
  }
  if windows() {
    let tools_dir = vs_root + "/VC/Tools/MSVC"
    let versions = @fs.readdir(tools_dir, sort=true)
    versions.sort_by((a, b) => lexical_compare(b, a))
    let mut librarian : String? = None
    for version in versions {
      let path = tools_dir + "/" + version + "/bin/Hostx64/x64/lib.exe"
      if @fs.exists(path) {
        librarian = Some(path)
        break
      }
    }
    guard librarian is Some(lib) else { fail("MSVC lib.exe is required") }
    println(
      command(
        lib,
        [
          "/DEF:" + dir + "/.napi-mbt/node_api.def",
          "/OUT:" + dir + "/.napi-mbt/napi.lib",
          "/MACHINE:X64",
        ],
        dir,
      ),
    )
  }
  prepare_package(dir, generated)
  println(
    command(moon, ["build", "--target", "native", "--" + mode, "."], dir, env={
      "MOONBIT_NEW_NATIVE": "0",
      "MOONBIT_ALLOCATOR": "system",
    }),
  )
  let artifacts = dir + "/_build/native/" + mode + "/build"
  let sources = @fs.readdir(artifacts, sort=true).filter(file => {
    file.has_suffix(".c")
  })
  if sources.length() != 1 {
    fail("Expected one MoonBit generated C source in \{artifacts}")
  }
  let name = sources[0][:sources[0].length() - 2].to_owned()
  let lines = [
    "cmake_minimum_required(VERSION 3.20)",
    "project(napi_mbt C)",
    "add_library(napi_mbt MODULE " + cmake_quote(dir + "/napi_glue.c") + ")",
    "target_include_directories(napi_mbt PRIVATE " +
    cmake_quote(dir + "/.napi-mbt/include") +
    ")",
    "target_compile_definitions(napi_mbt PRIVATE NAPI_VERSION=\{conf.napi_version})",
    "set_target_properties(napi_mbt PROPERTIES PREFIX \"\" SUFFIX \".node\")",
  ]
  if windows() {
    lines.append([
      "if(NOT MSVC)", "message(FATAL_ERROR \"Windows requires MSVC\")", "endif()",
      "set_property(TARGET napi_mbt PROPERTY MSVC_RUNTIME_LIBRARY MultiThreaded)",
    ])
    let objects = [
      artifacts + "/" + name + ".obj",
      artifacts + "/stub.obj",
      artifacts + "/libruntime.lib",
      dir + "/.napi-mbt/napi.lib",
    ]
    lines.push(
      "target_link_libraries(napi_mbt PRIVATE " +
      objects.map(cmake_quote).join(" ") +
      ")",
    )
  } else {
    let moon_home = match @env.get_env_var("MOON_HOME") {
      Some(home) => home
      None => {
        let compiler = require_command("moonc")
        let parts = compiler.split("/").to_array()
        parts[:parts.length() - 2].map(p => p.to_owned()).join("/")
      }
    }
    let sources = [artifacts + "/" + name + ".c", dir + "/stub.c"]
    let runtime = moon_home + "/lib/runtime"
    if @fs.exists(runtime) {
      for file in @fs.readdir(runtime, sort=true) {
        if file.has_suffix(".c") {
          sources.push(runtime + "/" + file)
        }
      }
    } else {
      sources.push(moon_home + "/lib/runtime.c")
    }
    lines.append([
      "target_sources(napi_mbt PRIVATE " +
      sources.map(cmake_quote).join(" ") +
      ")",
      "target_include_directories(napi_mbt PRIVATE " +
      cmake_quote(moon_home + "/include") +
      ")",
      "target_compile_definitions(napi_mbt PRIVATE MOONBIT_ALLOCATOR=MOONBIT_ALLOCATOR_SYSTEM)",
      "target_compile_options(napi_mbt PRIVATE -fwrapv -fno-strict-aliasing)",
      "target_link_libraries(napi_mbt PRIVATE m)",
      "set_target_properties(napi_mbt PROPERTIES POSITION_INDEPENDENT_CODE ON)",
    ])
    if target.has_prefix("darwin") {
      lines.push(
        "target_link_options(napi_mbt PRIVATE \"-undefined\" \"dynamic_lookup\")",
      )
    }
  }
  let suffix = if windows() {
    if conf.builder == "clang" {
      "-clangcl"
    } else {
      "-msvc"
    }
  } else {
    ""
  }
  let build_dir = dir + "/.napi-mbt/cmake/" + mode + suffix
  write_file(dir + "/.napi-mbt/CMakeLists.txt", lines.join("\n") + "\n")
  let args = ["-S", dir + "/.napi-mbt", "-B", build_dir]
  args.append(generator_args)
  println(command(cmake, args, dir))
  println(
    command(cmake, ["--build", build_dir, "--config", configuration], dir),
  )
  let built = build_dir +
    (if windows() { "/" + configuration } else { "" }) +
    "/napi_mbt.node"
  let output = dir + "/artifacts/" + target
  mkdirp(output, recursive=true)
  write_file(output + "/napi_mbt.node", @fs.read_file(built))
  println("[napi-mbt] built \{output}/napi_mbt.node")
}
