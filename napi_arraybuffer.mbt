///|
/// An owned immutable byte sequence, copied from/to an independent ArrayBuffer.
pub struct NapiArrayBuffer {
  priv data : Bytes
}

///|
pub fn NapiArrayBuffer::from_bytes(data : Bytes) -> NapiArrayBuffer {
  { data, }
}

///|
pub fn NapiArrayBuffer::to_bytes(self : NapiArrayBuffer) -> Bytes {
  self.data
}

///|
pub fn NapiArrayBuffer::byte_length(self : NapiArrayBuffer) -> Int32 {
  self.data.length()
}

///|
#borrow(status)
extern "c" fn napi_read_ArrayBuffer(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> Bytes = "moonbit_napi_read_ArrayBuffer"

///|
#borrow(data, result)
extern "c" fn napi_write_ArrayBuffer(
  env : NapiEnv,
  data : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_ArrayBuffer"

///|
pub fn get_NapiArrayBuffer(
  env : NapiEnv,
  value : NapiValue,
) -> NapiArrayBuffer raise NapiError {
  let status = Ref(0)
  let data = napi_read_ArrayBuffer(env, value, status)
  result_from_status(env, status.val, b"Reading owned ArrayBuffer")
  { data, }
}

///|
pub fn set_NapiArrayBuffer(
  env : NapiEnv,
  value : NapiArrayBuffer,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_ArrayBuffer(env, value.data, result),
    b"Writing owned ArrayBuffer",
  )
  result.val
}
