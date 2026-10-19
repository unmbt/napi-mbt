///|
/// An owned reference to a JavaScript function. The reference belongs to its
/// creating environment; dispose is idempotent and GC is a fallback.
pub type NapiCallback

///|
#external
pub type NapiArguments

///|
extern "c" fn napi_callback_empty() -> NapiCallback = "napi_mbt_callback_empty"

///|
#borrow(callback)
extern "c" fn napi_callback_bind(
  env : NapiEnv,
  value : NapiValue,
  callback : NapiCallback,
) -> Int32 = "napi_mbt_callback_bind"

///|
#borrow(callback, result)
extern "c" fn napi_callback_env_raw(
  callback : NapiCallback,
  result : Ref[NapiEnv],
) -> Int32 = "napi_mbt_callback_env"

///|
#borrow(callback, result)
extern "c" fn napi_callback_call_raw(
  callback : NapiCallback,
  args : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_callback_call"

///|
#borrow(callback)
extern "c" fn napi_callback_dispose_raw(callback : NapiCallback) -> Int32 = "napi_mbt_callback_dispose"

///|
pub fn NapiCallback::new(
  env : NapiEnv,
  value : NapiValue,
) -> NapiCallback raise NapiError {
  let callback = napi_callback_empty()
  result_from_status(
    env,
    napi_callback_bind(env, value, callback),
    b"Retaining JavaScript callback",
  )
  callback
}

///|
pub fn NapiCallback::environment(
  self : NapiCallback,
) -> NapiEnv raise NapiError {
  let result = Ref(napi_dummy_env())
  let status = napi_callback_env_raw(self, result)
  // The stored environment may already have closed. Do not call N-API with it.
  if status != 0 {
    raise napi_failure(
      status,
      Error,
      if status == 1006 {
        "ERR_NAPI_DISPOSED"
      } else {
        "ERR_NAPI_ENVIRONMENT"
      },
      "Calling callback outside its owning environment",
    )
  }
  result.val
}

///|
extern "c" fn napi_dummy_env() -> NapiEnv = "napi_mbt_dummy_env"

///|
pub fn NapiCallback::call(
  self : NapiCallback,
  args : NapiValue,
) -> NapiValue raise NapiError {
  let env = self.environment()
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_callback_call_raw(self, args, result),
    b"Calling JavaScript callback",
  )
  result.val
}

///|
pub fn NapiCallback::dispose(self : NapiCallback) -> Unit raise NapiError {
  let status = napi_callback_dispose_raw(self)
  if status != 0 {
    raise napi_failure(
      status,
      Error,
      "ERR_NAPI_ENVIRONMENT",
      "Disposing JavaScript callback",
    )
  }
}

///|
extern "c" fn napi_arguments_length(args : NapiArguments) -> Int32 = "napi_mbt_arguments_length"

///|
#borrow(result)
extern "c" fn napi_arguments_get_raw(
  env : NapiEnv,
  args : NapiArguments,
  index : Int32,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_arguments_get"

///|
pub fn NapiArguments::require(
  self : NapiArguments,
  count : Int32,
) -> Unit raise NapiError {
  if napi_arguments_length(self) < count {
    raise napi_failure(
      1,
      TypeError,
      "ERR_NAPI_ARGUMENTS",
      "Missing callback argument",
    )
  }
}

///|
pub fn NapiArguments::get(
  self : NapiArguments,
  env : NapiEnv,
  index : Int32,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_arguments_get_raw(env, self, index, result),
    b"Reading closure argument",
  )
  result.val
}

///|
#borrow(callback, result)
extern "c" fn napi_closure_new_raw(
  env : NapiEnv,
  callback : (NapiEnv, NapiArguments) -> NapiValue,
  trampoline : FuncRef[
    ((NapiEnv, NapiArguments) -> NapiValue, NapiEnv, NapiArguments) -> NapiValue,
  ],
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_closure_new"

///|
pub fn napi_closure_new(
  env : NapiEnv,
  callback : (NapiEnv, NapiArguments) -> NapiValue,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_closure_new_raw(
      env,
      callback,
      fn(f, env, args) { f(env, args) },
      result,
    ),
    b"Creating MoonBit closure",
  )
  result.val
}
