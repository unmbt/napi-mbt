///|
/// Basic SDD examples are intentionally small and deterministic.
test "export spec has independent source and export names" {
  let item : @generator.ExportSpec = {
    source_name: "add",
    export_name: "mbt_add",
    parameters: ["Int", "Int"],
    return_type: "Int",
  }
  assert_eq(item.source_name, "add")
  assert_eq(item.export_name, "mbt_add")
}

///|
test "scanner reads export_name" {
  let exports = @generator.scan_source(
    "#export_name(\"mbt_add\")\npub fn add(a : Int, b : Int) -> Int { a + b }",
  )
  assert_eq(exports.length(), 1)
  assert_eq(exports[0].source_name, "add")
  assert_eq(exports[0].export_name, "mbt_add")
  assert_eq(exports[0].parameters.length(), 2)
}
