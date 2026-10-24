///|
/// Owned binary inputs and outputs have independent backing stores.
#export_name("int8")
pub fn int8(value : NapiInt8Array) -> NapiInt8Array { value }

///|
#export_name("uint8")
pub fn uint8(value : NapiUint8Array) -> NapiUint8Array { value }

///|
#export_name("clamped")
pub fn clamped(value : NapiUint8ClampedArray) -> NapiUint8ClampedArray { value }

///|
#export_name("int16")
pub fn int16(value : NapiInt16Array) -> NapiInt16Array { value }

///|
#export_name("uint16")
pub fn uint16(value : NapiUint16Array) -> NapiUint16Array { value }

///|
#export_name("int32")
pub fn int32(value : NapiInt32Array) -> NapiInt32Array { value }

///|
#export_name("uint32")
pub fn uint32(value : NapiUint32Array) -> NapiUint32Array { value }

///|
#export_name("float32")
pub fn float32(value : NapiFloat32Array) -> NapiFloat32Array { value }

///|
#export_name("float64")
pub fn float64(value : NapiFloat64Array) -> NapiFloat64Array { value }

///|
#export_name("arrayBuffer")
pub fn array_buffer(value : NapiArrayBuffer) -> NapiArrayBuffer { value }
