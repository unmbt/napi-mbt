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

// C 层的代理工具函数
