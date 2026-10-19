///|
#borrow(result)
extern "c" fn napi_class_lookup_raw(
  env : NapiEnv,
  value : NapiValue,
  type_id : Int32,
  result : Ref[UnmanagedBuffer],
) -> Int32 = "napi_mbt_class_lookup"

///|
pub fn napi_class_handle(
  env : NapiEnv,
  value : NapiValue,
  type_id : Int32,
) -> UnmanagedBuffer raise NapiError {
  let result = Ref(moonbit_dummy_unmanaged_buffer())
  result_from_status(
    env,
    napi_class_lookup_raw(env, value, type_id, result),
    b"Validating native receiver",
  )
  result.val
}

///|
extern "c" fn napi_class_dispose_raw(
  env : NapiEnv,
  value : NapiValue,
  type_id : Int32,
) -> Int32 = "napi_mbt_class_dispose"

///|
pub fn napi_class_dispose(
  env : NapiEnv,
  value : NapiValue,
  type_id : Int32,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_class_dispose_raw(env, value, type_id),
    b"Disposing native receiver",
  )
}
