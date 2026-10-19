///|
pub(all) enum NapiErrorKind {
  Error
  TypeError
  RangeError
}

///|
pub(all) suberror NapiError {
  ApiError(
    status~ : Int32,
    kind~ : NapiErrorKind,
    code~ : String,
    context~ : String
  )
}

///|
fn napi_failure(
  status : Int32,
  kind : NapiErrorKind,
  code : String,
  context : String,
) -> NapiError {
  ApiError(status~, kind~, code~, context~)
}

///|
fn result_from_status(
  _env : NapiEnv,
  status : Int32,
  msg : Bytes,
) -> Unit raise NapiError {
  if status != 0 {
    if status == 1001 {
      raise napi_failure(
        status,
        Error,
        "ERR_NAPI_BUFFER_DETACHED",
        "Buffer backing store is detached",
      )
    }
    if status == 1002 {
      raise napi_failure(
        status,
        RangeError,
        "ERR_NAPI_SIZE",
        "Value exceeds MoonBit's supported size",
      )
    }
    let kind = match status {
      1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 17 | 18 | 19 | 20 => TypeError
      _ => Error
    }
    let code = if kind is TypeError {
      "ERR_NAPI_TYPE"
    } else if status == 10 {
      "ERR_NAPI_PENDING_EXCEPTION"
    } else {
      "ERR_NAPI_STATUS"
    }
    raise napi_failure(status, kind, code, @utf8.decode_lossy(msg))
  }
}

///|
#borrow(code, context)
extern "c" fn throw_napi_error_raw(
  env : NapiEnv,
  status : Int32,
  kind : Int32,
  code : Bytes,
  context : Bytes,
) -> Int32 = "moonbit_napi_throw"

///|
// The only JS exception boundary. The C side leaves an existing pending
// exception intact, including errors originating from reentrant JS callbacks.
fn throw_napi_error(env : NapiEnv, error : Error) -> Unit {
  let (status, kind, code, context) = match error {
    NapiError::ApiError(status~, kind~, code~, context~) =>
      (status, kind, code, context)
    _ => (9, Error, "ERR_NAPI_CALL", error.to_string())
  }
  let kind = match kind {
    Error => 0
    TypeError => 1
    RangeError => 2
  }
  // A throwing Node-API operation may itself report pending_exception. The
  // adapter must return NULL on either result; it cannot resume user code.
  ignore(
    throw_napi_error_raw(
      env,
      status,
      kind,
      @utf8.encode(code),
      @utf8.encode(context),
    ),
  )
}
