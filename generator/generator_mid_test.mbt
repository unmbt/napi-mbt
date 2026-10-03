///|
/// Mid-level contract test for configuration values.
test "generator config records one N-API version" {
  let config : @generator.GeneratorConfig = {
    napi_version: 1,
    builder: "auto",
    generator: "auto",
  }
  assert_eq(config.napi_version, 1)
  assert_eq(config.builder, "auto")
}

///|
test "emitters are deterministic and independent per export" {
  let exports : Array[@generator.ExportSpec] = [
    {
      source_name: "add",
      export_name: "mbt_add",
      parameters: ["a : Int", "b : Int"],
      return_type: "Int",
    },
  ]
  let mbt = @generator.render_moonbit_adapters(exports)
  let c = @generator.render_c_glue(exports, 1)
  assert_true(mbt.contains("napi_mbt_adapter_mbt_add"))
  assert_true(c.contains("napi_mbt_callback_mbt_add"))
  assert_true(!c.contains("func_id"))
}
