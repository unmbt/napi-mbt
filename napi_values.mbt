///|
#borrow(result)
extern "c" fn napi_value_kind(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int32],
) -> Int32 = "moonbit_napi_value_kind"

///|
#borrow(result)
extern "c" fn napi_value_same(
  env : NapiEnv,
  a : NapiValue,
  b : NapiValue,
  result : Ref[Bool],
) -> Int32 = "moonbit_napi_value_same"

///|
#borrow(result)
extern "c" fn napi_null_raw(env : NapiEnv, result : Ref[NapiValue]) -> Int32 = "napi_get_null"

///|
#borrow(result)
extern "c" fn napi_array_length_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int32],
) -> Int32 = "moonbit_napi_array_length"

///|
#borrow(result)
extern "c" fn napi_array_new_raw(
  env : NapiEnv,
  length : Int32,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_array_new"

///|
#borrow(result)
extern "c" fn napi_array_get_raw(
  env : NapiEnv,
  value : NapiValue,
  index : Int32,
  result : Ref[NapiValue],
) -> Int32 = "napi_get_element"

///|
extern "c" fn napi_array_set_raw(
  env : NapiEnv,
  value : NapiValue,
  index : Int32,
  element : NapiValue,
) -> Int32 = "napi_set_element"

///|
#borrow(result)
extern "c" fn napi_object_new_raw(
  env : NapiEnv,
  result : Ref[NapiValue],
) -> Int32 = "napi_create_object"

///|
#borrow(name, result)
extern "c" fn napi_field_get_raw(
  env : NapiEnv,
  value : NapiValue,
  name : Bytes,
  required : Bool,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_field_get"

///|
#borrow(name)
extern "c" fn napi_field_set_raw(
  env : NapiEnv,
  value : NapiValue,
  name : Bytes,
  field : NapiValue,
) -> Int32 = "moonbit_napi_field_set"

///|
pub fn napi_is_nullish(
  env : NapiEnv,
  value : NapiValue,
) -> Bool raise NapiError {
  let kind = Ref(0)
  result_from_status(
    env,
    napi_value_kind(env, value, kind),
    b"Inspecting optional value",
  )
  kind.val == 0 || kind.val == 1
}

///|
pub fn napi_require_object(
  env : NapiEnv,
  value : NapiValue,
) -> Unit raise NapiError {
  let kind = Ref(0)
  result_from_status(
    env,
    napi_value_kind(env, value, kind),
    b"Inspecting object",
  )
  if kind.val != 6 {
    raise napi_failure(2, TypeError, "ERR_NAPI_TYPE", "Expected object")
  }
}

///|
pub fn napi_null(env : NapiEnv) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(env, napi_null_raw(env, result), b"Creating null")
  result.val
}

///|
// A path belongs to one synchronous conversion, including reentrant getters.
// Repeated references in different branches are allowed; actual cycles are not.
pub fn napi_enter_value(
  env : NapiEnv,
  value : NapiValue,
  path : Array[NapiValue],
) -> Unit raise NapiError {
  if path.length() >= 256 {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_DEPTH",
      "Structured value exceeds maximum nesting depth",
    )
  }
  for ancestor in path {
    let same = Ref(false)
    result_from_status(
      env,
      napi_value_same(env, ancestor, value, same),
      b"Checking structured value identity",
    )
    if same.val {
      raise napi_failure(
        1,
        TypeError,
        "ERR_NAPI_CYCLE",
        "Cyclic JavaScript input",
      )
    }
  }
  path.push(value)
}

///|
pub fn napi_check_depth(depth : Int32) -> Unit raise NapiError {
  if depth >= 256 {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_DEPTH",
      "Structured result exceeds maximum nesting depth",
    )
  }
}

///|
pub fn napi_array_length(
  env : NapiEnv,
  value : NapiValue,
) -> Int32 raise NapiError {
  let result = Ref(0)
  result_from_status(
    env,
    napi_array_length_raw(env, value, result),
    b"Expected Array",
  )
  result.val
}

///|
pub fn napi_array_new(
  env : NapiEnv,
  length : Int32,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_array_new_raw(env, length, result),
    b"Creating Array",
  )
  result.val
}

///|
pub fn napi_array_get(
  env : NapiEnv,
  value : NapiValue,
  index : Int32,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_array_get_raw(env, value, index, result),
    b"Reading Array element",
  )
  result.val
}

///|
pub fn napi_array_set(
  env : NapiEnv,
  value : NapiValue,
  index : Int32,
  element : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_array_set_raw(env, value, index, element),
    b"Writing Array element",
  )
}

///|
pub fn napi_object_new(env : NapiEnv) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(env, napi_object_new_raw(env, result), b"Creating Object")
  result.val
}

///|
pub fn napi_field_get(
  env : NapiEnv,
  value : NapiValue,
  name : String,
  required : Bool,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_field_get_raw(
    env,
    value,
    @utf8.encode(name),
    required,
    result,
  )
  if status == 1003 {
    raise napi_failure(
      status,
      TypeError,
      "ERR_NAPI_FIELD",
      "Missing required field: " + name,
    )
  }
  result_from_status(env, status, @utf8.encode("Reading field: " + name))
  result.val
}

///|
pub fn napi_field_set(
  env : NapiEnv,
  value : NapiValue,
  name : String,
  field : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_field_set_raw(env, value, @utf8.encode(name), field),
    @utf8.encode("Writing field: " + name),
  )
}

///|
pub fn get_Int64(env : NapiEnv, value : NapiValue) -> Int64 raise NapiError {
  let (result, lossless) = napi_bigint_to_int64(env, value)
  if !lossless {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_BIGINT_RANGE",
      "BigInt does not fit Int64 losslessly",
    )
  }
  result
}

///|
pub fn get_UInt64(env : NapiEnv, value : NapiValue) -> UInt64 raise NapiError {
  let (result, lossless) = napi_bigint_to_uint64(env, value)
  if !lossless {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_BIGINT_RANGE",
      "BigInt does not fit UInt64 losslessly",
    )
  }
  result
}

///|
pub fn set_Int64(env : NapiEnv, value : Int64) -> NapiValue raise NapiError {
  napi_bigint_from_int64(env, value)
}

///|
pub fn set_UInt64(env : NapiEnv, value : UInt64) -> NapiValue raise NapiError {
  napi_bigint_from_uint64(env, value)
}
