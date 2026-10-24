/// A typed, high-level Threadsafe Function.
///
/// Call this wrapper on the MoonBit owner thread: `call` runs the encoder
/// synchronously, then copies its bytes into a C-owned queue payload. The JS
/// callback receives a Node Buffer. Native producer threads must instead use
/// the low-level TSFN API with C-owned payloads, without MoonBit closures or RC.

///|
pub struct NapiTypedThreadsafeFunction[T] {
  priv raw : NapiThreadsafeFunction
  priv encode : (T) -> Bytes
}

///|
#borrow(result)
extern "c" fn napi_typed_tsfn_create_raw(
  env : NapiEnv,
  callback : NapiValue,
  max_queue_size : Int32,
  result : Ref[NapiThreadsafeFunction],
) -> Int32 = "napi_mbt_typed_tsfn_create"

///|
#borrow(data)
extern "c" fn napi_typed_tsfn_call_raw(
  func : NapiThreadsafeFunction,
  data : Bytes,
  mode : Int32,
) -> Int32 = "napi_mbt_typed_tsfn_call"

///|
/// Creation owns one producer count. Release it when finished. This wrapper
/// does not automatically release or prevent use after the last release.
pub fn[T] NapiTypedThreadsafeFunction::new(
  env : NapiEnv,
  callback : NapiValue,
  max_queue_size : Int32,
  encode : (T) -> Bytes,
) -> NapiTypedThreadsafeFunction[T] raise NapiError {
  let result = Ref(napi_threadsafe_function_dummy())
  result_from_status(
    env,
    napi_typed_tsfn_create_raw(env, callback, max_queue_size, result),
    b"Creating typed Threadsafe Function",
  )
  { raw: result.val, encode, }
}

///|
/// Prefer Nonblocking on the owner thread; Blocking on a full queue can deadlock.
pub fn[T] NapiTypedThreadsafeFunction::call(
  self : NapiTypedThreadsafeFunction[T],
  value : T,
  mode : NapiTsfnCallMode,
) -> NapiTsfnStatus raise NapiError {
  let mode = match mode {
    Nonblocking => 0
    Blocking => 1
  }
  tsfn_status(
    napi_typed_tsfn_call_raw(self.raw, (self.encode)(value), mode),
    "Calling typed Threadsafe Function",
  )
}

///|
pub fn[T] NapiTypedThreadsafeFunction::try_call(
  self : NapiTypedThreadsafeFunction[T],
  value : T,
) -> NapiTsfnStatus raise NapiError {
  self.call(value, Nonblocking)
}

///|
pub fn[T] NapiTypedThreadsafeFunction::acquire(
  self : NapiTypedThreadsafeFunction[T],
) -> NapiTsfnStatus raise NapiError {
  napi_threadsafe_function_acquire(self.raw)
}

///|
pub fn[T] NapiTypedThreadsafeFunction::release(
  self : NapiTypedThreadsafeFunction[T],
) -> NapiTsfnStatus raise NapiError {
  napi_threadsafe_function_release(self.raw, Release)
}

///|
/// Stop delivery and release one producer count. Do not use this producer again.
pub fn[T] NapiTypedThreadsafeFunction::abort(
  self : NapiTypedThreadsafeFunction[T],
) -> NapiTsfnStatus raise NapiError {
  napi_threadsafe_function_release(self.raw, Abort)
}
