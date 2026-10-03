///|
/// Promise support is available in Node-API v1.
pub fn napi_promise_new(env : NapiEnv) -> NapiPromise {
  let deferred = Ref(moonbit_dummy_deferred())
  let promise = Ref(moonbit_dummy_napi_value())
  let status = napi_create_promise(env, deferred, promise)
  result_from_status(env, status, b"Failed to create Promise")
  { promise: promise.val, deferred: deferred.val, }
}

///|
pub fn napi_promise_resolve(
  env : NapiEnv,
  promise : NapiPromise,
  value : NapiValue,
) -> Unit {
  let status = napi_resolve_deferred(env, promise.deferred, value)
  result_from_status(env, status, b"Failed to resolve Promise")
}

///|
pub fn napi_promise_reject(
  env : NapiEnv,
  promise : NapiPromise,
  reason : NapiValue,
) -> Unit {
  let status = napi_reject_deferred(env, promise.deferred, reason)
  result_from_status(env, status, b"Failed to reject Promise")
}

///|
/// Returns whether a value is a JavaScript Promise.
pub fn napi_promise_is(env : NapiEnv, value : NapiValue) -> Bool {
  let result = Ref(false)
  let status = napi_is_promise(env, value, result)
  result_from_status(env, status, b"Failed to inspect Promise")
  result.val
}

///|
pub fn napi_bigint_from_int64(env : NapiEnv, value : Int64) -> NapiValue {
  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_create_bigint_int64(env, value, result)
  result_from_status(env, status, b"Failed to create BigInt")
  result.val
}

///|
pub fn napi_bigint_from_uint64(env : NapiEnv, value : UInt64) -> NapiValue {
  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_create_bigint_uint64(env, value, result)
  result_from_status(env, status, b"Failed to create BigInt")
  result.val
}

///|
/// Reads a signed BigInt and returns the value plus the lossless flag.
pub fn napi_bigint_to_int64(env : NapiEnv, value : NapiValue) -> (Int64, Bool) {
  let result = Ref(0L)
  let lossless = Ref(false)
  let status = napi_get_value_bigint_int64(env, value, result, lossless)
  result_from_status(env, status, b"Failed to read BigInt")
  (result.val, lossless.val)
}

///|
/// Reads an unsigned BigInt and returns the value plus the lossless flag.
pub fn napi_bigint_to_uint64(
  env : NapiEnv,
  value : NapiValue,
) -> (UInt64, Bool) {
  let result = Ref(0UL)
  let lossless = Ref(false)
  let status = napi_get_value_bigint_uint64(env, value, result, lossless)
  result_from_status(env, status, b"Failed to read BigInt")
  (result.val, lossless.val)
}

///|
/// Threadsafe Function lifecycle helper. Threadsafe Functions require N-API v4.
pub fn napi_threadsafe_function_release(
  func : NapiThreadsafeFunction,
  mode : Int,
) -> Unit {
  let status = napi_release_threadsafe_function(func, mode)
  if status != 0 {
    abort("Failed to release Threadsafe Function")
  }
}

///|
/// Creates a Threadsafe Function. Callback pointers are opaque unmanaged
/// pointers supplied by a C layer.
pub fn napi_threadsafe_function_create(
  env : NapiEnv,
  func : NapiValue,
  async_resource : NapiValue,
  async_resource_name : NapiValue,
  max_queue_size : Int,
  initial_thread_count : Int,
  finalize_data : UnmanagedBuffer,
  finalize_cb : UnmanagedBuffer,
  context : UnmanagedBuffer,
  call_js_cb : UnmanagedBuffer,
) -> NapiThreadsafeFunction {
  let result = Ref(napi_threadsafe_function_dummy())
  let status = napi_create_threadsafe_function(
    env, func, async_resource, async_resource_name, max_queue_size, initial_thread_count,
    finalize_data, finalize_cb, context, call_js_cb, result,
  )
  result_from_status(env, status, b"Failed to create Threadsafe Function")
  result.val
}

///|
pub fn napi_threadsafe_function_call(
  func : NapiThreadsafeFunction,
  data : UnmanagedBuffer,
  mode : Int,
) -> Unit {
  let status = napi_call_threadsafe_function(func, data, mode)
  if status != 0 {
    abort("Failed to call Threadsafe Function")
  }
}

///|
pub fn napi_threadsafe_function_acquire(func : NapiThreadsafeFunction) -> Unit {
  let status = napi_acquire_threadsafe_function(func)
  if status != 0 {
    abort("Failed to acquire Threadsafe Function")
  }
}
