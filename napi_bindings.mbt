// 声明 N-API 基础函数的 FFI 绑定

///|
#borrow(arg0, arg1)
extern "c" fn moonbit_napi_get_cb_info_2(
  env : NapiEnv,
  info : NapiCallbackInfo,
  arg0 : Ref[NapiValue],
  arg1 : Ref[NapiValue],
) -> Int = "moonbit_napi_get_cb_info_2"

///|
#borrow(argc, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15)
extern "c" fn moonbit_napi_get_cb_info_max(
  env : NapiEnv,
  info : NapiCallbackInfo,
  argc : Ref[Int],
  a0 : Ref[NapiValue], a1 : Ref[NapiValue], a2 : Ref[NapiValue], a3 : Ref[NapiValue],
  a4 : Ref[NapiValue], a5 : Ref[NapiValue], a6 : Ref[NapiValue], a7 : Ref[NapiValue],
  a8 : Ref[NapiValue], a9 : Ref[NapiValue], a10 : Ref[NapiValue], a11 : Ref[NapiValue],
  a12 : Ref[NapiValue], a13 : Ref[NapiValue], a14 : Ref[NapiValue], a15 : Ref[NapiValue]
) -> Int = "moonbit_napi_get_cb_info_max"

///|
#borrow(result)
extern "c" fn napi_get_value_int32(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int],
) -> Int = "napi_get_value_int32"

///|
#borrow(result)
extern "c" fn napi_create_int32(
  env : NapiEnv,
  value : Int,
  result : Ref[NapiValue],
) -> Int = "napi_create_int32"

///|
#borrow(result)
extern "c" fn napi_get_value_double(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Double],
) -> Int = "napi_get_value_double"

///|
#borrow(result)
extern "c" fn napi_create_double(
  env : NapiEnv,
  value : Double,
  result : Ref[NapiValue],
) -> Int = "napi_create_double"

///|
#borrow(result)
extern "c" fn napi_get_value_bool(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Bool],
) -> Int = "napi_get_value_bool"

///|
#borrow(result)
extern "c" fn napi_get_boolean(
  env : NapiEnv,
  value : Bool,
  result : Ref[NapiValue],
) -> Int = "napi_get_boolean"

///|
#borrow(result)
extern "c" fn napi_get_undefined(
  env : NapiEnv,
  result : Ref[NapiValue],
) -> Int = "napi_get_undefined"

///|
#borrow(utf8name)
extern "c" fn napi_set_named_property(
  env : NapiEnv,
  object : NapiValue,
  utf8name : Bytes,
  value : NapiValue,
) -> Int = "napi_set_named_property"

///|
#borrow(buf, result)
extern "c" fn napi_get_value_string_utf8(
  env : NapiEnv,
  value : NapiValue,
  buf : Bytes,
  bufsize : Int,
  result : Ref[Int],
) -> Int = "napi_get_value_string_utf8"

///|
#borrow(result)
extern "c" fn napi_get_value_string_utf8_length(
  env : NapiEnv,
  value : NapiValue,
  buf : UnmanagedBuffer,
  bufsize : Int,
  result : Ref[Int],
) -> Int = "napi_get_value_string_utf8"

///|
#borrow(str, result)
extern "c" fn napi_create_string_utf8(
  env : NapiEnv,
  str : Bytes,
  length : Int,
  result : Ref[NapiValue],
) -> Int = "napi_create_string_utf8"

///|
#borrow(result)
extern "c" fn napi_get_value_external(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int],
) -> Int = "napi_get_value_external"

///|
#borrow(result)
extern "c" fn moonbit_napi_create_external_id(
  env : NapiEnv,
  id : Int,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_external_id"

///|
#borrow(result)
extern "c" fn moonbit_napi_create_external_buffer(
  env : NapiEnv,
  length : Int,
  data : UnmanagedBuffer,
  id : Int,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_external_buffer"

///|
#borrow(data, length)
extern "c" fn napi_get_buffer_info(
  env : NapiEnv,
  value : NapiValue,
  data : Ref[UnmanagedBuffer],
  length : Ref[Int],
) -> Int = "napi_get_buffer_info"

///|
extern "c" fn UnmanagedBuffer::load8(
  self : UnmanagedBuffer,
  offset : Int,
) -> Int = "moonbit_ptr_load8"

///|
extern "c" fn UnmanagedBuffer::store8(
  self : UnmanagedBuffer,
  offset : Int,
  val : Int,
) = "moonbit_ptr_store8"

///|
#borrow(code, msg)
extern "c" fn napi_throw_error(env : NapiEnv, code : Bytes, msg : Bytes) -> Int = "napi_throw_error"

///|
#borrow(data, result, result_data)
extern "c" fn napi_create_buffer_copy(
  env : NapiEnv,
  length : Int,
  data : Bytes,
  result_data : Ref[UnmanagedBuffer],
  result : Ref[NapiValue],
) -> Int = "napi_create_buffer_copy"

///|
extern "c" fn moonbit_dummy_napi_value() -> NapiValue = "moonbit_dummy_napi_value"

///|
extern "c" fn moonbit_dummy_unmanaged_buffer() -> UnmanagedBuffer = "moonbit_dummy_unmanaged_buffer"

///|
#borrow(utf8name, result)
extern "c" fn moonbit_napi_create_func(
  env : NapiEnv,
  utf8name : Bytes,
  id : Int,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_func"

