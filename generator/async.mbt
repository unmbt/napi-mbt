///|
fn borrowed_type(
  value : ValueType,
  types : Array[TypeDefinition],
  seen : Array[String],
) -> Bool {
  match value {
    BufferViewType
    | EnvType
    | RawValueType
    | ObjectValueType
    | FunctionValueType
    | ArrayValueType
    | ExternalValueType => true
    OptionType(inner)
    | ArrayType(inner)
    | MapType(inner)
    | SetType(inner)
    | IteratorType(inner)
    | JsPromiseType(inner)
    | AsyncIteratorType(inner) => borrowed_type(inner, types, seen)
    EitherType(a, b) =>
      borrowed_type(a, types, seen) || borrowed_type(b, types, seen)
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
  rt~ : String = "",
) -> String {
  let out = StringBuilder()
  let name = "napi_mbt_adapter_" + item.export_name
  let params = ["env : \{rt}NapiEnv"]
  for i, _ in item.parameters {
    params.push("a\{i} : \{rt}NapiValue")
  }
  params.push("options : \{rt}NapiValue")
  out.write_string(
    "\n///|\n#export_name(\"\{name}\")\npub fn \{name}(\n  \{params.join(",\n  ")},\n) -> \{rt}NapiValue {\n  try {\n    let call = napi_async_call_new(env)\n    try {\n      call.listen(options)\n      if !call.promise.settled {\n",
  )
  let args = []
  for i, p in item.parameters {
    out.write_string(
      "        let p\{i} : \{p.value_type.moonbit_with(rt)} = \{convert_read_expr(p.value_type, "a\{i}", readers, rt, typed=false)}\n",
    )
    let arg = match p.label {
      Positional => "p\{i}"
      Labeled => "\{p.name}=p\{i}"
      OptionalLabeled => "\{p.name}?=p\{i}"
    }
    args.push(arg)
  }
  out.write_string(
    "        call.start(() => {\n          let result : \{item.return_type.moonbit_with(rt)} = \{item.source_name}(\{args.join(", ")})\n          \{convert_write_expr(item.return_type, "result", writers, rt)}\n        })\n      }\n    } catch { error => call.reject(error) }\n    call.promise.promise\n  } catch { error => { \{rt}throw_napi_error(env, error); \{rt}moonbit_dummy_napi_value() } }\n}\n",
  )
  out.to_string()
}
