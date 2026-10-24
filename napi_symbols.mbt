///|
/// An owned reference to a JavaScript Symbol in its creating environment.
pub struct NapiSymbol {
  priv reference : NapiReference
}

///|
#borrow(description, result)
extern "c" fn napi_symbol_new_raw(
  env : NapiEnv,
  description : String,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_symbol_new"

///|
pub fn NapiSymbol::new(
  env : NapiEnv,
  description : String,
) -> NapiSymbol raise NapiError {
  let value = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_symbol_new_raw(env, description, value),
    b"Creating Symbol",
  )
  { reference: NapiReference::new(env, value.val), }
}

///|
#warnings("-unused_value")
fn get_NapiSymbol(
  env : NapiEnv,
  value : NapiValue,
) -> NapiSymbol raise NapiError {
  let kind = Ref(0)
  result_from_status(env, napi_value_kind(env, value, kind), b"Reading Symbol")
  if kind.val != 5 {
    raise napi_failure(
      1,
      TypeError,
      "ERR_NAPI_SYMBOL",
      "Expected JavaScript Symbol",
    )
  }
  { reference: NapiReference::new(env, value), }
}

///|
#warnings("-unused_value")
fn set_NapiSymbol(
  env : NapiEnv,
  value : NapiSymbol,
) -> NapiValue raise NapiError {
  value.reference.get(env)
}
