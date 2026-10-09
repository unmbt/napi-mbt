///|
struct Generated {
  config : Config
  exports : Array[@generator.ParsedExport]
}

///|
async fn generate(
  dir : String,
  check : Bool,
  override_generator : String?,
) -> Generated {
  let conf = config(dir, override_generator)
  let excluded = [
    "napi_exports.mbt", "_napi_bindings.mbt", "napi_bindings.mbt", "napi_features.mbt",
    "napi_types.mbt", "napi_runtime.mbt",
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
    let source = @generator.parse_source(read_text(dir + "/" + file), file)
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
  let (cjs, esm) = @generator.loaders(
    exports,
    str(pkg, "name", "napi-mbt-package"),
    conf.napi_version,
  )
  let manifest : Json = {
    "napiVersion": conf.napi_version,
    "requiredNapiVersion": conf.napi_version,
    "features": features,
    "targets": conf.targets,
    "generator": conf.generator,
    "builder": conf.builder,
    "exports": exports.map(e => e.manifest()),
  }
  let outputs = [
    ("napi_exports.mbt", @generator.adapters(exports)),
    ("napi_glue.c", @generator.c_glue(exports)),
    ("napi_manifest.json", manifest.stringify(indent=2) + "\n"),
    ("index.d.ts", @generator.declarations(exports)),
    ("index.cjs", cjs),
    ("index.mjs", esm),
  ]
  for (name, text) in outputs {
    let path = dir + "/" + name
    if check {
      if !@fs.exists(path) || @fs.read_file(path).text() != text {
        fail("Generated file is not up-to-date: \{name}")
      }
    } else {
      write_text_file(path, text)
    }
  }
  if !check {
    println("Generated \{exports.length()} N-API export(s).")
  }
  { config: conf, exports, }
}
