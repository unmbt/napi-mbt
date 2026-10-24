///|
struct Generated {
  config : Config
  source : @generator.ParsedSource
  outputs : Array[(String, String)]
  removals : Array[String]
}

///|
async fn generate(
  dir : String,
  check : Bool,
  check_package~ : Bool = true,
) -> Generated {
  let conf = config(dir)
  let runtime = read_text(dir + "/napi_runtime_version.mbt")
  guard runtime.find("=") is Some(equal) &&
    @json.parse(runtime[equal + 1:].trim().to_owned()) ==
    Json(@assets.runtime_version()) else {
    fail("Runtime template version does not match this generator")
  }
  let excluded = [
    "napi_exports.mbt", "_napi_bindings.mbt", "napi_bindings.mbt", "napi_features.mbt",
    "napi_types.mbt", "napi_runtime.mbt", "napi_error.mbt", "napi_values.mbt", "napi_classes.mbt",
    "napi_callbacks.mbt", "napi_reference.mbt", "napi_collections.mbt", "napi_owned_binary.mbt",
    "napi_arraybuffer.mbt", "napi_dates.mbt", "napi_symbols.mbt", "napi_iterators.mbt",
    "napi_low_level.mbt", "napi_advanced.mbt", "napi_typed_tsfn.mbt", "napi_native_tasks.mbt",
    "napi_native_exports.mbt",
  ]
  let features = conf.features.copy()
  let seen : Map[String, String] = Map([])
  let sources = []
  for file in @fs.readdir(dir, sort=true) {
    if !file.has_suffix(".mbt") ||
      file.has_suffix("_test.mbt") ||
      file.has_suffix("_wbtest.mbt") ||
      excluded.contains(file) {
      continue
    }
    sources.push((file, read_text(dir + "/" + file)))
  }
  if !conf.native_tasks.is_empty() {
    sources.push(
      ("napi_native_exports.mbt", native_task_source(conf.native_tasks)),
    )
    if !features.contains("native_tasks") {
      features.push("native_tasks")
    }
  }
  let source = @generator.parse_sources(sources, classes=conf.classes)
  let exports = source.exports
  for feature in source.features {
    if !features.contains(feature) {
      features.push(feature)
    }
  }
  for item in source.exports {
    if seen.contains(item.export_name) {
      fail(
        "\{item.filename}:\{item.line}: duplicate export name \{item.export_name} (first in \{seen[item.export_name]})",
      )
    }
    seen[item.export_name] = item.filename
  }
  features.sort()
  let conf = { ..conf, features, }
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
    source,
    str(pkg, "name", "napi-mbt-package"),
    conf.napi_version,
    package_version=str(pkg, "version", "0.1.0"),
    cjs=conf.cjs,
    esm=conf.esm,
    worker_tasks=conf.worker_tasks,
  )
  outputs.append(worker_outputs(source, conf))
  if !conf.native_tasks.is_empty() {
    for i, (name, source) in outputs {
      if name == "napi_glue.c" {
        outputs[i] = (name, source + native_task_glue(conf.native_tasks))
      }
    }
    outputs.push(
      ("napi_native_exports.mbt", native_task_source(conf.native_tasks)),
    )
  }
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
    "types": source.types.map(t => t.manifest()),
    "classes": source.classes.map(c => c.manifest()),
    "nativeTasks": Map::from_array(conf.native_tasks),
    "workerTasks": conf.worker_tasks,
    "workerPool": conf.worker_pool,
  }
  outputs.push(("napi_manifest.json", manifest.stringify(indent=2) + "\n"))
  outputs.push(
    ("napi-mbt.schema.json", config_schema().stringify(indent=2) + "\n"),
  )
  outputs.push(
    ("package.json", package_metadata(pkg, conf).stringify(indent=2) + "\n"),
  )
  let removals = []
  if conf.worker_tasks.is_empty() {
    removals.append(["napi_workers.cjs", "napi_worker_entry.cjs"])
  }
  if conf.native_tasks.is_empty() {
    removals.append(["napi_native_exports.mbt", "napi_native_tasks.mbt"])
  }
  if !conf.cjs {
    removals.append(["index.cjs", "index.d.cts"])
  }
  if !conf.esm {
    removals.append(["index.mjs", "index.d.mts"])
  }
  install_outputs(
    dir,
    if check && !check_package {
      outputs.filter(output => output.0 != "package.json")
    } else {
      outputs
    },
    check,
    removals~,
  )
  if !check {
    println("Generated \{exports.length()} N-API export(s).")
  }
  { config: conf, source, outputs, removals, }
}
