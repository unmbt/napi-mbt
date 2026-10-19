///|
async fn prepare_package(dir : String, generated : Generated) -> Unit {
  let exports = generated.source.native_exports()
  let path = dir + "/moon.pkg"
  let overlay = build_package_overlay(
    read_text(path),
    exports,
    generated.config.napi_version,
    windows(),
  )
  let overlay = if host_target().has_prefix("darwin") {
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
