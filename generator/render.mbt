///|
/// Render every artifact from the validated type IR before doing any file I/O.
pub fn render(
  source : ParsedSource,
  package_name : String,
  napi_version : Int32,
  package_version~ : String,
  cjs~ : Bool = true,
  esm~ : Bool = true,
  worker_tasks~ : Array[String] = [],
) -> Array[(String, String)] raise {
  validate_ir(source, napi_version)
  let exports = source.exports
  if !worker_tasks.is_empty() && napi_version < 8 {
    fail("workerTasks requires N-API 8 for process cleanup registration")
  }
  let snapshots = worker_snapshots(source, worker_tasks)
  if !cjs && !esm {
    fail("At least one module mode must be enabled")
  }
  let names : Map[String, Bool] = Map([])
  for item in exports {
    if !worker_tasks.is_empty() && item.export_name.has_prefix("__napi_mbt_") {
      fail("Reserved internal worker export: " + item.export_name)
    }
    if !valid_export(item.export_name) || names.contains(item.export_name) {
      fail(
        "\{item.filename}:\{item.line}: invalid or duplicate export \{item.export_name}",
      )
    }
    names[item.export_name] = true
  }
  for cls in source.classes {
    if names.contains(cls.name) {
      fail("Duplicate class/export name: \{cls.name}")
    }
    names[cls.name] = true
  }
  let export_names = exports.map(e => e.export_name)
  export_names.append(source.classes.map(c => c.name))
  let (cjs_loader, esm_loader) = loaders(
    export_names,
    package_name,
    package_version,
    napi_version,
    workers=!worker_tasks.is_empty(),
  )
  let types = declarations(
    exports,
    source.types,
    source.classes,
    workers=worker_tasks,
  )
  let esm_types = types +
    "\ndeclare const $napiAddon: {\n" +
    export_names.map(name => "  " + name + ": typeof " + name + ";").join("\n") +
    "\n};\nexport default $napiAddon;\n"
  let outputs = [
    (
      "napi_exports.mbt",
      adapters(source.all_functions(), source.types, source.classes, snapshots~),
    ),
    (
      "napi_glue.c",
      c_glue(
        exports + snapshots,
        source.classes,
        workers=!worker_tasks.is_empty(),
      ),
    ),
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
