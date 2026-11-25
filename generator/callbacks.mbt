///|
fn matching_paren(text : String) -> Int32 {
  let mut depth = 0
  for i, c in text {
    if c == '(' {
      depth += 1
    }
    if c == ')' {
      depth -= 1
      if depth == 0 {
        return i
      }
    }
  }
  -1
}

///|
fn split_type_arguments(text : String) -> Array[String] {
  if text.is_empty() {
    return []
  }
  let result = []
  let mut depth = 0
  let mut start = 0
  for i, c in text {
    if c == '(' || c == '[' {
      depth += 1
    }
    if c == ')' || c == ']' {
      depth -= 1
    }
    if c == ',' && depth == 0 {
      result.push(text[start:i].to_owned())
      start = i + 1
    }
  }
  result.push(text[start:].to_owned())
  result
}

///|
fn callback_conversion(
  params : Array[ValueType],
  ret : ValueType,
  readers : Array[ValueType],
  writers : Array[ValueType],
  read : Bool,
  rt~ : String = "",
) -> String {
  let out = StringBuilder()
  if read {
    out.write_string(
      "  let callback = \{rt}NapiCallback::new(env, value)\n  fn(",
    )
    out.write_string(
      params.mapi((i, p) => "p\{i} : " + p.moonbit_with(rt)).join(", "),
    )
    out.write_string(") raise {\n    let env = callback.environment()\n")
    let argv = params
      .mapi((i, p) => convert_write_expr(p, "p\{i}", writers, rt))
      .join(", ")
    out.write_string(
      "    let result = callback.call_argv([\{argv}])\n    " +
      convert_read_expr(ret, "result", readers, rt, typed=true) +
      "\n  }\n",
    )
  } else {
    let mut required = 0
    for i, p in params {
      if !(p is OptionType(_)) {
        required = i + 1
      }
    }
    out.write_string(
      "  \{rt}napi_closure_new(env, fn(env, args) {\n    try {\n      args.require(\{required})\n",
    )
    for i, p in params {
      out.write_string(
        "      let p\{i} : \{p.moonbit_with(rt)} = \{convert_read_expr(p, "args.get(env, \{i})", readers, rt, typed=false)}\n",
      )
    }
    out.write_string(
      "      let result : \{ret.moonbit_with(rt)} = value(" +
      params.mapi((i, _) => "p\{i}").join(", ") +
      ")\n      \{convert_write_expr(ret, "result", writers, rt)}\n    } catch { error => { \{rt}throw_napi_error(env, error); \{rt}moonbit_dummy_napi_value() } }\n  })\n",
    )
  }
  out.to_string()
}
