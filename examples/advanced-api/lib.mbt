///|
/// Read and write properties through an environment-bound low-level object.
#export_name("objectInfo")
pub fn object_info(env : NapiEnv, input : NapiObject) -> NapiObject raise {
  let output = NapiObject::from_value(env, napi_object_new(env))
  output.set(env, "name", input.get(env, "name"))
  output.set(env, "keyCount", set_Int(env, input.keys(env).length()))
  output
}

///|
/// Call a JavaScript method while keeping the receiver explicit.
#export_name("callMethod")
pub fn call_method(env : NapiEnv, input : NapiObject) -> Int32 raise {
  let function_value = NapiFunction::from_value(env, input.get(env, "add"))
  get_Int(env, function_value.call(env, input.value(), [set_Int(env, 2)]))
}

///|
/// Construct and fill an Array through the low-level wrapper.
#export_name("makeArray")
pub fn make_array(env : NapiEnv, value : Int32) -> NapiArray raise {
  let output = NapiArray::new(env, 2)
  output.set(env, 0, set_Int(env, value))
  output.set(env, 1, set_String(env, "from-moonbit"))
  output
}

///|
/// Escape one value from a nested handle scope.
#export_name("escapeValue")
pub fn escape_value(env : NapiEnv, value : String) -> NapiValue raise {
  let scope = NapiEscapableHandleScopeGuard::open(env)
  errdefer (scope.close() catch { _ => () })
  let escaped = scope.escape(set_String(env, value))
  scope.close()
  escaped
}

///|
/// Construct a JS instance; preserve the constructor's prototype and identity.
#export_name("construct")
pub fn construct(env : NapiEnv, ctor : NapiFunction) -> NapiObject raise {
  ctor.new_instance(env, [set_Int(env, 42)])
}

///|
/// Define an enumerable, non-writable, non-configurable data property.
#export_name("defineAnswer")
pub fn define_answer(env : NapiEnv, object : NapiObject) -> Unit raise {
  object.define_property(env, "answer", set_Int(env, 42), 2)
}

///|
/// Return a mutable, GC-retained external Buffer.
#export_name("externalBuffer")
pub fn external_buffer(env : NapiEnv) -> NapiValue raise {
  napi_external_buffer(env, @utf8.encode("external"))
}

///|
/// Return a mutable, GC-retained external ArrayBuffer.
#export_name("externalArrayBuffer")
pub fn external_arraybuffer(env : NapiEnv) -> NapiValue raise {
  napi_external_arraybuffer(env, @utf8.encode("arraybuffer"))
}

///|
/// Static literals receive writable copies instead of exposing read-only memory.
#export_name("literalBuffer")
pub fn literal_buffer(env : NapiEnv) -> NapiValue raise {
  napi_external_buffer(env, b"literal")
}

///|
#export_name("literalArrayBuffer")
pub fn literal_arraybuffer(env : NapiEnv) -> NapiValue raise {
  napi_external_arraybuffer(env, b"literal")
}

///|
/// Return an external Latin-1 string.
#export_name("externalString")
pub fn external_string(env : NapiEnv) -> NapiValue raise {
  let (value, _) = napi_external_string_latin1(env, b"caf\xe9")
  value
}

///|
extern "c" fn native_token() -> UnmanagedBuffer = "example_native_token"

///|
extern "c" fn is_native_token(pointer : UnmanagedBuffer) -> Bool = "example_is_native_token"

///|
extern "c" fn pointer_is_null(pointer : UnmanagedBuffer) -> Bool = "example_pointer_is_null"

///|
/// The C token has process lifetime. This External never owns or frees it.
#export_name("makeExternal")
pub fn make_external(env : NapiEnv) -> NapiExternal raise {
  NapiExternal::new(env, native_token())
}

///|
/// Return the same External value after validating its N-API type.
#export_name("externalIdentity")
pub fn external_identity(
  env : NapiEnv,
  value : NapiExternal,
) -> NapiValue raise {
  if !is_native_token(value.data(env)) {
    fail("Foreign native token")
  }
  value.value()
}

///|
#export_name("seal")
pub fn seal(env : NapiEnv, value : NapiObject) -> Unit raise {
  napi_object_seal(env, value.value())
}

///|
/// Owned DataView snapshots copy on both sides of the boundary.
#export_name("dataViewRoundtrip")
pub fn data_view_roundtrip(value : NapiDataView) -> NapiDataView {
  value
}

///|
#export_name("bigInt64Roundtrip")
pub fn bigint64_roundtrip(value : NapiBigInt64Array) -> NapiBigInt64Array {
  value
}

///|
#export_name("bigUint64Roundtrip")
pub fn biguint64_roundtrip(value : NapiBigUint64Array) -> NapiBigUint64Array {
  value
}

///|
/// Freeze an object, attach a type tag and verify the tag in the same scope.
#export_name("freezeAndTag")
pub fn freeze_and_tag(env : NapiEnv, value : NapiObject) -> Bool raise {
  let tag = NapiTypeTag::new(0x4E415049UL, 0x4D425430UL)
  napi_type_tag_object(env, value.value(), tag)
  napi_object_freeze(env, value.value())
  napi_check_object_type_tag(env, value.value(), tag)
}

///|
#export_name("globalSymbol")
pub fn global_symbol(env : NapiEnv) -> NapiSymbol raise {
  napi_symbol_for(env, "napi-mbt-example")
}

///|
#export_name("syntaxError")
pub fn syntax_error(env : NapiEnv) -> NapiValue raise {
  napi_syntax_error(env, "ERR_语法\u0000", "示例 syntax 🚀\u0000error")
}

///|
#export_name("throwSyntaxError")
pub fn throw_syntax_error(env : NapiEnv) -> Unit raise {
  napi_throw_syntax_error(
    env, "ERR_语法\u0000", "示例 syntax 🚀\u0000error",
  )
}

///|
#export_name("moduleFileName")
pub fn module_file_name(env : NapiEnv) -> String raise {
  napi_module_file_name(env)
}

///|
#export_name("propertyKey")
pub fn property_key(env : NapiEnv, name : String) -> NapiValue raise {
  napi_property_key(env, name)
}

///|
#export_name("bufferFromArrayBuffer")
pub fn buffer_from_arraybuffer(
  env : NapiEnv,
  value : NapiValue,
) -> NapiValue raise {
  napi_buffer_from_arraybuffer(env, value, 1, 2)
}

///|
/// Detach an ArrayBuffer and report its state.
#export_name("detachArrayBuffer")
pub fn detach_arraybuffer(env : NapiEnv, value : NapiValue) -> Bool raise {
  napi_detach_arraybuffer(env, value)
  napi_is_detached_arraybuffer(env, value)
}

///|
/// This standalone addon owns its instance-data slot. Never overwrite another
/// component's slot or finalizer; the static C token needs no cleanup.
#export_name("instanceData")
pub fn instance_data(env : NapiEnv) -> Bool raise {
  let pointer = napi_get_instance_data(env)
  if pointer_is_null(pointer) {
    napi_set_instance_data(env, native_token())
  } else if !is_native_token(pointer) {
    fail("Instance-data slot already in use")
  }
  is_native_token(napi_get_instance_data(env))
}

///|
#export_name("napiVersion")
pub fn napi_version_value(env : NapiEnv) -> UInt32 raise {
  napi_version(env)
}

///|
/// Encode a value to a C-owned payload and deliver it to a JavaScript callback.
#export_name("typedTsfn")
pub fn typed_tsfn(
  env : NapiEnv,
  callback : NapiValue,
  value : Int32,
) -> String raise {
  let tsfn = NapiTypedThreadsafeFunction::new(env, callback, 8, (value : Int32) => {
    @utf8.encode(value.to_string())
  })
  errdefer (ignore(tsfn.abort()) catch { _ => () })
  let status = tsfn.try_call(value)
  ignore(tsfn.release())
  match status {
    Accepted => "accepted"
    QueueFull => "queue-full"
    Closing => "closing"
  }
}

///|
/// A bounded queue cannot drain until this synchronous export returns.
#export_name("boundedTsfn")
pub fn bounded_tsfn(
  env : NapiEnv,
  callback : NapiValue,
  abort : Bool,
) -> String raise {
  let tsfn = NapiTypedThreadsafeFunction::new(env, callback, 1, (value : Int32) => {
    @utf8.encode(value.to_string())
  })
  errdefer (ignore(tsfn.abort()) catch { _ => () })
  guard tsfn.try_call(1) is Accepted else { fail("Expected first payload") }
  for _ in 0..<64 {
    guard tsfn.try_call(2) is QueueFull else { fail("Expected backpressure") }
  }
  if abort {
    ignore(tsfn.abort())
  } else {
    ignore(tsfn.release())
  }
  "queue-full"
}
