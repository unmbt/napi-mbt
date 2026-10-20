///|
fn worker_owned(
  value : ValueType,
  types : Array[TypeDefinition],
  seen : Array[String],
) -> Bool {
  match value {
    BufferViewType | CallbackType(_, _, _) | ClassType(_, _, _) => false
    OptionType(t) | ArrayType(t) | MapType(t) => worker_owned(t, types, seen)
    TupleType(items) => items.all(t => worker_owned(t, types, seen))
    NamedType(name) if !seen.contains(name) => {
      guard types.iter().find_first(t => t.name == name) is Some(definition) else {
        return false
      }
      let path = seen.copy()
      path.push(name)
      let fields = match definition.shape {
        StructShape(fields) => fields
        EnumShape(variants) => variants.map(v => v.parameters).flatten()
      }
      fields.all(p => worker_owned(p.value_type, types, path))
    }
    _ => true
  }
}

///|
fn worker_snapshots(
  source : ParsedSource,
  names : Array[String],
) -> Array[ParsedExport] raise {
  names.map(name => {
    guard source.exports.iter().find_first(e => e.export_name == name)
      is Some(item) else {
      fail("workerTasks names an unknown export: " + name)
    }
    if item.is_async {
      fail("workerTasks requires synchronous exports: " + name)
    }
    if !worker_owned(item.return_type, source.types, []) ||
      !item.parameters.all(p => worker_owned(p.value_type, source.types, [])) {
      fail(
        "workerTasks only accepts owned values; callbacks, classes and borrowed views are forbidden: " +
        name,
      )
    }
    {
      ..item,
      export_name: "__napi_mbt_snapshot_" + name,
      return_type: TupleType(item.parameters.map(p => p.value_type)),
    }
  })
}

///|
fn worker_snapshot_adapters(
  items : Array[ParsedExport],
  readers : Array[ValueType],
  writers : Array[ValueType],
) -> String {
  let out = StringBuilder()
  for item in items {
    let name = "napi_mbt_adapter_" + item.export_name
    let params = ["env : NapiEnv"]
    for i, _ in item.parameters {
      params.push("a\{i} : NapiValue")
    }
    out.write_string(
      "\n///|\n#export_name(\"" +
      name +
      "\")\npub fn " +
      name +
      "(" +
      params.join(", ") +
      ") -> NapiValue {\n  try {\n",
    )
    // Read all arguments before publishing the snapshot. This runs the same IR
    // converters as ordinary calls without invoking the business function.
    for i, p in item.parameters {
      out.write_string(
        "    let p\{i} = " +
        conversion_name(p.value_type, readers, true) +
        "(env, a\{i}, [])\n",
      )
    }
    out.write_string(
      "    let snapshot = napi_array_new(env, \{item.parameters.length()})\n",
    )
    for i, p in item.parameters {
      out.write_string(
        "    napi_array_set(env, snapshot, \{i}, " +
        conversion_name(p.value_type, writers, false) +
        "(env, p\{i}, 0))\n",
      )
    }
    out.write_string(
      "    snapshot\n  } catch { error => { throw_napi_error(env, error); moonbit_dummy_napi_value() } }\n}\n",
    )
  }
  out.to_string()
}
