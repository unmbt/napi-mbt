///|
pub(all) enum BinaryKind {
  Int8
  Uint8
  Uint8Clamped
  Int16
  Uint16
  Int32
  Uint32
  Float32
  Float64
  BigInt64
  BigUint64
  DataView
  ArrayBuffer
}

///|
fn BinaryKind::javascript(self : BinaryKind) -> String {
  match self {
    Int8 => "Int8Array"
    Uint8 => "Uint8Array"
    Uint8Clamped => "Uint8ClampedArray"
    Int16 => "Int16Array"
    Uint16 => "Uint16Array"
    Int32 => "Int32Array"
    Uint32 => "Uint32Array"
    Float32 => "Float32Array"
    Float64 => "Float64Array"
    BigInt64 => "BigInt64Array"
    BigUint64 => "BigUint64Array"
    DataView => "DataView"
    ArrayBuffer => "ArrayBuffer"
  }
}
