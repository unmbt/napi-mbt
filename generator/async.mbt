///|
fn borrowed_type(
  value : ValueType,
  types : Array[TypeDefinition],
  seen : Array[String],
) -> Bool {
  match value {
    BufferViewType => true
    OptionType(inner)
    | ArrayType(inner)
    | MapType(inner)
    | SetType(inner)
    | IteratorType(inner)
    | JsPromiseType(inner)
    | AsyncIteratorType(inner) => borrowed_type(inner, types, seen)
    TupleType(items) => items.any(item => borrowed_type(item, types, seen))
    CallbackType(params, ret, _) =>
      params.any(p => borrowed_type(p, types, seen)) ||
      borrowed_type(ret, types, seen)
    NamedType(name) if !seen.contains(name) => {
      for def in types {
        if def.name == name {
          let path = seen.copy()
          path.push(name)
          let fields = match def.shape {
            StructShape(fields) => fields
            EnumShape(variants) => variants.map(v => v.parameters).flatten()
          }
          return fields.any(p => borrowed_type(p.value_type, types, path))
        }
      }
      false
    }
    _ => false
  }
}

///|
fn async_adapter(
  item : ParsedExport,
  readers : Array[ValueType],
  writers : Array[ValueType],
) -> String {
  let out = StringBuilder()
  let name = "napi_mbt_adapter_" + item.export_name
  let params = ["env : NapiEnv"]
  for i, _ in item.parameters {
    params.push("a\{i} : NapiValue")
  }
  params.push("options : NapiValue")
  out.write_string(
    "\n///|\n#export_name(\"\{name}\")\npub fn \{name}(\n  \{params.join(",\n  ")},\n) -> NapiValue {\n  try {\n    let call = napi_async_call_new(env)\n    try {\n      call.listen(options)\n      if !call.promise.settled {\n",
  )
  let args = []
  for i, p in item.parameters {
    out.write_string(
      "        let p\{i} = \{conversion_name(p.value_type, readers, true)}(env, a\{i}, [])\n",
    )
    args.push("p\{i}")
  }
  out.write_string(
    "        call.start(() => {\n          let result : \{item.return_type.moonbit()} = \{item.source_name}(\{args.join(", ")})\n          \{conversion_name(item.return_type, writers, false)}(env, result, 0)\n        })\n      }\n    } catch { error => call.reject(error) }\n    call.promise.promise\n  } catch { error => { throw_napi_error(env, error); moonbit_dummy_napi_value() } }\n}\n",
  )
  out.to_string()
}
