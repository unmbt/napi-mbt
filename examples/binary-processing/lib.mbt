///|
#export_name("copy")
pub fn copy(value : Bytes) -> Bytes { value }
///|
#export_name("increment")
pub fn increment(value : NapiBufferView) -> Unit raise { if value.length() > 0 { value.store8(0, value.load8(0) + 1) } }
