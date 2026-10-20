///|
/// Owned data copied from/to JavaScript. No JavaScript handles or borrowed storage.
pub struct NapiUint8Array {
  priv data : FixedArray[Byte]
}

///|
pub fn NapiUint8Array::new(values : Array[Byte]) -> NapiUint8Array {
  { data: FixedArray::makei(values.length(), i => values[i]), }
}

///|
pub fn NapiUint8Array::length(self : NapiUint8Array) -> Int32 {
  self.data.length()
}

///|
pub fn NapiUint8Array::to_array(self : NapiUint8Array) -> Array[Byte] {
  Array::makei(self.data.length(), i => self.data[i])
}

///|
#borrow(status)
extern "c" fn napi_read_Uint8Array(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> FixedArray[Byte] = "moonbit_napi_read_Uint8Array"

///|
#borrow(data, result)
extern "c" fn napi_write_Uint8Array(
  env : NapiEnv,
  data : FixedArray[Byte],
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_Uint8Array"

///|
pub fn get_NapiUint8Array(
  env : NapiEnv,
  value : NapiValue,
) -> NapiUint8Array raise NapiError {
  let status = Ref(0)
  let data = napi_read_Uint8Array(env, value, status)
  result_from_status(env, status.val, b"Reading owned Uint8Array")
  { data, }
}

///|
pub fn set_NapiUint8Array(
  env : NapiEnv,
  value : NapiUint8Array,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_Uint8Array(env, value.data, result),
    b"Writing owned Uint8Array",
  )
  result.val
}

///|
/// Owned data copied from/to JavaScript. No JavaScript handles or borrowed storage.
pub struct NapiInt32Array {
  priv data : FixedArray[Int32]
}

///|
pub fn NapiInt32Array::new(values : Array[Int32]) -> NapiInt32Array {
  { data: FixedArray::makei(values.length(), i => values[i]), }
}

///|
pub fn NapiInt32Array::length(self : NapiInt32Array) -> Int32 {
  self.data.length()
}

///|
pub fn NapiInt32Array::to_array(self : NapiInt32Array) -> Array[Int32] {
  Array::makei(self.data.length(), i => self.data[i])
}

///|
#borrow(status)
extern "c" fn napi_read_Int32Array(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> FixedArray[Int32] = "moonbit_napi_read_Int32Array"

///|
#borrow(data, result)
extern "c" fn napi_write_Int32Array(
  env : NapiEnv,
  data : FixedArray[Int32],
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_Int32Array"

///|
pub fn get_NapiInt32Array(
  env : NapiEnv,
  value : NapiValue,
) -> NapiInt32Array raise NapiError {
  let status = Ref(0)
  let data = napi_read_Int32Array(env, value, status)
  result_from_status(env, status.val, b"Reading owned Int32Array")
  { data, }
}

///|
pub fn set_NapiInt32Array(
  env : NapiEnv,
  value : NapiInt32Array,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_Int32Array(env, value.data, result),
    b"Writing owned Int32Array",
  )
  result.val
}

///|
/// Owned data copied from/to JavaScript. No JavaScript handles or borrowed storage.
pub struct NapiUint32Array {
  priv data : FixedArray[UInt32]
}

///|
pub fn NapiUint32Array::new(values : Array[UInt32]) -> NapiUint32Array {
  { data: FixedArray::makei(values.length(), i => values[i]), }
}

///|
pub fn NapiUint32Array::length(self : NapiUint32Array) -> Int32 {
  self.data.length()
}

///|
pub fn NapiUint32Array::to_array(self : NapiUint32Array) -> Array[UInt32] {
  Array::makei(self.data.length(), i => self.data[i])
}

///|
#borrow(status)
extern "c" fn napi_read_Uint32Array(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> FixedArray[UInt32] = "moonbit_napi_read_Uint32Array"

///|
#borrow(data, result)
extern "c" fn napi_write_Uint32Array(
  env : NapiEnv,
  data : FixedArray[UInt32],
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_Uint32Array"

///|
pub fn get_NapiUint32Array(
  env : NapiEnv,
  value : NapiValue,
) -> NapiUint32Array raise NapiError {
  let status = Ref(0)
  let data = napi_read_Uint32Array(env, value, status)
  result_from_status(env, status.val, b"Reading owned Uint32Array")
  { data, }
}

///|
pub fn set_NapiUint32Array(
  env : NapiEnv,
  value : NapiUint32Array,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_Uint32Array(env, value.data, result),
    b"Writing owned Uint32Array",
  )
  result.val
}

///|
/// Owned data copied from/to JavaScript. No JavaScript handles or borrowed storage.
pub struct NapiFloat32Array {
  priv data : FixedArray[Float]
}

///|
pub fn NapiFloat32Array::new(values : Array[Float]) -> NapiFloat32Array {
  { data: FixedArray::makei(values.length(), i => values[i]), }
}

///|
pub fn NapiFloat32Array::length(self : NapiFloat32Array) -> Int32 {
  self.data.length()
}

///|
pub fn NapiFloat32Array::to_array(self : NapiFloat32Array) -> Array[Float] {
  Array::makei(self.data.length(), i => self.data[i])
}

///|
#borrow(status)
extern "c" fn napi_read_Float32Array(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> FixedArray[Float] = "moonbit_napi_read_Float32Array"

///|
#borrow(data, result)
extern "c" fn napi_write_Float32Array(
  env : NapiEnv,
  data : FixedArray[Float],
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_Float32Array"

///|
pub fn get_NapiFloat32Array(
  env : NapiEnv,
  value : NapiValue,
) -> NapiFloat32Array raise NapiError {
  let status = Ref(0)
  let data = napi_read_Float32Array(env, value, status)
  result_from_status(env, status.val, b"Reading owned Float32Array")
  { data, }
}

///|
pub fn set_NapiFloat32Array(
  env : NapiEnv,
  value : NapiFloat32Array,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_Float32Array(env, value.data, result),
    b"Writing owned Float32Array",
  )
  result.val
}

///|
/// Owned data copied from/to JavaScript. No JavaScript handles or borrowed storage.
pub struct NapiFloat64Array {
  priv data : FixedArray[Double]
}

///|
pub fn NapiFloat64Array::new(values : Array[Double]) -> NapiFloat64Array {
  { data: FixedArray::makei(values.length(), i => values[i]), }
}

///|
pub fn NapiFloat64Array::length(self : NapiFloat64Array) -> Int32 {
  self.data.length()
}

///|
pub fn NapiFloat64Array::to_array(self : NapiFloat64Array) -> Array[Double] {
  Array::makei(self.data.length(), i => self.data[i])
}

///|
#borrow(status)
extern "c" fn napi_read_Float64Array(
  env : NapiEnv,
  value : NapiValue,
  status : Ref[Int32],
) -> FixedArray[Double] = "moonbit_napi_read_Float64Array"

///|
#borrow(data, result)
extern "c" fn napi_write_Float64Array(
  env : NapiEnv,
  data : FixedArray[Double],
  result : Ref[NapiValue],
) -> Int32 = "moonbit_napi_write_Float64Array"

///|
pub fn get_NapiFloat64Array(
  env : NapiEnv,
  value : NapiValue,
) -> NapiFloat64Array raise NapiError {
  let status = Ref(0)
  let data = napi_read_Float64Array(env, value, status)
  result_from_status(env, status.val, b"Reading owned Float64Array")
  { data, }
}

///|
pub fn set_NapiFloat64Array(
  env : NapiEnv,
  value : NapiFloat64Array,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_write_Float64Array(env, value.data, result),
    b"Writing owned Float64Array",
  )
  result.val
}
