///|
fn conversion_name(
  value : ValueType,
  types : Array[ValueType],
  read : Bool,
) -> String {
  for i, t in types {
    if t.runtime_name() == value.runtime_name() {
      return "napi_mbt_" +
        (if read { "read_" } else { "write_" }) +
        i.to_string()
    }
  }
  abort("Validated conversion type missing")
}

///|
fn conversion_types(
  exports : Array[ParsedExport],
  definitions : Array[TypeDefinition],
  read : Bool,
) -> Array[ValueType] {
  let readers : Array[ValueType] = []
  let writers : Array[ValueType] = []
  fn collect(value : ValueType, read : Bool) -> Unit {
    let types = if read { readers } else { writers }
    if types.any(t => t.runtime_name() == value.runtime_name()) {
      return
    }
    types.push(value)
    match value {
      OptionType(inner)
      | ArrayType(inner)
      | MapType(inner)
      | SetType(inner)
      | IteratorType(inner)
      | JsPromiseType(inner)
      | AsyncIteratorType(inner) => collect(inner, read)
      TupleType(items) =>
        for item in items {
          collect(item, read)
        }
      CallbackType(params, ret, _) => {
        for p in params {
          collect(p, !read)
        }
        collect(ret, read)
      }
      NamedType(name) =>
        for def in definitions {
          if def.name == name {
            match def.shape {
              StructShape(fields) =>
                for field in fields {
                  collect(field.value_type, read)
                }
              EnumShape(variants) =>
                for v in variants {
                  for p in v.parameters {
                    collect(p.value_type, read)
                  }
                }
            }
          }
        }
      _ => ()
    }
  }
  for item in exports {
    for p in item.parameters {
      collect(p.value_type, true)
    }
    if !(item.binding is ConstructorBinding(_)) {
      collect(item.return_type, false)
    }
  }
  if read {
    readers
  } else {
    writers
  }
}

///|
fn conversions(
  types : Array[ValueType],
  opposite : Array[ValueType],
  definitions : Array[TypeDefinition],
  read : Bool,
) -> String {
  let out = StringBuilder()
  for value in types {
    let name = conversion_name(value, types, read)
    let mbt = value.moonbit()
    if read {
      out.write_string(
        "\n///|\nfn \{name}(\n  env : NapiEnv,\n  value : NapiValue,\n  _path : Array[NapiValue],\n) -> \{mbt}\{if value is UnitType { "" } else { " raise" }} {\n",
      )
    } else {
      out.write_string(
        "\n///|\nfn \{name}(\n  env : NapiEnv,\n  value : \{mbt},\n  _depth : Int32,\n) -> NapiValue raise {\n",
      )
    }
    fn convert(t : ValueType, expression : String) -> String {
      conversion_name(t, types, read) +
      "(env, " +
      expression +
      (if read { ", _path)" } else { ", _depth + 1)" })
    }
    fn enter() -> Unit {
      out.write_string(
        if read {
          "  napi_enter_value(env, value, _path)\n  defer ignore(_path.pop())\n"
        } else {
          "  napi_check_depth(_depth)\n"
        },
      )
    }
    match value {
      AsyncIteratorType(inner) =>
        out.write_string(
          "  " +
          (if read { "get_" } else { "set_" }) +
          "NapiAsyncIterator(env, value, fn(env, value) { " +
          conversion_name(inner, types, read) +
          (if read { "(env, value, [])" } else { "(env, value, 0)" }) +
          " })\n",
        )
      JsPromiseType(inner) =>
        out.write_string(
          "  get_NapiJsPromise(env, value, fn(env, value) { " +
          conversion_name(inner, types, true) +
          "(env, value, []) })\n",
        )
      CallbackType(params, ret, _) =>
        out.write_string(
          callback_conversion(
            params,
            ret,
            if read {
              types
            } else {
              opposite
            },
            if read {
              opposite
            } else {
              types
            },
            read,
          ),
        )
      JsonType =>
        out.write_string(
          if read {
            "  napi_read_json(env, value, _path)\n"
          } else {
            "  napi_write_json(env, value, _depth)\n"
          },
        )
      MapType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let result : " +
            mbt +
            " = Map([])\n  for key in napi_object_keys(env, value) {\n    result[key] = " +
            convert(inner, "napi_key_get(env, value, key)") +
            "\n  }\n  result\n",
          )
        } else {
          out.write_string(
            "  let result = napi_object_new(env)\n  for key, item in value {\n    napi_key_set(env, result, key, " +
            convert(inner, "item") +
            ")\n  }\n  result\n",
          )
        }
      }
      SetType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let raw = napi_set_values(env, value)\n  let length = napi_array_length(env, raw)\n  NapiSet::new(Array::makei(length, i => " +
            convert(inner, "napi_array_get(env, raw, i)") +
            "))\n",
          )
        } else {
          out.write_string(
            "  let raw = napi_array_new(env, value.length())\n  for i, item in value.to_array() { napi_array_set(env, raw, i, " +
            convert(inner, "item") +
            ") }\n  napi_set_new(env, raw)\n",
          )
        }
      }
      IteratorType(inner) =>
        out.write_string(
          "  " +
          (if read { "get_" } else { "set_" }) +
          "NapiIterator(env, value, fn(env, value) { " +
          conversion_name(inner, types, read) +
          (if read { "(env, value, [])" } else { "(env, value, 0)" }) +
          " })\n",
        )
      TupleType(items) => {
        enter()
        if read {
          out.write_string(
            "  if napi_array_length(env, value) != \{items.length()} { raise napi_failure(1, TypeError, \"ERR_NAPI_TUPLE_LENGTH\", \"Unexpected tuple length\") }\n  (" +
            items
            .mapi((i, t) => convert(t, "napi_array_get(env, value, \{i})"))
            .join(", ") +
            ")\n",
          )
        } else {
          out.write_string(
            "  let result = napi_array_new(env, \{items.length()})\n",
          )
          for i, t in items {
            out.write_string(
              "  napi_array_set(env, result, \{i}, " +
              convert(t, "value.\{i}") +
              ")\n",
            )
          }
          out.write_string("  result\n")
        }
      }
      UnitType if read =>
        out.write_string("  ignore(env)\n  ignore(value)\n  ()\n")
      OptionType(inner) =>
        if read {
          out.write_string(
            "  if napi_is_nullish(env, value) { None } else { Some(" +
            convert(inner, "value") +
            ") }\n",
          )
        } else {
          out.write_string(
            "  match value { None => napi_null(env); Some(inner) => " +
            convert(inner, "inner") +
            " }\n",
          )
        }
      ArrayType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let length = napi_array_length(env, value)\n  Array::makei(length, i => " +
            convert(inner, "napi_array_get(env, value, i)") +
            ")\n",
          )
        } else {
          out.write_string(
            "  let result = napi_array_new(env, value.length())\n  for i, element in value { napi_array_set(env, result, i, " +
            convert(inner, "element") +
            ") }\n  result\n",
          )
        }
      }
      NamedType(name) =>
        for def in definitions {
          if def.name != name {
            continue
          }
          enter()
          match def.shape {
            StructShape(fields) =>
              if read {
                out.write_string("  napi_require_object(env, value)\n")
                out.write_string("  {\n")
                for field in fields {
                  let required = !(field.value_type is OptionType(_))
                  let expression = "napi_field_get(env, value, " +
                    Json(field.name).stringify() +
                    ", \{required})"
                  out.write_string(
                    "    \{field.name}: " +
                    convert(field.value_type, expression) +
                    ",\n",
                  )
                }
                out.write_string("  }\n")
              } else {
                out.write_string("  let result = napi_object_new(env)\n")
                for field in fields {
                  out.write_string(
                    "  napi_field_set(env, result, " +
                    Json(field.name).stringify() +
                    ", " +
                    convert(field.value_type, "value." + field.name) +
                    ")\n",
                  )
                }
                out.write_string("  result\n")
              }
            EnumShape(variants) => {
              let plain = variants.all(v => v.parameters.is_empty())
              if read {
                let tag = if plain {
                  "value"
                } else {
                  "napi_field_get(env, value, \"tag\", true)"
                }
                out.write_string("  let tag = get_String(env, " + tag + ")\n")
                if !plain {
                  out.write_string(
                    "  let args = napi_field_get(env, value, \"args\", true)\n  let count = napi_array_length(env, args)\n",
                  )
                }
                out.write_string("  match tag {\n")
                for v in variants {
                  out.write_string(
                    "    " + Json(v.name).stringify() + " => {\n",
                  )
                  if !plain {
                    out.write_string(
                      "      if count != \{v.parameters.length()} { raise napi_failure(1, TypeError, \"ERR_NAPI_ENUM_ARGS\", \"Wrong enum payload arity\") }\n",
                    )
                  }
                  let args = []
                  for i, p in v.parameters {
                    args.push(
                      (if p.name.is_empty() { "" } else { p.name + "=" }) +
                      convert(p.value_type, "napi_array_get(env, args, \{i})"),
                    )
                  }
                  out.write_string(
                    "      \{v.name}" +
                    (if args.is_empty() {
                      ""
                    } else {
                      "(" + args.join(", ") + ")"
                    }) +
                    "\n    }\n",
                  )
                }
                out.write_string(
                  "    _ => raise napi_failure(1, TypeError, \"ERR_NAPI_ENUM_TAG\", \"Unknown \{name} tag: \" + tag)\n  }\n",
                )
              } else {
                out.write_string("  match value {\n")
                for v in variants {
                  let args = []
                  for i, p in v.parameters {
                    args.push(
                      (if p.name.is_empty() { "" } else { p.name + "=" }) +
                      "p\{i}",
                    )
                  }
                  out.write_string(
                    "    \{v.name}" +
                    (if args.is_empty() {
                      ""
                    } else {
                      "(" + args.join(", ") + ")"
                    }) +
                    " => {\n",
                  )
                  if plain {
                    out.write_string(
                      "      set_String(env, " +
                      Json(v.name).stringify() +
                      ")\n",
                    )
                  } else {
                    out.write_string(
                      "      let result = napi_object_new(env)\n      napi_field_set(env, result, \"tag\", set_String(env, " +
                      Json(v.name).stringify() +
                      "))\n      let args = napi_array_new(env, \{v.parameters.length()})\n",
                    )
                    for i, p in v.parameters {
                      out.write_string(
                        "      napi_array_set(env, args, \{i}, " +
                        convert(p.value_type, "p\{i}") +
                        ")\n",
                      )
                    }
                    out.write_string(
                      "      napi_field_set(env, result, \"args\", args)\n      result\n",
                    )
                  }
                  out.write_string("    }\n")
                }
                out.write_string("  }\n")
              }
            }
          }
        }
      ClassType(_, _, id) =>
        if read {
          out.write_string(
            "  let handle = napi_class_handle(env, value, \{id})\n  napi_mbt_class_payload_\{id}(handle)\n",
          )
        } else {
          out.write_string(
            "  let result = Ref(moonbit_dummy_napi_value())\n  result_from_status(env, napi_mbt_class_create_\{id}(env, value, \{id}, result), b\"Creating native instance\")\n  result.val\n",
          )
        }
      _ =>
        out.write_string(
          "  " +
          (if read { "get_" } else { "set_" }) +
          value.runtime_name() +
          "(env, value)\n",
        )
    }
    out.write_string("}\n")
  }
  out.to_string()
}
