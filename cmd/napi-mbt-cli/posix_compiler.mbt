///|
async fn resolve_compiler(path : String, dir : String) -> String {
  if path.contains("/") {
    @fs.realpath(if path.has_prefix("/") { path } else { dir + "/" + path })
  } else {
    require_command(path)
  }
}

///|
async fn configured_native_compiler(dir : String, builder : String) -> String? {
  if builder == "gcc" || builder == "clang" {
    return Some(require_command(builder))
  }
  if @env.get_env_var("MOON_CC") is Some(path) {
    return Some(resolve_compiler(path, dir))
  }
  package_native_compiler(dir)
}

///|
async fn package_native_compiler(dir : String) -> String? {
  if !@fs.exists(dir + "/moon.pkg") {
    return None
  }
  let text = read_text(dir + "/moon.pkg")
  let tokens = package_tokens(text)
  let has_link = package_call(tokens, "link") is Some(_) ||
    (
      package_call(tokens, "options") is Some(open) &&
      package_field(tokens, open, "link") is Some(_)
    )
  if !has_link {
    return None
  }
  if package_value(text, native_block(text), "cc") is Some(raw) {
    guard @json.parse(raw) is String(path) else {
      fail("Native cc must be a compiler path")
    }
    return Some(resolve_compiler(path, dir))
  }
  None
}

///|
async fn validate_package_compilers(dir : String, compiler : String) -> Unit {
  if package_native_compiler(dir) is Some(selected) &&
    @fs.realpath(selected) != @fs.realpath(compiler) {
    fail(
      "Native compiler in \{dir}/moon.pkg conflicts with the addon toolchain: \{selected} vs \{compiler}",
    )
  }
  for name in @fs.readdir(dir) {
    if [".napi-mbt", "_build", ".git"].contains(name) {
      continue
    }
    let path = dir + "/" + name
    if @fs.kind(path) == Directory {
      validate_package_compilers(path, compiler)
    }
  }
}

///|
// The pinned Moon builder does not forward package flags when compiling its
// runtime objects. A native compiler driver adds PIC to that invocation too.
// It delegates to the already-probed compiler and preserves every argument.
async fn prepare_posix_compiler(
  workspace : String,
  compiler : String,
) -> String {
  validate_package_compilers(workspace, compiler)
  let source = workspace + "/.napi-mbt/cc.c"
  let driver = workspace + "/.napi-mbt/cc"
  let archiver = @env.get_env_var("MOON_AR").unwrap_or(
    command(compiler, ["-print-prog-name=ar"], workspace).trim().to_owned(),
  )
  @fs.symlink(
    workspace + "/.napi-mbt/ar",
    target=resolve_compiler(archiver, workspace),
  )
  let compiler_literal = Json(compiler).stringify()
  write_text_file(
    source,
    "#include <unistd.h>\n#include <stdlib.h>\n#include <stdio.h>\nint main(int argc, char **argv) {\n  char **args = calloc((size_t)argc + 2, sizeof(char *));\n  if (!args) return 127;\n  args[0] = " +
    compiler_literal +
    ";\n  for (int i = 1; i < argc; i++) args[i] = argv[i];\n  args[argc] = \"-fPIC\";\n  execv(args[0], args);\n  perror(\"napi-mbt native compiler\");\n  free(args);\n  return 127;\n}\n",
  )
  ignore(command(compiler, [source, "-o", driver], workspace))
  let path = workspace + "/moon.pkg"
  let text = read_text(path)
  write_text_file(
    path,
    package_set(text, native_block(text), "cc", Json(driver).stringify()),
  )
  driver
}
