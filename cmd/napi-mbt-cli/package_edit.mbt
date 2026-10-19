///|
async fn prepare_package(dir : String, generated : Generated) -> Unit {
  let exports = ["moonbit_init"]
  for item in generated.exports {
    exports.push("napi_mbt_adapter_" + item.export_name)
  }
  let path = dir + "/moon.pkg"
  let overlay = build_package_overlay(
    @fs.read_file(path).text(),
    exports,
    generated.config.napi_version,
    windows(),
  )
  let overlay = if host_target().has_prefix("darwin") {
    append_native_flag(overlay, "cc-link-flags", "-undefined dynamic_lookup")
  } else {
    overlay
  }
  write_file(path, overlay)
  // Reference the registration translation unit from MoonBit initialization,
  // so the native linker pulls it from the package's stub archive.
  write_file(
    dir + "/napi_link.mbt",
    "///|\nextern \"c\" fn napi_link_anchor() -> Unit = \"napi_mbt_link_anchor\"\n///|\nfn init { napi_link_anchor() }\n",
  )
  write_file(
    dir + "/napi_glue.c",
    @fs.read_file(dir + "/napi_glue.c").text() +
    "\nvoid napi_mbt_link_anchor(void) {}\n",
  )
}
