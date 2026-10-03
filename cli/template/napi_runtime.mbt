///|
pub struct NapiBufferView {
  buf : UnmanagedBuffer
  len : Int
  mut is_alive : Bool
}

///|
pub fn NapiBufferView::length(self : NapiBufferView) -> Int {
  if !self.is_alive {
    abort("Buffer view is no longer valid") // This should be a panic or error, but we'll use panic for now, generator wrapper handles typed error if possible.
  }
  self.len
}

///|
pub fn NapiBufferView::load8(self : NapiBufferView, offset : Int) -> Int {
  if !self.is_alive {
    abort("Buffer view is no longer valid")
  }
  if offset < 0 || offset >= self.len {
    abort("Buffer view out of bounds")
  }
  self.buf.load8(offset)
}

///|
pub fn NapiBufferView::store8(
  self : NapiBufferView,
  offset : Int,
  val : Int,
) -> Unit {
  if !self.is_alive {
    abort("Buffer view is no longer valid")
  }
  if offset < 0 || offset >= self.len {
    abort("Buffer view out of bounds")
  }
  self.buf.store8(offset, val)
}

///|
pub fn NapiBufferView::invalidate(self : NapiBufferView) -> Unit {
  self.is_alive = false
}

///|
fn result_from_status(env : NapiEnv, status : Int, msg : Bytes) -> Unit {
  if status != 0 {
    let _ = napi_throw_error(env, b"", msg)
    ()
  }
}

// 供生成的包装函数调用的转换器

///|
pub fn get_Int(env : NapiEnv, val : NapiValue) -> Int {
  let res = Ref(0)
  let status = napi_get_value_int32(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Int")
  res.val
}

///|
pub fn set_Int(env : NapiEnv, val : Int) -> NapiValue {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_int32(env, val, res)
  result_from_status(env, status, b"Failed to create Int")
  res.val
}

///|
pub fn get_Double(env : NapiEnv, val : NapiValue) -> Double {
  let res = Ref(0.0)
  let status = napi_get_value_double(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Double")
  res.val
}

///|
pub fn set_Double(env : NapiEnv, val : Double) -> NapiValue {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_double(env, val, res)
  result_from_status(env, status, b"Failed to create Double")
  res.val
}

///|
pub fn get_Bool(env : NapiEnv, val : NapiValue) -> Bool {
  let res = Ref(false)
  let status = napi_get_value_bool(env, val, res)
  result_from_status(env, status, b"Invalid argument, expected Bool")
  res.val
}

///|
pub fn set_Bool(env : NapiEnv, val : Bool) -> NapiValue {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_get_boolean(env, val, res)
  result_from_status(env, status, b"Failed to create Bool")
  res.val
}

///|
pub fn get_String(env : NapiEnv, val : NapiValue) -> String {
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
    _ => {
      let _ = napi_throw_error(env, b"", b"Failed to decode UTF-8 string")
      ""
    }
  }
  res
}

///|
pub fn set_String(env : NapiEnv, val : String) -> NapiValue {
  let res_bytes = @utf8.encode(val)
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_create_string_utf8(env, res_bytes, res_bytes.length(), res)
  result_from_status(env, status, b"Failed to create String")
  res.val
}

///|
pub fn get_Bytes(env : NapiEnv, val : NapiValue) -> Bytes {
  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, val, unmanaged, len)
  result_from_status(env, status, b"Failed to get buffer")

  let arr = Array::make(len.val, b'\x00')
  for i = 0; i < len.val; i = i + 1 {
    arr[i] = unmanaged.val.load8(i).to_byte()
  }
  Bytes::from_array(arr)
}

///|
pub fn set_Bytes(env : NapiEnv, val : Bytes) -> NapiValue {
  // Currently MoonBit doesn't expose malloc natively to FFI.
  // Actually we need to pass a C-allocated buffer if we want external buffer.
  // For now we'll just create a string if we can't allocate.
  // wait, Node N-API provides `napi_create_buffer_copy` which allocates!
  // Let's add napi_create_buffer_copy to bindings.
  let res = Ref(moonbit_dummy_napi_value())
  let data = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_create_buffer_copy(env, val.length(), val, data, res)
  result_from_status(env, status, b"Failed to create buffer")
  res.val
}

///|
pub fn get_NapiBufferView(env : NapiEnv, val : NapiValue) -> NapiBufferView {
  let len = Ref(0)
  let unmanaged = Ref(moonbit_dummy_unmanaged_buffer())
  let status = napi_get_buffer_info(env, val, unmanaged, len)
  result_from_status(env, status, b"Failed to get buffer")
  { buf: unmanaged.val, len: len.val, is_alive: true, }
}

///|
pub fn set_Unit(env : NapiEnv, _val : Unit) -> NapiValue {
  let res = Ref(moonbit_dummy_napi_value())
  let status = napi_get_undefined(env, res)
  result_from_status(env, status, b"Failed to create undefined")
  res.val
}
