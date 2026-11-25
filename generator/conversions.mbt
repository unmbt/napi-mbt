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
fn convert_read_expr(
  value : ValueType,
  expression : String,
  types : Array[ValueType],
  rt : String,
  path~ : String = "[]",
  typed~ : Bool = true,
) -> String {
  match value {
    EnvType => "env"
    RawValueType => expression
    _ if value.supports_trait(true) =>
      if typed {
        "(\{rt}napi_from_value(env, \{expression}) : \{value.moonbit_with(rt)})"
      } else {
        "\{rt}napi_from_value(env, \{expression})"
      }
    _ => "\{conversion_name(value, types, true)}(env, \{expression}, \{path})"
  }
}

///|
fn convert_write_expr(
  value : ValueType,
  expression : String,
  types : Array[ValueType],
  rt : String,
  depth~ : String = "0",
) -> String {
  match value {
    EnvType => "abort(\"NapiEnv cannot be returned\")"
    RawValueType => expression
    _ if value.supports_trait(false) => "\{rt}napi_to_value(env, \{expression})"
    _ => "\{conversion_name(value, types, false)}(env, \{expression}, \{depth})"
  }
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
    // Environments are injected directly, never read from a JS value.
    if value is EnvType {
      return
    }
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
      EitherType(left, right) => {
        collect(left, read)
        collect(right, read)
      }
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
  rt~ : String = "",
) -> String {
  let out = StringBuilder()
  fn convert(t : ValueType, expression : String) -> String {
    if read {
      convert_read_expr(t, expression, types, rt, path="_path", typed=true)
    } else {
      convert_write_expr(t, expression, types, rt, depth="_depth + 1")
    }
  }
  fn inner_callback_expr(inner : ValueType) -> String {
    if inner.supports_trait(read) {
      if read {
        "fn(env, value) { (\{rt}napi_from_value(env, value) : \{inner.moonbit_with(rt)}) }"
      } else {
        "fn(env, value) { \{rt}napi_to_value(env, value) }"
      }
    } else {
      "fn(env, value) { " +
      conversion_name(inner, types, read) +
      (if read { "(env, value, [])" } else { "(env, value, 0)" }) +
      " }"
    }
  }
  for value in types {
    match value {
      NamedType(name) => {
        for def in definitions {
          if def.name != name {
            continue
          }
          if read {
            out.write_string(
              "\n///|\npub impl \{rt}FromNapiValue for \{name} with from_napi_value(\n  env,\n  value,\n) {\n",
            )
          } else {
            out.write_string(
              "\n///|\npub impl \{rt}ToNapiValue for \{name} with to_napi_value(\n  self,\n  env,\n) {\n",
            )
          }
          match def.shape {
            StructShape(fields) =>
              if read {
                out.write_string(
                  "  \{rt}napi_with_cycle_guard(env, value, () => {\n    \{rt}napi_require_object(env, value)\n    {\n",
                )
                for field in fields {
                  let required = !(field.value_type is OptionType(_))
                  let expression = "\{rt}napi_field_get(env, value, " +
                    Json(field.name).stringify() +
                    ", \{required})"
                  out.write_string(
                    "      \{field.name}: " +
                    convert_read_expr(
                      field.value_type,
                      expression,
                      types,
                      rt,
                      typed=false,
                    ) +
                    ",\n",
                  )
                }
                out.write_string("    }\n  })\n")
              } else {
                out.write_string(
                  "  \{rt}napi_with_depth_guard(() => {\n    let result = \{rt}napi_object_new(env)\n",
                )
                for field in fields {
                  out.write_string(
                    "    \{rt}napi_field_set(env, result, " +
                    Json(field.name).stringify() +
                    ", " +
                    convert_write_expr(
                      field.value_type,
                      "self." + field.name,
                      types,
                      rt,
                    ) +
                    ")\n",
                  )
                }
                out.write_string("    result\n  })\n")
              }
            EnumShape(variants) => {
              let plain = variants.all(v => v.parameters.is_empty())
              if read {
                if !plain {
                  out.write_string(
                    "  \{rt}napi_with_cycle_guard(env, value, () => {\n",
                  )
                }
                let indent = if plain { "  " } else { "    " }
                let tag = if plain {
                  "value"
                } else {
                  "\{rt}napi_field_get(env, value, \"tag\", true)"
                }
                out.write_string(
                  "\{indent}let tag = \{rt}get_String(env, \{tag})\n",
                )
                if !plain {
                  out.write_string(
                    "\{indent}let args = \{rt}napi_field_get(env, value, \"args\", true)\n\{indent}let count = \{rt}napi_array_length(env, args)\n",
                  )
                }
                out.write_string("\{indent}match tag {\n")
                for v in variants {
                  let js_tag = v.js_value.unwrap_or(v.name)
                  out.write_string(
                    "\{indent}  " + Json(js_tag).stringify() + " => {\n",
                  )
                  if !plain {
                    out.write_string(
                      "\{indent}    if count != \{v.parameters.length()} { raise \{rt}napi_failure(1, TypeError, \"ERR_NAPI_ENUM_ARGS\", \"Wrong enum payload arity\") }\n",
                    )
                  }
                  let args = []
                  for i, p in v.parameters {
                    args.push(
                      (if p.name.is_empty() { "" } else { p.name + "=" }) +
                      convert_read_expr(
                        p.value_type,
                        "\{rt}napi_array_get(env, args, \{i})",
                        types,
                        rt,
                        typed=false,
                      ),
                    )
                  }
                  out.write_string(
                    "\{indent}    \{v.name}" +
                    (if args.is_empty() {
                      ""
                    } else {
                      "(" + args.join(", ") + ")"
                    }) +
                    "\n\{indent}  }\n",
                  )
                }
                out.write_string(
                  "\{indent}  _ => raise \{rt}napi_failure(1, TypeError, \"ERR_NAPI_ENUM_TAG\", \"Unknown \{name} tag: \" + tag)\n\{indent}}\n",
                )
                if !plain {
                  out.write_string("  })\n")
                }
              } else {
                if !plain {
                  out.write_string("  \{rt}napi_with_depth_guard(() => {\n")
                }
                let indent = if plain { "  " } else { "    " }
                out.write_string("\{indent}match self {\n")
                for v in variants {
                  let args = []
                  for i, p in v.parameters {
                    args.push(
                      (if p.name.is_empty() { "" } else { p.name + "=" }) +
                      "p\{i}",
                    )
                  }
                  out.write_string(
                    "\{indent}  \{v.name}" +
                    (if args.is_empty() {
                      ""
                    } else {
                      "(" + args.join(", ") + ")"
                    }) +
                    " => {\n",
                  )
                  if plain {
                    out.write_string(
                      "\{indent}    \{rt}set_String(env, " +
                      Json(v.js_value.unwrap_or(v.name)).stringify() +
                      ")\n",
                    )
                  } else {
                    out.write_string(
                      "\{indent}    let result = \{rt}napi_object_new(env)\n\{indent}    \{rt}napi_field_set(env, result, \"tag\", \{rt}set_String(env, " +
                      Json(v.name).stringify() +
                      "))\n\{indent}    let args = \{rt}napi_array_new(env, \{v.parameters.length()})\n",
                    )
                    for i, p in v.parameters {
                      out.write_string(
                        "\{indent}    \{rt}napi_array_set(env, args, \{i}, " +
                        convert_write_expr(p.value_type, "p\{i}", types, rt) +
                        ")\n",
                      )
                    }
                    out.write_string(
                      "\{indent}    \{rt}napi_field_set(env, result, \"args\", args)\n\{indent}    result\n",
                    )
                  }
                  out.write_string("\{indent}  }\n")
                }
                out.write_string("\{indent}}\n")
                if !plain {
                  out.write_string("  })\n")
                }
              }
            }
          }
          out.write_string("}\n")
        }
        continue
      }
      ClassType(type_name, _, id) => {
        if read {
          out.write_string(
            "\n///|\npub impl \{rt}FromNapiValue for \{type_name} with from_napi_value(\n  env,\n  value,\n) {\n  let handle = \{rt}napi_class_handle(env, value, \{id})\n  napi_mbt_class_payload_\{id}(handle)\n}\n",
          )
        } else {
          out.write_string(
            "\n///|\npub impl \{rt}ToNapiValue for \{type_name} with to_napi_value(\n  self,\n  env,\n) {\n  let result = Ref(\{rt}moonbit_dummy_napi_value())\n  \{rt}result_from_status(env, napi_mbt_class_create_\{id}(env, self, \{id}, result), b\"Creating native instance\")\n  result.val\n}\n",
          )
        }
        continue
      }
      _ => ()
    }
    if value.supports_trait(read) || value is (EnvType | RawValueType) {
      continue
    }
    let name = conversion_name(value, types, read)
    let mbt = value.moonbit_with(rt)
    if read {
      out.write_string(
        "\n///|\nfn \{name}(\n  env : \{rt}NapiEnv,\n  value : \{rt}NapiValue,\n  _path : Array[\{rt}NapiValue],\n) -> \{mbt} raise {\n",
      )
    } else {
      out.write_string(
        "\n///|\nfn \{name}(\n  env : \{rt}NapiEnv,\n  value : \{mbt},\n  _depth : Int32,\n) -> \{rt}NapiValue raise {\n",
      )
    }
    fn enter() -> Unit {
      out.write_string(
        if read {
          "  \{rt}napi_enter_value(env, value, _path)\n  defer ignore(_path.pop())\n"
        } else {
          "  \{rt}napi_check_depth(_depth)\n"
        },
      )
    }
    match value {
      AsyncIteratorType(inner) =>
        out.write_string(
          "  " +
          rt +
          (if read { "get_" } else { "set_" }) +
          "NapiAsyncIterator(env, value, " +
          inner_callback_expr(inner) +
          ")\n",
        )
      JsPromiseType(inner) =>
        out.write_string(
          "  \{rt}get_NapiJsPromise(env, value, " +
          inner_callback_expr(inner) +
          ")\n",
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
            rt~,
          ),
        )
      MapType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let result : " +
            mbt +
            " = Map([])\n  for key in \{rt}napi_object_keys(env, value) {\n    result[key] = " +
            convert(inner, "\{rt}napi_key_get(env, value, key)") +
            "\n  }\n  result\n",
          )
        } else {
          out.write_string(
            "  let result = \{rt}napi_object_new(env)\n  for key, item in value {\n    \{rt}napi_key_set(env, result, key, " +
            convert(inner, "item") +
            ")\n  }\n  result\n",
          )
        }
      }
      SetType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let raw = \{rt}napi_set_values(env, value)\n  let length = \{rt}napi_array_length(env, raw)\n  \{rt}NapiSet::new(Array::makei(length, i => " +
            convert(inner, "\{rt}napi_array_get(env, raw, i)") +
            "))\n",
          )
        } else {
          out.write_string(
            "  let raw = \{rt}napi_array_new(env, value.length())\n  for i, item in value.to_array() { \{rt}napi_array_set(env, raw, i, " +
            convert(inner, "item") +
            ") }\n  \{rt}napi_set_new(env, raw)\n",
          )
        }
      }
      IteratorType(inner) =>
        out.write_string(
          "  " +
          rt +
          (if read { "get_" } else { "set_" }) +
          "NapiIterator(env, value, " +
          inner_callback_expr(inner) +
          ")\n",
        )
      EitherType(left, right) =>
        if read {
          out.write_string(
            "  try {\n    A(" +
            convert(left, "value") +
            ")\n  } catch {\n    error => {\n      if error is \{rt}NapiError::JavaScriptException(_) ||\n        (\{rt}napi_is_exception_pending(env) catch { _ => false }) {\n        raise error\n      }\n      B(" +
            convert(right, "value") +
            ")\n    }\n  }\n",
          )
        } else {
          out.write_string(
            "  match value {\n    A(a) => " +
            convert(left, "a") +
            "\n    B(b) => " +
            convert(right, "b") +
            "\n  }\n",
          )
        }
      TupleType(items) => {
        enter()
        if read {
          out.write_string(
            "  if \{rt}napi_array_length(env, value) != \{items.length()} { raise \{rt}napi_failure(1, TypeError, \"ERR_NAPI_TUPLE_LENGTH\", \"Unexpected tuple length\") }\n  (" +
            items
            .mapi((i, t) => convert(t, "\{rt}napi_array_get(env, value, \{i})"))
            .join(", ") +
            ")\n",
          )
        } else {
          out.write_string(
            "  let result = \{rt}napi_array_new(env, \{items.length()})\n",
          )
          for i, t in items {
            out.write_string(
              "  \{rt}napi_array_set(env, result, \{i}, " +
              convert(t, "value.\{i}") +
              ")\n",
            )
          }
          out.write_string("  result\n")
        }
      }
      OptionType(inner) =>
        if read {
          out.write_string(
            "  if \{rt}napi_is_nullish(env, value) { None } else { Some(" +
            convert(inner, "value") +
            ") }\n",
          )
        } else {
          out.write_string(
            "  match value { None => \{rt}napi_null(env); Some(inner) => " +
            convert(inner, "inner") +
            " }\n",
          )
        }
      ArrayType(inner) => {
        enter()
        if read {
          out.write_string(
            "  let length = \{rt}napi_array_length(env, value)\n  Array::makei(length, i => " +
            convert(inner, "\{rt}napi_array_get(env, value, i)") +
            ")\n",
          )
        } else {
          out.write_string(
            "  let result = \{rt}napi_array_new(env, value.length())\n  for i, element in value { \{rt}napi_array_set(env, result, i, " +
            convert(inner, "element") +
            ") }\n  result\n",
          )
        }
      }
      _ =>
        abort("Unexpected non-trait conversion type: " + value.runtime_name())
    }
    out.write_string("}\n")
  }
  out.to_string()
}
