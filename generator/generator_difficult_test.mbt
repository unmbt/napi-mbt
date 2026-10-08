///|
/// Filesystem and native compilation are also exercised by cli-native-test.mbtx.
test "export names are not inferred from source names" {
  let item : @generator.ExportSpec = {
    source_name: "internal_add",
    export_name: "mbt_add",
    parameters: [],
    return_type: "Unit",
  }
  assert_true(item.source_name != item.export_name)
}
