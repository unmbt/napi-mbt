///|
/// Render every artifact from the validated type IR before doing any file I/O.
pub fn render(
  exports : Array[ParsedExport],
  package_name : String,
  napi_version : Int32,
) -> Array[(String, String)] raise {
  let names : Map[String, Bool] = Map([])
  for item in exports {
    if !valid_export(item.export_name) || names.contains(item.export_name) {
      fail(
        "\{item.filename}:\{item.line}: invalid or duplicate export \{item.export_name}",
      )
    }
    names[item.export_name] = true
  }
  let (cjs, esm) = loaders(exports, package_name, napi_version)
  [
    ("napi_exports.mbt", adapters(exports)),
    ("napi_glue.c", c_glue(exports)),
    ("index.d.ts", declarations(exports)),
    ("index.cjs", cjs),
    ("index.mjs", esm),
  ]
}
