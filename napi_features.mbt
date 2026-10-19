///|
/// Promise support is available in Node-API v1.
pub fn napi_promise_new(env : NapiEnv) -> NapiPromise raise NapiError {
  let deferred = Ref(moonbit_dummy_deferred())
  let promise = Ref(moonbit_dummy_napi_value())
  let status = napi_create_promise(env, deferred, promise)
  result_from_status(env, status, b"Failed to create Promise")
  { promise: promise.val, deferred: deferred.val, settled: false, }
}

///|
pub fn napi_promise_resolve(
  env : NapiEnv,
  promise : NapiPromise,
  value : NapiValue,
) -> Unit raise NapiError {
  if promise.settled {
    raise napi_failure(
      1,
      Error,
      "ERR_NAPI_PROMISE_SETTLED",
      "Promise has already settled",
    )
  }
  promise.settled = true
  let status = napi_resolve_deferred(env, promise.deferred, value)
  result_from_status(env, status, b"Failed to resolve Promise")
}

///|
pub fn napi_promise_reject(
  env : NapiEnv,
  promise : NapiPromise,
  reason : NapiValue,
) -> Unit raise NapiError {
  if promise.settled {
    raise napi_failure(
      1,
      Error,
      "ERR_NAPI_PROMISE_SETTLED",
      "Promise has already settled",
    )
  }
  promise.settled = true
  let status = napi_reject_deferred(env, promise.deferred, reason)
  result_from_status(env, status, b"Failed to reject Promise")
}

///|
/// Returns whether a value is a JavaScript Promise.
pub fn napi_promise_is(
  env : NapiEnv,
  value : NapiValue,
) -> Bool raise NapiError {
  let result = Ref(false)
  let status = napi_is_promise(env, value, result)
  result_from_status(env, status, b"Failed to inspect Promise")
  result.val
}

///|
pub fn napi_bigint_from_int64(
  env : NapiEnv,
  value : Int64,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_create_bigint_int64(env, value, result)
  result_from_status(env, status, b"Failed to create BigInt")
  result.val
}

///|
pub fn napi_bigint_from_uint64(
  env : NapiEnv,
  value : UInt64,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  let status = napi_create_bigint_uint64(env, value, result)
  result_from_status(env, status, b"Failed to create BigInt")
  result.val
}

///|
/// Reads a signed BigInt and returns the value plus the lossless flag.
pub fn napi_bigint_to_int64(
  env : NapiEnv,
  value : NapiValue,
) -> (Int64, Bool) raise NapiError {
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
) -> (UInt64, Bool) raise NapiError {
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
  mode : NapiTsfnReleaseMode,
) -> NapiTsfnStatus raise NapiError {
  let mode = match mode {
    Release => 0
    Abort => 1
  }
  let status = napi_release_threadsafe_function(func, mode)
  tsfn_status(status, "Failed to release Threadsafe Function")
}

///|
/// Creates a Threadsafe Function. Callback pointers are opaque unmanaged
/// pointers supplied by a C layer.
pub fn napi_threadsafe_function_create(
  env : NapiEnv,
  func : NapiValue,
  async_resource : NapiValue,
  async_resource_name : NapiValue,
  max_queue_size : Int32,
  initial_thread_count : Int32,
  finalize_data : UnmanagedBuffer,
  finalize_cb : UnmanagedBuffer,
  context : UnmanagedBuffer,
  call_js_cb : UnmanagedBuffer,
) -> NapiThreadsafeFunction raise NapiError {
  if max_queue_size < 0 || initial_thread_count <= 0 {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_TSFN_OPTIONS",
      "TSFN needs nonnegative queue size and positive thread count",
    )
  }
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
  mode : NapiTsfnCallMode,
) -> NapiTsfnStatus raise NapiError {
  let mode = match mode {
    Nonblocking => 0
    Blocking => 1
  }
  let status = napi_call_threadsafe_function(func, data, mode)
  tsfn_status(status, "Failed to call Threadsafe Function")
}

///|
pub fn napi_threadsafe_function_acquire(
  func : NapiThreadsafeFunction,
) -> NapiTsfnStatus raise NapiError {
  let status = napi_acquire_threadsafe_function(func)
  tsfn_status(status, "Failed to acquire Threadsafe Function")
}

///|
fn tsfn_status(
  status : Int32,
  context : String,
) -> NapiTsfnStatus raise NapiError {
  match status {
    0 => Accepted
    15 => QueueFull
    16 => Closing
    _ => raise napi_failure(status, Error, "ERR_NAPI_TSFN", context)
  }
}
