// 声明 N-API 基础函数的 FFI 绑定

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
extern "c" fn napi_get_undefined(env : NapiEnv, result : Ref[NapiValue]) -> Int = "napi_get_undefined"

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
) -> Int = "moonbit_napi_get_value_string_utf8"

///|
#borrow(result)
extern "c" fn napi_get_value_string_utf8_length(
  env : NapiEnv,
  value : NapiValue,
  buf : UnmanagedBuffer,
  bufsize : Int,
  result : Ref[Int],
) -> Int = "moonbit_napi_get_value_string_utf8_length"

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
) -> Int = "moonbit_napi_get_buffer_info"

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
extern "c" fn moonbit_dummy_deferred() -> NapiDeferred = "moonbit_dummy_deferred"

///|
#borrow(deferred, promise)
extern "c" fn napi_create_promise(
  env : NapiEnv,
  deferred : Ref[NapiDeferred],
  promise : Ref[NapiValue],
) -> Int = "napi_create_promise"

///|
extern "c" fn napi_resolve_deferred(
  env : NapiEnv,
  deferred : NapiDeferred,
  resolution : NapiValue,
) -> Int = "napi_resolve_deferred"

///|
extern "c" fn napi_reject_deferred(
  env : NapiEnv,
  deferred : NapiDeferred,
  rejection : NapiValue,
) -> Int = "napi_reject_deferred"

///|
#borrow(is_promise)
extern "c" fn napi_is_promise(
  env : NapiEnv,
  value : NapiValue,
  is_promise : Ref[Bool],
) -> Int = "moonbit_napi_is_promise"

///|
#borrow(result)
extern "c" fn napi_create_bigint_int64(
  env : NapiEnv,
  value : Int64,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_bigint_int64"

///|
#borrow(result)
extern "c" fn napi_create_bigint_uint64(
  env : NapiEnv,
  value : UInt64,
  result : Ref[NapiValue],
) -> Int = "moonbit_napi_create_bigint_uint64"

///|
#borrow(result, lossless)
extern "c" fn napi_get_value_bigint_int64(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int64],
  lossless : Ref[Bool],
) -> Int = "moonbit_napi_get_value_bigint_int64"

///|
#borrow(result, lossless)
extern "c" fn napi_get_value_bigint_uint64(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[UInt64],
  lossless : Ref[Bool],
) -> Int = "moonbit_napi_get_value_bigint_uint64"

///|
extern "c" fn napi_threadsafe_function_dummy() -> NapiThreadsafeFunction = "moonbit_dummy_threadsafe_function"

///|
#borrow(result)
extern "c" fn napi_create_threadsafe_function(
  env : NapiEnv,
  func : NapiValue,
  async_resource : NapiValue,
  async_resource_name : NapiValue,
  max_queue_size : Int,
  initial_thread_count : Int,
  thread_finalize_data : UnmanagedBuffer,
  thread_finalize_cb : UnmanagedBuffer,
  context : UnmanagedBuffer,
  call_js_cb : UnmanagedBuffer,
  result : Ref[NapiThreadsafeFunction],
) -> Int = "moonbit_napi_create_threadsafe_function"

///|
extern "c" fn napi_call_threadsafe_function(
  func : NapiThreadsafeFunction,
  data : UnmanagedBuffer,
  mode : Int,
) -> Int = "moonbit_napi_call_threadsafe_function"

///|
extern "c" fn napi_acquire_threadsafe_function(
  func : NapiThreadsafeFunction,
) -> Int = "moonbit_napi_acquire_threadsafe_function"

///|
extern "c" fn napi_release_threadsafe_function(
  func : NapiThreadsafeFunction,
  mode : Int,
) -> Int = "moonbit_napi_release_threadsafe_function"
