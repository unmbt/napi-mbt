///|
#borrow(result)
extern "c" fn napi_keys_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_keys"

///|
#borrow(result)
extern "c" fn napi_key_get_raw(
  env : NapiEnv,
  value : NapiValue,
  key : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_get_property"

///|
extern "c" fn napi_key_set_raw(
  env : NapiEnv,
  value : NapiValue,
  key : NapiValue,
  field : NapiValue,
) -> Int32 = "moonbit_napi_key_set"

///|
#borrow(result)
extern "c" fn napi_is_array_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Bool],
) -> Int32 = "moonbit_napi_is_array"

///|
pub fn napi_object_keys(
  env : NapiEnv,
  value : NapiValue,
) -> Array[String] raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_keys_raw(env, value, result),
    b"Reading own enumerable string keys",
  )
  Array::makei(napi_array_length(env, result.val), i => {
    get_String(env, napi_array_get(env, result.val, i))
  })
}

///|
pub fn napi_key_get(
  env : NapiEnv,
  value : NapiValue,
  key : String,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_key_get_raw(env, value, set_String(env, key), result),
    b"Reading record property",
  )
  result.val
}

///|
pub fn napi_key_set(
  env : NapiEnv,
  value : NapiValue,
  key : String,
  field : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_key_set_raw(env, value, set_String(env, key), field),
    b"Writing record property",
  )
}

///|
pub fn napi_read_json(
  env : NapiEnv,
  value : NapiValue,
  path : Array[NapiValue],
) -> Json raise NapiError {
  let kind = Ref(0)
  result_from_status(
    env,
    napi_value_kind(env, value, kind),
    b"Reading JSON kind",
  )
  match kind.val {
    1 => Json::null()
    2 => Json(get_Bool(env, value))
    3 => {
      let number = get_Double(env, value)
      if number.is_nan() || number.is_inf() {
        raise napi_failure(
          1,
          TypeError,
          "ERR_NAPI_JSON",
          "JSON numbers must be finite",
        )
      }
      Json(number)
    }
    4 => Json(get_String(env, value))
    6 => {
      napi_enter_value(env, value, path)
      defer ignore(path.pop())
      let array = Ref(false)
      result_from_status(
        env,
        napi_is_array_raw(env, value, array),
        b"Reading JSON array",
      )
      if array.val {
        Json::array(
          Array::makei(napi_array_length(env, value), i => {
            napi_read_json(env, napi_array_get(env, value, i), path)
          }),
        )
      } else {
        let fields : Map[String, Json] = Map([])
        for key in napi_object_keys(env, value) {
          fields[key] = napi_read_json(env, napi_key_get(env, value, key), path)
        }
        Json::object(fields)
      }
    }
    _ =>
      raise napi_failure(1, TypeError, "ERR_NAPI_JSON", "Expected a JSON value")
  }
}

///|
pub fn napi_write_json(
  env : NapiEnv,
  value : Json,
  depth : Int32,
) -> NapiValue raise NapiError {
  napi_check_depth(depth)
  match value {
    Null => napi_null(env)
    True => set_Bool(env, true)
    False => set_Bool(env, false)
    String(text) => set_String(env, text)
    Number(number, ..) => {
      if number.is_nan() || number.is_inf() {
        raise napi_failure(
          1,
          TypeError,
          "ERR_NAPI_JSON",
          "JSON numbers must be finite",
        )
      }
      set_Double(env, number)
    }
    Array(items) => {
      let result = napi_array_new(env, items.length())
      for i, item in items {
        napi_array_set(env, result, i, napi_write_json(env, item, depth + 1))
      }
      result
    }
    Object(fields) => {
      let result = napi_object_new(env)
      for key, item in fields {
        napi_key_set(env, result, key, napi_write_json(env, item, depth + 1))
      }
      result
    }
  }
}
