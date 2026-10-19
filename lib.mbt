///|
let active_buffer_views : Ref[Int32] = Ref(0)

///|
pub struct NapiBufferView {
  env : NapiEnv
  value : NapiValue
  mut is_alive : Bool
}

///|
fn NapiBufferView::validate(
  self : NapiBufferView,
) -> (UnmanagedBuffer, Int32) raise NapiError {
  if !self.is_alive {
    raise napi_failure(
      1,
      Error,
      "ERR_NAPI_BUFFER_EXPIRED",
      "Buffer view is no longer valid",
    )
  }
  let data = Ref(moonbit_dummy_unmanaged_buffer())
  let len = Ref(0)
  let status = napi_get_buffer_info(self.env, self.value, data, len)
  result_from_status(
    self.env,
    status,
    b"Buffer backing store is detached or invalid",
  )
  (data.val, len.val)
}

///|
pub fn NapiBufferView::length(self : NapiBufferView) -> Int32 raise NapiError {
  self.validate().1
}

///|
pub fn NapiBufferView::load8(
  self : NapiBufferView,
  offset : Int32,
) -> Int32 raise NapiError {
  let (buf, len) = self.validate()
  if offset < 0 || offset >= len {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_BUFFER_BOUNDS",
      "Buffer view out of bounds",
    )
  }
  buf.load8(offset)
}

///|
pub fn NapiBufferView::store8(
  self : NapiBufferView,
  offset : Int32,
  val : Int32,
) -> Unit raise NapiError {
  let (buf, len) = self.validate()
  if offset < 0 || offset >= len {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_BUFFER_BOUNDS",
      "Buffer view out of bounds",
    )
  }
  buf.store8(offset, val)
}

///|
/// Invalidates a borrowed Buffer view after the callback returns.
pub fn NapiBufferView::invalidate(self : NapiBufferView) -> Unit {
  if self.is_alive {
    self.is_alive = false
    active_buffer_views.val -= 1
  }
}

///|
pub fn get_Int(env : NapiEnv, val : NapiValue) -> Int32 raise NapiError {
  let res = Ref(0.0)
  let status = napi_get_value_double(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Int")
  let value = res.val
  if !(value >= -2147483648.0 && value <= 2147483647.0) ||
    value != value.to_int().to_double() {
    raise napi_failure(
      1,
      RangeError,
      "ERR_NAPI_INT_RANGE",
      "Int requires a finite integral number in [-2147483648, 2147483647]",
    )
  }
  value.to_int()
}

///|
pub fn set_Int(env : NapiEnv, val : Int32) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_int32(env, val, res)
  result_from_status(env, status, b"Failed to create Int")
  res.val
}

///|
pub fn get_Double(env : NapiEnv, val : NapiValue) -> Double raise NapiError {
  let res = Ref(0.0)
  let status = napi_get_value_double(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Double")
  res.val
}

///|
pub fn set_Double(env : NapiEnv, val : Double) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_double(env, val, res)
  result_from_status(env, status, b"Failed to create Double")
  res.val
}

///|
pub fn get_Bool(env : NapiEnv, val : NapiValue) -> Bool raise NapiError {
  let res = Ref(false)
  let status = napi_get_value_bool(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Bool")
  res.val
}

///|
pub fn set_Bool(env : NapiEnv, val : Bool) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_get_boolean(env, val, res)
  result_from_status(env, status, b"Failed to create Bool")
  res.val
}

///|
pub fn get_String(env : NapiEnv, val : NapiValue) -> String raise NapiError {
  let status = Ref(0)
  let result = napi_read_string(env, val, status)
  result_from_status(env, status.val, b"Reading UTF-16 String")
  result
}

///|
pub fn set_String(env : NapiEnv, val : String) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_write_string(env, val, res)
  result_from_status(env, status, b"Failed to create String")
  res.val
}

///|
pub fn get_Bytes(env : NapiEnv, val : NapiValue) -> Bytes raise NapiError {
  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, val, unmanaged, len)
  result_from_status(env, status, b"Invalid argument, expected Buffer")

  napi_copy_bytes(unmanaged.val, len.val)
}

///|
pub fn set_Bytes(env : NapiEnv, val : Bytes) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let data = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_create_buffer_copy(env, val.length(), val, data, res)
  result_from_status(env, status, b"Failed to create buffer")
  res.val
}

///|
pub fn get_NapiBufferView(
  env : NapiEnv,
  val : NapiValue,
) -> NapiBufferView raise NapiError {
  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, val, unmanaged, len)
  result_from_status(env, status, b"Invalid argument, expected Buffer")
  active_buffer_views.val += 1
  { env, value: val, is_alive: true, }
}

///|
pub fn set_Unit(env : NapiEnv, _val : Unit) -> NapiValue raise NapiError {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_get_undefined(env, res)
  result_from_status(env, status, b"Failed to create undefined")
  res.val
}
