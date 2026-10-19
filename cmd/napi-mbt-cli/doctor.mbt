///|
struct NativeToolchain {
  moon : String
  librarian : String?
  workspace : String
  report : Json
}

///|
async fn NativeToolchain::close(self : NativeToolchain) -> Unit {
  // Remove the junction itself before recursively deleting our private workspace.
  if @fs.exists(self.workspace + "/msbuild") {
    @fs.remove(self.workspace + "/msbuild")
  }
  @fs.rmdir(self.workspace, recursive=true)
}

///|
fn validate_builder(builder : String, is_windows : Bool) -> Unit raise {
  if !["auto", "cmake", "gcc", "clang", "msvc"].contains(builder) {
    fail("Unknown builder: \{builder}")
  }
  if is_windows && builder == "gcc" {
    fail(
      "Windows requires an MSVC-compatible toolchain; MinGW GCC cannot link MoonBit artifacts",
    )
  }
  if !is_windows && builder == "msvc" {
    fail("MSVC builds require Windows")
  }
}

///|
async fn detect_toolchain(dir : String, builder : String) -> NativeToolchain {
  validate_builder(builder, windows())
  let moon = require_command("moon")
  let cmake = require_command("cmake")
  let report : Map[String, Json] = {
    "target": Json(host_target()),
    "moon": {
      "path": Json(moon),
      "version": Json(
        command(moon, ["version", "--all"], dir).trim().to_owned(),
      ),
    },
    "cmake": {
      "path": Json(cmake),
      "version": Json(command(cmake, ["--version"], dir).trim().to_owned()),
    },
  }
  let args = []
  let mut librarian = None
  let probe = @fs.tmpdir(prefix="napi-mbt-toolchain-")
  errdefer {
    if @fs.exists(probe + "/msbuild") {
      @fs.remove(probe + "/msbuild")
    }
    @fs.rmdir(probe, recursive=true)
  }
  if windows() {
    let (root, version) = visual_studio(dir)
    let msbuild = root + "/MSBuild/Current/Bin/MSBuild.exe"
    if !@fs.exists(msbuild) {
      fail(
        "MSBuild is missing from Visual Studio instance \{root}: \{msbuild}. Install the MSBuild and C++ build tools components.",
      )
    }
    let msbuild_version = command(msbuild, ["-nologo", "-version"], dir)
    // CMake 4.0's VS generator searches the *whole path* for IDE tool names.
    // A harmless parent directory can therefore select the wrong command syntax.
    // Use a private directory junction, retaining the actual executable and its
    // adjacent .NET assemblies. Never copy or replace the installed toolchain.
    let make_program = if msbuild.to_lower().contains("devenv") ||
      msbuild.to_lower().contains("vcexpress") {
      @fs.symlink(probe + "/msbuild", target=root)
      probe + "/msbuild/MSBuild/Current/Bin/MSBuild.exe"
    } else {
      msbuild
    }
    let tools_dir = root + "/VC/Tools/MSVC"
    let versions = @fs.readdir(tools_dir, sort=true)
    versions.sort_by((a, b) => lexical_compare(b, a))
    let mut compiler = None
    for version in versions {
      let bin = tools_dir + "/" + version + "/bin/Hostx64/x64/"
      if @fs.exists(bin + "cl.exe") && @fs.exists(bin + "lib.exe") {
        compiler = Some(bin + "cl.exe")
        librarian = Some(bin + "lib.exe")
        break
      }
    }
    guard compiler is Some(cl) else {
      fail(
        "Visual Studio instance \{root} has no complete x64 C++ toolset (cl.exe and lib.exe)",
      )
    }
    let generator = visual_studio_generator(
      version,
      @json.parse(command(cmake, ["-E", "capabilities"], dir)),
    )
    args.append([
      "-G",
      generator,
      "-A",
      "x64",
      "-DCMAKE_GENERATOR_INSTANCE=" + root,
      "-DCMAKE_MAKE_PROGRAM=" + make_program,
      "-T",
      if builder == "clang" {
        "ClangCL,host=x64"
      } else {
        "host=x64"
      },
    ])
    report["visualStudio"] = {
      "path": Json(root),
      "version": Json(version),
      "compiler": Json(cl),
    }
    report["msbuild"] = {
      "path": Json(msbuild),
      "version": Json(msbuild_version.trim().to_owned()),
    }
  } else {
    if find_command("ninja") is Some(_) {
      args.append(["-G", "Ninja"])
    }
    if builder == "gcc" || builder == "clang" {
      args.push("-DCMAKE_C_COMPILER=" + require_command(builder))
    }
  }
  // This workspace is disposable. No project output or configuration is touched
  // until the compiler, linker and platform SDK have passed a real build.
  write_file(
    probe + "/probe.c",
    "#include <stdlib.h>\n#ifdef _WIN32\n#include <windows.h>\n#endif\nint main(void) { void *p = malloc(16); free(p); return 0; }\n",
  )
  let cmakelists =
    #|cmake_minimum_required(VERSION 3.20)
    #|project(napi_mbt_probe C)
    #|add_executable(probe probe.c)
    #|file(WRITE "${CMAKE_BINARY_DIR}/toolchain.txt" "${CMAKE_C_COMPILER}\n${CMAKE_C_COMPILER_VERSION}\n${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}\n")
    #|
  write_file(probe + "/CMakeLists.txt", cmakelists)
  let configure = ["-S", probe, "-B", probe + "/build"]
  configure.append(args)
  try {
    ignore(command(cmake, configure, dir))
    ignore(
      command(cmake, ["--build", probe + "/build", "--config", "Release"], dir),
    )
  } catch {
    error =>
      fail(
        "Native toolchain compile/link probe failed for \{host_target()}. Check the selected compiler, MSBuild and platform SDK.\n\{error}",
      )
  }
  let details = @fs.read_file(probe + "/build/toolchain.txt")
    .text()
    .split("\n")
    .to_array()
  report["compiler"] = {
    "path": Json(details[0].trim().to_owned()),
    "version": Json(details[1].trim().to_owned()),
  }
  if windows() {
    report["windowsSdk"] = Json(details[2].trim().to_owned())
  }
  report["probe"] = "passed"
  { moon, librarian, workspace: probe, report: Json(report), }
}

///|
async fn doctor(directory : String, json : Bool) -> Unit {
  let report = try {
    let dir = @fs.realpath(directory)
    let conf = config(dir)
    let toolchain = detect_toolchain(dir, conf.builder)
    defer toolchain.close()
    toolchain.report
  } catch {
    error => {
      if json {
        println(
          ({ "ok": false, "error": Json(error.to_string()) } : Json).stringify(),
        )
      }
      fail(error.to_string())
    }
  }
  if json {
    println(({ "ok": true, "toolchain": report } : Json).stringify())
  } else {
    println(
      "[napi-mbt] Native toolchain compile/link probe passed\n" +
      report.stringify(indent=2),
    )
  }
}
