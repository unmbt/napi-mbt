///|
async fn prepare_package(dir : String, generated : Generated) -> Unit {
  if !windows() {
    prepare_dependency_pic(dir)
  }
  let exports = generated.source.native_exports()
  let path = dir + "/moon.pkg"
  let overlay = build_package_overlay(
    read_text(path),
    exports,
    generated.config.napi_version,
    windows(),
  )
  let overlay = if host_target().has_prefix("linux") {
    let symbols = package_strings(
      package_value(overlay, native_block(overlay), "exports"),
    )
    write_text_file(dir + "/.napi-mbt/exports.map", elf_export_map(symbols))
    append_native_flag(
      overlay, "cc-link-flags", "-Wl,-Bsymbolic -Wl,--version-script=./.napi-mbt/exports.map",
    )
  } else if host_target().has_prefix("darwin") {
    append_native_flag(overlay, "cc-link-flags", "-undefined dynamic_lookup")
  } else {
    overlay
  }
  write_text_file(path, overlay)
  // Reference the registration translation unit from MoonBit initialization,
  // so the native linker pulls it from the package's stub archive.
  write_text_file(
    dir + "/napi_link.mbt",
    "///|\nextern \"c\" fn napi_link_anchor() -> Unit = \"napi_mbt_link_anchor\"\n///|\nfn init { napi_link_anchor() }\n",
  )
  write_text_file(
    dir + "/napi_glue.c",
    read_text(dir + "/napi_glue.c") + "\nvoid napi_mbt_link_anchor(void) {}\n",
  )
}

///|
// Hide bundled runtime/C++ dependency symbols from Node and other addons while
// retaining the package's explicit C exports and the Node-API registration.
fn elf_export_map(exports : Array[String]) -> String {
  let symbols = exports.copy()
  if !symbols.contains("napi_register_module_v1") {
    symbols.push("napi_register_module_v1")
  }
  "{\n  global:\n" +
  symbols.map(name => "    " + Json(name).stringify() + ";").join("\n") +
  "\n  local: *;\n};\n"
}

///|
// Only the isolated copy is changed. Moon still chooses the dependency closure
// and owns all stub archive/link inputs; user flags and libraries are retained.
async fn prepare_dependency_pic(dir : String) -> Unit {
  for name in @fs.readdir(dir) {
    let path = dir + "/" + name
    if @fs.kind(path) == Directory {
      if [".napi-mbt", "_build", ".git"].contains(name) {
        continue
      }
      prepare_dependency_pic(path)
    } else if name == "moon.pkg" {
      let original = read_text(path)
      let updated = dependency_pic_overlay(original)
      if original != updated {
        write_text_file(path, updated)
      }
    }
  }
}
