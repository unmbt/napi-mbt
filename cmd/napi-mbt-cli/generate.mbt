///|
struct Generated {
  config : Config
  exports : Array[@generator.ParsedExport]
}

///|
async fn generate(dir : String, check : Bool) -> Generated {
  let conf = config(dir)
  let excluded = [
    "napi_exports.mbt", "_napi_bindings.mbt", "napi_bindings.mbt", "napi_features.mbt",
    "napi_types.mbt", "napi_runtime.mbt", "napi_error.mbt",
  ]
  let exports = []
  let features = conf.features.copy()
  let seen : Map[String, String] = Map([])
  for file in @fs.readdir(dir, sort=true) {
    if !file.has_suffix(".mbt") ||
      file.has_suffix("_test.mbt") ||
      file.has_suffix("_wbtest.mbt") ||
      excluded.contains(file) {
      continue
    }
    let source = @generator.parse_source(
      @fs.read_file(dir + "/" + file).text(),
      file,
    )
    for feature in source.features {
      if !features.contains(feature) {
        features.push(feature)
      }
    }
    for item in source.exports {
      if seen.contains(item.export_name) {
        fail(
          "\{file}:\{item.line}: duplicate export name \{item.export_name} (first in \{seen[item.export_name]})",
        )
      }
      seen[item.export_name] = file
      exports.push(item)
    }
  }
  features.sort()
  for feature in features {
    let required = feature_version(feature)
    if conf.napi_version < required {
      fail(
        "napiVersion \{conf.napi_version} is lower than inferred API requirement \{required}",
      )
    }
  }
  exports.sort_by((a, b) => lexical_compare(a.export_name, b.export_name))
  let pkg = read_object(dir + "/package.json")
  let outputs = @generator.render(
    exports,
    str(pkg, "name", "napi-mbt-package"),
    conf.napi_version,
    package_version=str(pkg, "version", "0.1.0"),
    cjs=conf.cjs,
    esm=conf.esm,
  )
  let manifest : Json = {
    "runtimeTemplateVersion": @assets.runtime_version(),
    "napiVersion": conf.napi_version,
    "requiredNapiVersion": conf.napi_version,
    "features": features,
    "targets": conf.targets,
    "cjs": conf.cjs,
    "esm": conf.esm,
    "builder": conf.builder,
    "exports": exports.map(e => e.manifest()),
  }
  outputs.push(("napi_manifest.json", manifest.stringify(indent=2) + "\n"))
  outputs.push(
    ("napi-mbt.schema.json", config_schema().stringify(indent=2) + "\n"),
  )
  outputs.push(
    ("package.json", package_metadata(pkg, conf).stringify(indent=2) + "\n"),
  )
  let removals = []
  if !conf.cjs {
    removals.append(["index.cjs", "index.d.cts"])
  }
  if !conf.esm {
    removals.append(["index.mjs", "index.d.mts"])
  }
  install_outputs(dir, outputs, check, removals~)
  if !check {
    println("Generated \{exports.length()} N-API export(s).")
  }
  { config: conf, exports, }
}
