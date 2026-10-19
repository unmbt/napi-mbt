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
  let len = Ref(0)
  let status = napi_get_value_string_utf8_length(
    env,
    val,
    moonbit_dummy_unmanaged_buffer(),
    0,
    len,
  )
  result_from_status(env, status, b"Failed to get string length")

  let buf = Bytes::make(len.val + 1, b'\x00')
  let status2 = napi_get_value_string_utf8(env, val, buf, len.val + 1, len)
  result_from_status(env, status2, b"Failed to read string")

  let arr = Array::make(len.val, b'\x00')
  for i = 0; i < len.val; i = i + 1 {
    arr[i] = buf[i]
  }

  // Use utf8.decode for proper string construction
  let res = @utf8.decode(Bytes::from_array(arr)) catch {
    _ =>
      raise napi_failure(
        9,
        Error,
        "ERR_NAPI_STRING",
        "Failed to decode UTF-8 string",
      )
  }
  res
}

///|
pub fn set_String(env : NapiEnv, val : String) -> NapiValue raise NapiError {
  let res_bytes = @utf8.encode(val)
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_string_utf8(env, res_bytes, res_bytes.length(), res)
  result_from_status(env, status, b"Failed to create String")
  res.val
}

///|
pub fn get_Bytes(env : NapiEnv, val : NapiValue) -> Bytes raise NapiError {
  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, val, unmanaged, len)
  result_from_status(env, status, b"Invalid argument, expected Buffer")

  let arr = Array::make(len.val, b'\x00')
  for i = 0; i < len.val; i = i + 1 {
    arr[i] = unmanaged.val.load8(i).to_byte()
  }
  Bytes::from_array(arr)
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

///|
#export_name("add")
pub fn add(a : Int32, b : Int32) -> Int32 {
  a + b
}

///|
#export_name("concat")
pub fn concat(a : String, b : String) -> String {
  a + b
}

///|
#export_name("mutate_buffer")
pub fn mutate_buffer(view : NapiBufferView) -> Unit raise NapiError {
  if view.length() > 0 {
    let old = view.load8(0)
    view.store8(0, old + 1)
  }
}

///|
#export_name("roundtrip_bytes")
pub fn roundtrip_bytes(b : Bytes) -> Bytes {
  b
}

///|
#export_name("check_bool")
pub fn check_bool(b : Bool) -> Bool {
  !b
}

///|
#export_name("check_double")
pub fn check_double(d : Double) -> Double {
  d * 2.0
}
