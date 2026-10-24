///|
async fn executable_path() -> String {
  let executable = @env.args()[0]
  if executable.contains("/") || executable.contains("\\") {
    @fs.realpath(executable)
  } else {
    require_command(executable)
  }
}

///|
async fn toolchain_signature(
  dir : String,
  builder : String,
  report : Json,
) -> Json {
  let result : Map[String, Json] = Map([])
  for
    name in [
      "MOON_HOME", "MOON_CC", "MOON_AR", "CC", "CFLAGS", "CXXFLAGS", "LDFLAGS", "INCLUDE",
      "LIB", "SDKROOT", "MACOSX_DEPLOYMENT_TARGET", "WindowsSdkDir", "WindowsSDKVersion",
      "VCToolsInstallDir",
    ] {
    result[name] = Json(@env.get_env_var(name))
  }
  let paths = [
    require_command("moon"),
    require_command("moonc"),
    require_command("cmake"),
    executable_path(),
  ]
  if report is { "compiler": { "path": String(path), .. }, .. } {
    paths.push(path)
  }
  if report is { "msbuild": { "path": String(path), .. }, .. } {
    paths.push(path)
  }
  if windows() {
    if report is { "visualStudio": { "compiler": String(path), .. }, .. } {
      let parts = path.replace_all(old="\\", new="/").split("/").to_array()
      let directory = parts[:parts.length() - 1]
        .map(p => p.to_owned())
        .join("/")
      for name in ["lib.exe", "link.exe", "c1.dll", "c2.dll"] {
        if @fs.exists(directory + "/" + name) {
          paths.push(directory + "/" + name)
        }
      }
    }
    let (root, version) = visual_studio(dir)
    result["visualStudio"] = Json([root, version])
    result["toolsets"] = Json(@fs.readdir(root + "/VC/Tools/MSVC", sort=true))
    let kits = @env.get_env_var("ProgramFiles(x86)").unwrap_or(
        "C:/Program Files (x86)",
      ) +
      "/Windows Kits/10"
    let sdk : Map[String, Json] = Map([])
    for name in ["Include", "Lib"] {
      let base = kits + "/" + name
      if @fs.exists(base) {
        for version in @fs.readdir(base, sort=true) {
          sdk[name + "/" + version] = Json(
            @fs.mtime(base + "/" + version).0.to_string(),
          )
          if name == "Include" {
            for
              header in ["shared/sdkddkver.h", "um/Windows.h", "ucrt/stdlib.h"] {
              let path = base + "/" + version + "/" + header
              if @fs.exists(path) {
                paths.push(path)
              }
            }
          }
        }
      }
    }
    result["sdk"] = Json(sdk)
  } else {
    let compiler = configured_native_compiler(dir, builder).unwrap_or(
      require_command("cc"),
    )
    paths.push(compiler)
    for name in ["ar", "ld", "cc1", "nm"] {
      let selected = command(compiler, ["-print-prog-name=" + name], dir)
        .trim()
        .to_owned()
      let resolved = Some(resolve_compiler(selected, dir)) catch { _ => None }
      if resolved is Some(path) && @fs.exists(path) {
        paths.push(path)
      }
    }
    result["selectedCompiler"] = Json(compiler)
    if host_target().has_prefix("linux-") {
      for name in ["libc.so", "libc.so.6", "libm.so", "libpthread.so"] {
        let selected = command(compiler, ["-print-file-name=" + name], dir)
          .trim()
          .to_owned()
        if selected.has_prefix("/") && @fs.exists(selected) {
          paths.push(@fs.realpath(selected))
        }
      }
    }
    if host_target().has_prefix("darwin") {
      result["sdk"] = Json(
        command(
          require_command("xcrun"),
          ["--show-sdk-path", "--show-sdk-version"],
          dir,
        ),
      )
    }
    for header in ["/usr/include/features.h", "/usr/include/stdlib.h"] {
      if @fs.exists(header) {
        paths.push(header)
      }
    }
  }
  let files : Map[String, Json] = Map([])
  for path in paths {
    files[path] = Json(content_digest(@fs.read_file(path).binary()))
  }
  result["files"] = Json(files)
  result["builder"] = Json(builder)
  Json(result)
}

///|
async fn build_toolchain(
  dir : String,
  builder : String,
  reuse : Bool,
) -> NativeToolchain {
  let path = dir + "/.napi-mbt/cache/toolchain.json"
  if reuse && @fs.exists(path) {
    let cached : NativeToolchain? = try {
      guard @json.parse(read_text(path))
        is {
          "signature": signature,
          "report": report,
          "moon": String(moon),
          "librarian": library,
          ..
        } else {
        fail("Invalid toolchain cache")
      }
      if toolchain_signature(dir, builder, report) != signature {
        None
      } else {
        let librarian = match library {
          String(text) => Some(text)
          Null => None
          _ => fail("Invalid librarian")
        }
        Some({ moon, librarian, workspace: "", report, })
      }
    } catch {
      _ => None
    }
    if cached is Some(toolchain) {
      return toolchain
    }
  }
  let toolchain = detect_toolchain(dir, builder)
  errdefer toolchain.close()
  if reuse {
    mkdirp(dir + "/.napi-mbt/cache")
    let signature = toolchain_signature(dir, builder, toolchain.report)
    write_json(path, {
      "signature": signature,
      "report": toolchain.report,
      "moon": Json(toolchain.moon),
      "librarian": match toolchain.librarian {
        Some(path) => Json(path)
        None => Json::null()
      },
    })
  }
  toolchain
}
