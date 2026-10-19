///|
/// Render every artifact from the validated type IR before doing any file I/O.
pub fn render(
  source : ParsedSource,
  package_name : String,
  napi_version : Int32,
  package_version~ : String,
  cjs~ : Bool = true,
  esm~ : Bool = true,
) -> Array[(String, String)] raise {
  validate_ir(source, napi_version)
  let exports = source.exports
  if !cjs && !esm {
    fail("At least one module mode must be enabled")
  }
  let names : Map[String, Bool] = Map([])
  for item in exports {
    if !valid_export(item.export_name) || names.contains(item.export_name) {
      fail(
        "\{item.filename}:\{item.line}: invalid or duplicate export \{item.export_name}",
      )
    }
    names[item.export_name] = true
  }
  let (cjs_loader, esm_loader) = loaders(
    exports, package_name, package_version, napi_version,
  )
  let types = declarations(exports, source.types)
  let esm_types = types +
    "\ndeclare const $napiAddon: {\n" +
    exports
    .map(e => "  " + e.export_name + ": typeof " + e.export_name + ";")
    .join("\n") +
    "\n};\nexport default $napiAddon;\n"
  let outputs = [
    ("napi_exports.mbt", adapters(exports, source.types)),
    ("napi_glue.c", c_glue(exports)),
    ("index.d.ts", if cjs { types } else { esm_types }),
  ]
  if cjs {
    outputs.append([("index.cjs", cjs_loader), ("index.d.cts", types)])
  }
  if esm {
    outputs.append([("index.mjs", esm_loader), ("index.d.mts", esm_types)])
  }
  outputs
}
