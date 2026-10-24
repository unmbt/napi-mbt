///|
/// A JavaScript Date represented by its ECMAScript time value in milliseconds.
/// Invalid dates are rejected at the N-API boundary.
pub struct NapiDate {
  priv milliseconds : Double
}

///|
pub fn NapiDate::new(milliseconds : Double) -> NapiDate {
  { milliseconds, }
}

///|
pub fn NapiDate::milliseconds(self : NapiDate) -> Double {
  self.milliseconds
}

///|
fn valid_date_time(milliseconds : Double) -> Bool {
  !milliseconds.is_nan() &&
  !milliseconds.is_inf() &&
  milliseconds >= -8640000000000000.0 &&
  milliseconds <= 8640000000000000.0
}

///|
#borrow(result)
extern "c" fn napi_read_date_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Double],
) -> Int32 = "moonbit_napi_read_date"

///|
#borrow(result)
extern "c" fn napi_write_date_raw(
  env : NapiEnv,
  value : Double,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_date"

///|
fn get_NapiDate(env : NapiEnv, value : NapiValue) -> NapiDate raise NapiError {
  let result = Ref(0.0)
  result_from_status(
    env,
    napi_read_date_raw(env, value, result),
    b"Reading Date",
  )
  if result.val.is_nan() {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_DATE",
      "Invalid JavaScript Date",
    )
  }
  { milliseconds: result.val, }
}

///|
fn set_NapiDate(env : NapiEnv, value : NapiDate) -> NapiValue raise NapiError {
  if !valid_date_time(value.milliseconds) {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_DATE",
      "Invalid JavaScript Date",
    )
  }
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_date_raw(env, value.milliseconds, result),
    b"Writing Date",
  )
  result.val
}
