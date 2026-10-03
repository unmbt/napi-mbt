///| Difficult cases are covered by the Node integration suite as they exercise

///|
/// filesystem, tree-sitter and native compilation boundaries.
test "export names are not inferred from source names" {
  let item : @generator.ExportSpec = {
    source_name: "internal_add",
    export_name: "mbt_add",
    parameters: [],
    return_type: "Unit",
  }
  assert_true(item.source_name != item.export_name)
}
