///|
fn worker_pool_configuration(value : Json?) -> Json raise {
  let fields = match value {
    None => Map([])
    Some(value) => object(value)
  }
  for key in fields.keys() {
    if !["size", "maxQueue", "idleTimeoutMs"].contains(key) {
      fail("Unknown workerPool setting: " + key)
    }
  }
  for
    (key, fallback, minimum, maximum) in [
      ("size", 2, 1, 64),
      ("maxQueue", 64, 0, 100000),
      ("idleTimeoutMs", 30000, 1, 2147483647),
    ] {
    match fields.get(key) {
      None => fields[key] = Json(fallback)
      Some(Number(value, ..)) if value >= minimum.to_double() &&
        value <= maximum.to_double() &&
        value == value.to_int().to_double() => ()
      _ => fail("Invalid workerPool." + key)
    }
  }
  Json(fields)
}

///|
fn worker_outputs(
  source : @generator.ParsedSource,
  conf : Config,
) -> Array[(String, String)] raise {
  if conf.worker_tasks.is_empty() {
    return []
  }
  let config = object(@json.parse(conf.worker_pool.stringify()))
  let tasks : Map[String, Json] = Map([])
  for item in source.exports {
    if conf.worker_tasks.contains(item.export_name) {
      tasks[item.export_name] = Json(item.parameters.length())
    }
  }
  config["tasks"] = Json(tasks)
  config["exports"] = Json(
    source.exports.map(e => e.export_name) + source.classes.map(c => c.name),
  )
  [
    (
      "napi_workers.cjs",
      @assets.files()["workers/pool.cjs"].replace_all(
        old="/* NAPI_MBT_WORKER_CONFIG */",
        new="JSON.parse(" + Json(Json(config).stringify()).stringify() + ")",
      ),
    ),
    ("napi_worker_entry.cjs", @assets.files()["workers/entry.cjs"]),
  ]
}
