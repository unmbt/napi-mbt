/// N-API v8, v9 and v10 additions plus ownership-aware External helpers.

///|
pub struct NapiTypeTag {
  high : UInt64
  low : UInt64
}

///|
pub fn NapiTypeTag::new(high : UInt64, low : UInt64) -> NapiTypeTag {
  { high, low, }
}

///|
#borrow(data, result)
extern "c" fn napi_create_external_buffer_raw(
  env : NapiEnv,
  data : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_external_buffer"

///|
#borrow(data, result)
extern "c" fn napi_create_external_arraybuffer_raw(
  env : NapiEnv,
  data : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_external_arraybuffer"

///|
#borrow(result)
extern "c" fn napi_create_external_raw(
  env : NapiEnv,
  data : UnmanagedBuffer,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_external"

///|
#borrow(result)
extern "c" fn napi_get_external_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[UnmanagedBuffer],
) -> Int32 = "napi_mbt_get_external"

///|
pub struct NapiExternal {
  priv value : NapiValue
}

///|
pub fn NapiExternal::new(
  env : NapiEnv,
  data : UnmanagedBuffer,
) -> NapiExternal raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_external_raw(env, data, result),
    b"Creating External",
  )
  { value: result.val, }
}

///|
pub fn NapiExternal::from_value(
  env : NapiEnv,
  value : NapiValue,
) -> NapiExternal raise NapiError {
  match napi_value_type(env, value) {
    External => { value, }
    _ =>
      raise napi_failure(
        1,
        TypeError,
        "ERR_NAPI_EXTERNAL",
        "Expected an External value",
      )
  }
}

///|
pub fn NapiExternal::value(self : NapiExternal) -> NapiValue {
  self.value
}

///|
pub fn NapiExternal::data(
  self : NapiExternal,
  env : NapiEnv,
) -> UnmanagedBuffer raise NapiError {
  let result = Ref(moonbit_dummy_unmanaged_buffer())
  result_from_status(
    env,
    napi_get_external_raw(env, self.value, result),
    b"Reading External",
  )
  result.val
}

///|
pub struct NapiExternalBuffer {
  priv data : Bytes
}

///|
pub fn NapiExternalBuffer::from_bytes(data : Bytes) -> NapiExternalBuffer {
  { data, }
}

///|
pub fn NapiExternalBuffer::length(self : NapiExternalBuffer) -> Int32 {
  self.data.length()
}

///|
pub fn NapiExternalBuffer::to_bytes(self : NapiExternalBuffer) -> Bytes {
  self.data
}

///|
#borrow(data, result)
extern "c" fn napi_create_dataview_raw(
  env : NapiEnv,
  data : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_dataview"

///|
#borrow(result, status)
extern "c" fn napi_read_dataview_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Bytes],
  status : Ref[Int32],
) -> Int32 = "napi_mbt_read_dataview"

///|
/// An owned DataView snapshot. The snapshot is copied on input; use
/// `napi_external_buffer` when a mutable zero-copy view is required.
pub struct NapiDataView {
  priv data : Bytes
}

///|
pub fn NapiDataView::from_bytes(data : Bytes) -> NapiDataView {
  { data, }
}

///|
pub fn NapiDataView::to_bytes(self : NapiDataView) -> Bytes {
  self.data
}

///|
pub fn NapiDataView::byte_length(self : NapiDataView) -> Int32 {
  self.data.length()
}

///|
pub fn get_NapiDataView(
  env : NapiEnv,
  value : NapiValue,
) -> NapiDataView raise NapiError {
  let data = Ref(b"")
  let status = Ref(0)
  ignore(napi_read_dataview_raw(env, value, data, status))
  result_from_status(env, status.val, b"Reading DataView")
  { data: data.val, }
}

///|
pub fn set_NapiDataView(
  env : NapiEnv,
  value : NapiDataView,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_dataview_raw(env, value.data, result),
    b"Creating DataView",
  )
  result.val
}

///|
pub fn napi_external_buffer(
  env : NapiEnv,
  data : Bytes,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_external_buffer_raw(env, data, result),
    b"Creating zero-copy Buffer",
  )
  result.val
}

///|
pub fn napi_external_arraybuffer(
  env : NapiEnv,
  data : Bytes,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_external_arraybuffer_raw(env, data, result),
    b"Creating zero-copy ArrayBuffer",
  )
  result.val
}

///|
#borrow(result)
extern "c" fn napi_buffer_from_arraybuffer_raw(
  env : NapiEnv,
  arraybuffer : NapiValue,
  offset : Int32,
  length : Int32,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_buffer_from_arraybuffer"

///|
pub fn napi_buffer_from_arraybuffer(
  env : NapiEnv,
  arraybuffer : NapiValue,
  offset : Int32,
  length : Int32,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_buffer_from_arraybuffer_raw(env, arraybuffer, offset, length, result),
    b"Creating Buffer view",
  )
  result.val
}

///|
#borrow(description, result)
extern "c" fn napi_symbol_for_raw(
  env : NapiEnv,
  description : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_symbol_for"

///|
pub fn napi_symbol_for(
  env : NapiEnv,
  description : String,
) -> NapiSymbol raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_symbol_for_raw(env, @utf8.encode(description), result),
    b"Creating global Symbol",
  )
  { reference: NapiReference::new(env, result.val), }
}

///|
#borrow(value, result)
extern "c" fn napi_create_property_key_raw(
  env : NapiEnv,
  value : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_property_key_utf8"

///|
pub fn napi_property_key(
  env : NapiEnv,
  value : String,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_property_key_raw(env, @utf8.encode(value), result),
    b"Creating property key",
  )
  result.val
}

///|
#borrow(value, result, copied)
extern "c" fn napi_create_external_string_raw(
  env : NapiEnv,
  value : Bytes,
  result : Ref[NapiValue],
  copied : Ref[Bool],
) -> Int32 = "napi_mbt_create_external_string_latin1"

///|
pub fn napi_external_string_latin1(
  env : NapiEnv,
  value : Bytes,
) -> (NapiValue, Bool) raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  let copied = Ref(false)
  result_from_status(
    env,
    napi_create_external_string_raw(env, value, result, copied),
    b"Creating external string",
  )
  (result.val, copied.val)
}

///|
#borrow(result)
extern "c" fn napi_module_file_name_raw(
  env : NapiEnv,
  result : Ref[String],
) -> Int32 = "napi_mbt_get_module_file_name"

///|
pub fn napi_module_file_name(env : NapiEnv) -> String raise NapiError {
  let result = Ref("")
  result_from_status(
    env,
    napi_module_file_name_raw(env, result),
    b"Reading module filename",
  )
  result.val
}

///|
#borrow(code, message, result)
extern "c" fn napi_create_syntax_error_raw(
  env : NapiEnv,
  code : String,
  message : String,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_create_syntax_error"

///|
#borrow(code, message)
extern "c" fn napi_throw_syntax_error_raw(
  env : NapiEnv,
  code : String,
  message : String,
) -> Int32 = "napi_mbt_throw_syntax_error"

///|
pub fn napi_syntax_error(
  env : NapiEnv,
  code : String,
  message : String,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_create_syntax_error_raw(env, code, message, result),
    b"Creating SyntaxError",
  )
  result.val
}

///|
pub fn napi_throw_syntax_error(
  env : NapiEnv,
  code : String,
  message : String,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_throw_syntax_error_raw(env, code, message),
    b"Throwing SyntaxError",
  )
}

///|
extern "c" fn napi_freeze_object_raw(
  env : NapiEnv,
  object : NapiValue,
) -> Int32 = "napi_mbt_freeze_object"

///|
extern "c" fn napi_seal_object_raw(env : NapiEnv, object : NapiValue) -> Int32 = "napi_mbt_seal_object"

///|
extern "c" fn napi_tag_object_raw(
  env : NapiEnv,
  object : NapiValue,
  high : UInt64,
  low : UInt64,
) -> Int32 = "napi_mbt_tag_object"

///|
#borrow(result)
extern "c" fn napi_check_object_tag_raw(
  env : NapiEnv,
  object : NapiValue,
  high : UInt64,
  low : UInt64,
  result : Ref[Bool],
) -> Int32 = "napi_mbt_check_object_tag"

///|
pub fn napi_object_freeze(
  env : NapiEnv,
  object : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_freeze_object_raw(env, object),
    b"Freezing object",
  )
}

///|
pub fn napi_object_seal(
  env : NapiEnv,
  object : NapiValue,
) -> Unit raise NapiError {
  result_from_status(env, napi_seal_object_raw(env, object), b"Sealing object")
}

///|
pub fn napi_type_tag_object(
  env : NapiEnv,
  object : NapiValue,
  tag : NapiTypeTag,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_tag_object_raw(env, object, tag.high, tag.low),
    b"Tagging object",
  )
}

///|
pub fn napi_check_object_type_tag(
  env : NapiEnv,
  object : NapiValue,
  tag : NapiTypeTag,
) -> Bool raise NapiError {
  let result = Ref(false)
  result_from_status(
    env,
    napi_check_object_tag_raw(env, object, tag.high, tag.low, result),
    b"Checking object tag",
  )
  result.val
}

///|
extern "c" fn napi_set_instance_data_raw(
  env : NapiEnv,
  data : UnmanagedBuffer,
) -> Int32 = "napi_mbt_set_instance_data"

///|
#borrow(result)
extern "c" fn napi_get_instance_data_raw(
  env : NapiEnv,
  result : Ref[UnmanagedBuffer],
) -> Int32 = "napi_mbt_get_instance_data"

///|
pub fn napi_set_instance_data(
  env : NapiEnv,
  data : UnmanagedBuffer,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_set_instance_data_raw(env, data),
    b"Setting instance data",
  )
}

///|
pub fn napi_get_instance_data(env : NapiEnv) -> UnmanagedBuffer raise NapiError {
  let result = Ref(moonbit_dummy_unmanaged_buffer())
  result_from_status(
    env,
    napi_get_instance_data_raw(env, result),
    b"Reading instance data",
  )
  result.val
}

///|
#borrow(result)
extern "c" fn napi_get_version_raw(
  env : NapiEnv,
  result : Ref[UInt32],
) -> Int32 = "napi_mbt_get_version"

///|
pub fn napi_version(env : NapiEnv) -> UInt32 raise NapiError {
  let result = Ref(0U)
  result_from_status(
    env,
    napi_get_version_raw(env, result),
    b"Reading N-API version",
  )
  result.val
}

///|
#borrow(result)
extern "c" fn napi_adjust_external_memory_raw(
  env : NapiEnv,
  change : Int64,
  result : Ref[Int64],
) -> Int32 = "napi_mbt_adjust_external_memory"

///|
pub fn napi_adjust_external_memory(
  env : NapiEnv,
  change : Int64,
) -> Int64 raise NapiError {
  let result = Ref(0L)
  result_from_status(
    env,
    napi_adjust_external_memory_raw(env, change, result),
    b"Adjusting external memory",
  )
  result.val
}

///|
extern "c" fn napi_detach_arraybuffer_raw(
  env : NapiEnv,
  value : NapiValue,
) -> Int32 = "napi_mbt_detach_arraybuffer"

///|
#borrow(result)
extern "c" fn napi_is_detached_arraybuffer_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Bool],
) -> Int32 = "napi_mbt_is_detached_arraybuffer"

///|
pub fn napi_detach_arraybuffer(
  env : NapiEnv,
  value : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_detach_arraybuffer_raw(env, value),
    b"Detaching ArrayBuffer",
  )
}

///|
pub fn napi_is_detached_arraybuffer(
  env : NapiEnv,
  value : NapiValue,
) -> Bool raise NapiError {
  let result = Ref(false)
  result_from_status(
    env,
    napi_is_detached_arraybuffer_raw(env, value, result),
    b"Inspecting detached ArrayBuffer",
  )
  result.val
}
