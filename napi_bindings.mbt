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
#borrow(code, msg)
extern "c" fn napi_throw_error(env : NapiEnv, code : Bytes, msg : Bytes) -> Int = "napi_throw_error"

// C 层的代理工具函数

///|
#borrow(name, result)
extern "c" fn moonbit_napi_create_add_function(
  env : NapiEnv,
  name : Bytes,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_add_function"
