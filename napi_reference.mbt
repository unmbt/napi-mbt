///|
/// An owned, environment-bound JavaScript value, safe across handle scopes.
pub type NapiReference

///|
extern "c" fn napi_reference_empty() -> NapiReference = "napi_mbt_callback_empty"

///|
#borrow(reference)
extern "c" fn napi_reference_bind(
  env : NapiEnv,
  value : NapiValue,
  reference : NapiReference,
) -> Int32 = "napi_mbt_reference_bind"

///|
#borrow(reference, result)
extern "c" fn napi_reference_get(
  env : NapiEnv,
  reference : NapiReference,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_reference_get"

///|
#borrow(reference)
extern "c" fn napi_reference_dispose(reference : NapiReference) -> Int32 = "napi_mbt_owned_reference_dispose"

///|
#borrow(reference)
extern "c" fn napi_reference_throw(
  env : NapiEnv,
  reference : NapiReference,
) -> Int32 = "napi_mbt_reference_throw"

///|
#borrow(result)
extern "c" fn napi_take_exception(
  env : NapiEnv,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_take_exception"

///|
pub fn NapiReference::new(
  env : NapiEnv,
  value : NapiValue,
) -> NapiReference raise NapiError {
  let reference = napi_reference_empty()
  result_from_status(
    env,
    napi_reference_bind(env, value, reference),
    b"Retaining JavaScript value",
  )
  reference
}

///|
pub fn NapiReference::get(
  self : NapiReference,
  env : NapiEnv,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_reference_get(env, self, result),
    b"Reading JavaScript reference",
  )
  result.val
}

///|
pub fn NapiReference::dispose(self : NapiReference) -> Unit raise NapiError {
  let status = napi_reference_dispose(self)
  if status != 0 {
    raise napi_failure(
      status,
      Error,
      "ERR_NAPI_ENVIRONMENT",
      "Disposing JavaScript reference",
    )
  }
}

///|
pub fn napi_error_value(
  env : NapiEnv,
  error : Error,
) -> NapiValue raise NapiError {
  throw_napi_error(env, error)
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_take_exception(env, result),
    b"Capturing JavaScript exception",
  )
  result.val
}
