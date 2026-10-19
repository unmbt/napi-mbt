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
) -> String {
  let out = StringBuilder()
  if read {
    out.write_string("  let callback = NapiCallback::new(env, value)\n  fn(")
    out.write_string(params.mapi((i, p) => "p\{i} : " + p.moonbit()).join(", "))
    out.write_string(
      ") raise {\n    let env = callback.environment()\n    let args = napi_array_new(env, \{params.length()})\n",
    )
    for i, p in params {
      out.write_string(
        "    napi_array_set(env, args, \{i}, \{conversion_name(p, writers, false)}(env, p\{i}, 0))\n",
      )
    }
    out.write_string(
      "    let result = callback.call(args)\n    \{conversion_name(ret, readers, true)}(env, result, [])\n  }\n",
    )
  } else {
    let mut required = 0
    for i, p in params {
      if !(p is OptionType(_)) {
        required = i + 1
      }
    }
    out.write_string(
      "  napi_closure_new(env, fn(env, args) {\n    try {\n      args.require(\{required})\n",
    )
    for i, p in params {
      out.write_string(
        "      let p\{i} = \{conversion_name(p, readers, true)}(env, args.get(env, \{i}), [])\n",
      )
    }
    out.write_string(
      "      let result = value(" +
      params.mapi((i, _) => "p\{i}").join(", ") +
      ")\n      \{conversion_name(ret, writers, false)}(env, result, 0)\n    } catch { error => { throw_napi_error(env, error); moonbit_dummy_napi_value() } }\n  })\n",
    )
  }
  out.to_string()
}
