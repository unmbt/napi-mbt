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

// 帮助函数：从 napi_value 提取 String

///|
fn get_string(env : NapiEnv, val : NapiValue) -> String {
  let len = Ref(0)
  // 先获取需要的长度
  let status = napi_get_value_string_utf8_length(
    env,
    val,
    moonbit_dummy_unmanaged_buffer(),
    0,
    len,
  )
  result_from_status(env, status, b"Failed to get string length")

  // 加上 '\0' 的长度
  let buf = Bytes::make(len.val + 1, b'\x00')
  let status2 = napi_get_value_string_utf8(env, val, buf, len.val + 1, len)
  result_from_status(env, status2, b"Failed to read string")

  let mut s = ""
  for i = 0; i < len.val; i = i + 1 {
    let c = buf[i]
    if c != b'\x00' {
      s = s + c.to_int().unsafe_to_char().to_string()
    }
  }

  s
}

///|
pub fn moonbit_concat_wrapper(
  env : NapiEnv,
  info : NapiCallbackInfo,
) -> NapiValue {
  let arg0 = Ref(moonbit_dummy_napi_value())
  let arg1 = Ref(moonbit_dummy_napi_value())
  let status = moonbit_napi_get_cb_info_2(env, info, arg0, arg1)
  result_from_status(env, status, b"Failed to get args")

  let s0 = get_string(env, arg0.val)
  let s1 = get_string(env, arg1.val)

  let res_str = s0 + s1
  let res_bytes = @utf8.encode(res_str)
  let result = Ref(moonbit_dummy_napi_value())
  let status2 = napi_create_string_utf8(
    env,
    res_bytes,
    res_bytes.length(),
    result,
  )
  result_from_status(env, status2, b"Failed to create string")

  result.val
}

///|
pub fn moonbit_create_obj_wrapper(
  env : NapiEnv,
  info : NapiCallbackInfo,
) -> NapiValue {
  let arg0 = Ref(moonbit_dummy_napi_value())
  let arg1 = Ref(moonbit_dummy_napi_value()) // unused but get_cb_info_2 needs it
  let _ = moonbit_napi_get_cb_info_2(env, info, arg0, arg1)

  let s = get_string(env, arg0.val)
  let id = registry_retain(s)

  let result = Ref(moonbit_dummy_napi_value())
  let status = moonbit_napi_create_external_id(env, id, result)
  result_from_status(env, status, b"Failed to create external")

  result.val
}

///|
pub fn moonbit_read_obj_wrapper(
  env : NapiEnv,
  info : NapiCallbackInfo,
) -> NapiValue {
  let arg0 = Ref(moonbit_dummy_napi_value())
  let arg1 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_get_cb_info_2(env, info, arg0, arg1)

  let id_ref = Ref(0)
  let status = napi_get_value_external(env, arg0.val, id_ref)
  result_from_status(env, status, b"Failed to get external")

  let obj = registry_get(id_ref.val)
  let res_str = match obj {
    Some(s) => s
    None => "Object has been collected!"
  }

  let res_bytes = @utf8.encode(res_str)
  let result = Ref(moonbit_dummy_napi_value())
  let _ = napi_create_string_utf8(env, res_bytes, res_bytes.length(), result)
  result.val
}

///|
pub fn moonbit_mutate_buf_wrapper(
  env : NapiEnv,
  info : NapiCallbackInfo,
) -> NapiValue {
  let arg0 = Ref(moonbit_dummy_napi_value())
  let arg1 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_get_cb_info_2(env, info, arg0, arg1)

  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, arg0.val, unmanaged, len)
  result_from_status(env, status, b"Failed to get buffer")

  if len.val > 0 {
    let buf = unmanaged.val
    let old_val = buf.load8(0)
    buf.store8(0, old_val + 1)
  }

  arg0.val
}

///|
extern "c" fn moonbit_dummy_unmanaged_buffer() -> UnmanagedBuffer = "moonbit_dummy_napi_value"

///|
#borrow(name, result)
extern "c" fn moonbit_napi_create_func(
  env : NapiEnv,
  name : Bytes,
  kind : Int,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_func"

///|
pub fn moonbit_napi_init(env : NapiEnv, exports : NapiValue) -> NapiValue {
  let func = Ref(moonbit_dummy_napi_value())
  let status = moonbit_napi_create_func(env, b"add\x00", 0, func)
  result_from_status(env, status, b"Failed to create function 'add'")
  let _ = napi_set_named_property(env, exports, b"add\x00", func.val)

  let func2 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_create_func(env, b"concat\x00", 1, func2)
  let _ = napi_set_named_property(env, exports, b"concat\x00", func2.val)

  let func3 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_create_func(env, b"create_obj\x00", 2, func3)
  let _ = napi_set_named_property(env, exports, b"create_obj\x00", func3.val)

  let func4 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_create_func(env, b"read_obj\x00", 3, func4)
  let _ = napi_set_named_property(env, exports, b"read_obj\x00", func4.val)

  let func5 = Ref(moonbit_dummy_napi_value())
  let _ = moonbit_napi_create_func(env, b"mutate_buffer\x00", 4, func5)
  let _ = napi_set_named_property(env, exports, b"mutate_buffer\x00", func5.val)

  exports
}
