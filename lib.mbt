// Dummy placeholder to represent a null value temporarily

///|
extern "c" fn moonbit_dummy_napi_value() -> NapiValue = "moonbit_dummy_napi_value"

///|
pub fn add(a : Int, b : Int) -> Int {
  a + b
}

///|
fn result_from_status(env : NapiEnv, status : Int, msg : Bytes) -> Unit {
  if status != 0 {
    let _ = napi_throw_error(env, b"", msg)
    ()
  }
}

// 供 C stub 调用的包装函数

///|
pub fn moonbit_add_wrapper(env : NapiEnv, info : NapiCallbackInfo) -> NapiValue {
  let arg0 = Ref(moonbit_dummy_napi_value())
  let arg1 = Ref(moonbit_dummy_napi_value())

  let status = moonbit_napi_get_cb_info_2(env, info, arg0, arg1)
  result_from_status(env, status, b"Failed to get arguments")

  let val0 = Ref(0)
  let status = napi_get_value_int32(env, arg0.val, val0)
  result_from_status(env, status, b"Invalid argument 0, expected int32")

  let val1 = Ref(0)
  let status = napi_get_value_int32(env, arg1.val, val1)
  result_from_status(env, status, b"Invalid argument 1, expected int32")

  let sum = add(val0.val, val1.val)

  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_create_int32(env, sum, result)
  result_from_status(env, status, b"Failed to create result")

  result.val
}

///|
pub fn moonbit_napi_init(env : NapiEnv, exports : NapiValue) -> NapiValue {
  let func = Ref(moonbit_dummy_napi_value())
  let status = moonbit_napi_create_add_function(env, b"add\x00", func)
  result_from_status(env, status, b"Failed to create function 'add'")

  let status = napi_set_named_property(env, exports, b"add\x00", func.val)
  result_from_status(env, status, b"Failed to set property 'add'")

  exports
}
