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
    view.store8(0, view.load8(0) + 1)
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
