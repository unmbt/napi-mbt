///|
pub(all) enum BinaryKind {
  Uint8
  Int32
  Uint32
  Float32
  Float64
  ArrayBuffer
}

///|
fn BinaryKind::javascript(self : BinaryKind) -> String {
  match self {
    Uint8 => "Uint8Array"
    Int32 => "Int32Array"
    Uint32 => "Uint32Array"
    Float32 => "Float32Array"
    Float64 => "Float64Array"
    ArrayBuffer => "ArrayBuffer"
  }
}
