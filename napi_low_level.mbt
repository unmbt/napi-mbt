/// Low-level, environment-bound wrappers around the general N-API value API.
///
/// The wrappers deliberately keep `NapiValue` opaque.  A value is only valid
/// while its creating environment is active; references and handle scopes are
/// provided for values that need to outlive one callback.

///|
pub struct NapiObject {
  priv value : NapiValue
}

///|
pub struct NapiFunction {
  priv value : NapiValue
}

///|
pub struct NapiArray {
  priv value : NapiValue
}

///|
pub enum NapiValueType {
  Undefined
  Null
  Boolean
  Number
  String
  Symbol
  Object
  Function
  External
  BigInt
}

///|
fn napi_value_type_of_int(kind : Int32) -> NapiValueType {
  match kind {
    0 => Undefined
    1 => Null
    2 => Boolean
    3 => Number
    4 => String
    5 => Symbol
    6 => Object
    7 => Function
    8 => External
    9 => BigInt
    _ => Undefined
  }
}

///|
#borrow(result)
extern "c" fn napi_get_global_raw(
  env : NapiEnv,
  result : Ref[NapiValue],
) -> Int32 = "napi_get_global"

///|
#borrow(result)
extern "c" fn napi_get_undefined_raw(
  env : NapiEnv,
  result : Ref[NapiValue],
) -> Int32 = "napi_get_undefined"

///|
#borrow(result)
extern "c" fn napi_typeof_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[Int32],
) -> Int32 = "moonbit_napi_value_kind"

///|
#borrow(result)
extern "c" fn napi_strict_equal_raw(
  env : NapiEnv,
  a : NapiValue,
  b : NapiValue,
  result : Ref[Bool],
) -> Int32 = "moonbit_napi_value_same"

///|
#borrow(key, result)
extern "c" fn napi_object_get_raw(
  env : NapiEnv,
  object : NapiValue,
  key : Bytes,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_get_named_property"

///|
#borrow(key)
extern "c" fn napi_object_set_raw(
  env : NapiEnv,
  object : NapiValue,
  key : Bytes,
  value : NapiValue,
) -> Int32 = "napi_mbt_set_named_property"

///|
#borrow(key, result)
extern "c" fn napi_object_has_raw(
  env : NapiEnv,
  object : NapiValue,
  key : Bytes,
  result : Ref[Bool],
) -> Int32 = "napi_mbt_has_named_property"

///|
#borrow(result)
extern "c" fn napi_call_array_raw(
  env : NapiEnv,
  function : NapiValue,
  receiver : NapiValue,
  args : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_call_function_array"

///|
#borrow(result)
extern "c" fn napi_new_instance_array_raw(
  env : NapiEnv,
  function : NapiValue,
  args : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_new_instance_array"

///|
#borrow(result)
extern "c" fn napi_object_keys_raw(
  env : NapiEnv,
  object : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_get_property_names"

///|
#borrow(result)
extern "c" fn napi_get_prototype_raw(
  env : NapiEnv,
  object : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_get_prototype"

///|
#borrow(result)
extern "c" fn napi_instanceof_raw(
  env : NapiEnv,
  object : NapiValue,
  ctor : NapiValue,
  result : Ref[Bool],
) -> Int32 = "napi_mbt_instanceof"

///|
#borrow(result)
extern "c" fn napi_coerce_string_raw(
  env : NapiEnv,
  value : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_coerce_to_string"

///|
#borrow(key)
extern "c" fn napi_define_data_property_raw(
  env : NapiEnv,
  object : NapiValue,
  key : Bytes,
  value : NapiValue,
  attributes : Int32,
) -> Int32 = "napi_mbt_define_data_property"

///|
#borrow(scope)
extern "c" fn napi_open_handle_scope_raw(
  env : NapiEnv,
  scope : Ref[NapiHandleScope],
) -> Int32 = "napi_open_handle_scope"

///|
extern "c" fn napi_close_handle_scope_raw(
  env : NapiEnv,
  scope : NapiHandleScope,
) -> Int32 = "napi_close_handle_scope"

///|
#borrow(scope)
extern "c" fn napi_open_escapable_scope_raw(
  env : NapiEnv,
  scope : Ref[NapiEscapableHandleScope],
) -> Int32 = "napi_open_escapable_handle_scope"

///|
extern "c" fn napi_close_escapable_scope_raw(
  env : NapiEnv,
  scope : NapiEscapableHandleScope,
) -> Int32 = "napi_close_escapable_handle_scope"

///|
#borrow(result)
extern "c" fn napi_escape_handle_raw(
  env : NapiEnv,
  scope : NapiEscapableHandleScope,
  value : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_escape_handle"

///|
pub fn napi_global(env : NapiEnv) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_get_global_raw(env, result),
    b"Reading global object",
  )
  result.val
}

///|
pub fn napi_undefined(env : NapiEnv) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_get_undefined_raw(env, result),
    b"Reading undefined",
  )
  result.val
}

///|
pub fn napi_value_type(
  env : NapiEnv,
  value : NapiValue,
) -> NapiValueType raise NapiError {
  let result = Ref(0)
  result_from_status(
    env,
    napi_typeof_raw(env, value, result),
    b"Inspecting JavaScript value",
  )
  napi_value_type_of_int(result.val)
}

///|
pub fn napi_strict_equal(
  env : NapiEnv,
  a : NapiValue,
  b : NapiValue,
) -> Bool raise NapiError {
  let result = Ref(false)
  result_from_status(
    env,
    napi_strict_equal_raw(env, a, b, result),
    b"Comparing JavaScript values",
  )
  result.val
}

///|
pub fn NapiObject::from_value(
  env : NapiEnv,
  value : NapiValue,
) -> NapiObject raise NapiError {
  match napi_value_type(env, value) {
    Object | Function => { value, }
    _ =>
      raise napi_failure(1, TypeError, "ERR_NAPI_OBJECT", "Expected an object")
  }
}

///|
pub fn NapiObject::value(self : NapiObject) -> NapiValue {
  self.value
}

///|
pub fn NapiObject::get(
  self : NapiObject,
  env : NapiEnv,
  key : String,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_object_get_raw(env, self.value, @utf8.encode(key), result),
    b"Reading property",
  )
  result.val
}

///|
pub fn NapiObject::set(
  self : NapiObject,
  env : NapiEnv,
  key : String,
  value : NapiValue,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_object_set_raw(env, self.value, @utf8.encode(key), value),
    b"Writing property",
  )
}

///|
pub fn NapiObject::has(
  self : NapiObject,
  env : NapiEnv,
  key : String,
) -> Bool raise NapiError {
  let result = Ref(false)
  result_from_status(
    env,
    napi_object_has_raw(env, self.value, @utf8.encode(key), result),
    b"Checking property",
  )
  result.val
}

///|
pub fn NapiObject::define_property(
  self : NapiObject,
  env : NapiEnv,
  key : String,
  value : NapiValue,
  attributes : Int32,
) -> Unit raise NapiError {
  result_from_status(
    env,
    napi_define_data_property_raw(
      env,
      self.value,
      @utf8.encode(key),
      value,
      attributes,
    ),
    b"Defining property",
  )
}

///|
pub fn NapiObject::keys(
  self : NapiObject,
  env : NapiEnv,
) -> Array[String] raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_object_keys_raw(env, self.value, result),
    b"Reading property names",
  )
  Array::makei(napi_array_length(env, result.val), i => {
    get_String(env, napi_array_get(env, result.val, i))
  })
}

///|
pub fn NapiObject::prototype(
  self : NapiObject,
  env : NapiEnv,
) -> NapiObject raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_get_prototype_raw(env, self.value, result),
    b"Reading prototype",
  )
  NapiObject::from_value(env, result.val)
}

///|
pub fn NapiObject::is_instance_of(
  self : NapiObject,
  env : NapiEnv,
  ctor : NapiFunction,
) -> Bool raise NapiError {
  let result = Ref(false)
  result_from_status(
    env,
    napi_instanceof_raw(env, self.value, ctor.value, result),
    b"Checking instance",
  )
  result.val
}

///|
pub fn NapiFunction::from_value(
  env : NapiEnv,
  value : NapiValue,
) -> NapiFunction raise NapiError {
  if napi_value_type(env, value) is Function {
    { value, }
  } else {
    raise napi_failure(1, TypeError, "ERR_NAPI_FUNCTION", "Expected a function")
  }
}

///|
pub fn NapiFunction::value(self : NapiFunction) -> NapiValue {
  self.value
}

///|
pub fn NapiFunction::call(
  self : NapiFunction,
  env : NapiEnv,
  receiver : NapiValue,
  args : Array[NapiValue],
) -> NapiValue raise NapiError {
  let js_args = napi_array_new(env, args.length())
  for i, arg in args {
    napi_array_set(env, js_args, i, arg)
  }
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_call_array_raw(env, self.value, receiver, js_args, result),
    b"Calling JavaScript function",
  )
  result.val
}

///|
pub fn NapiFunction::new_instance(
  self : NapiFunction,
  env : NapiEnv,
  args : Array[NapiValue],
) -> NapiObject raise NapiError {
  let js_args = napi_array_new(env, args.length())
  for i, arg in args {
    napi_array_set(env, js_args, i, arg)
  }
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_new_instance_array_raw(env, self.value, js_args, result),
    b"Constructing JavaScript object",
  )
  NapiObject::from_value(env, result.val)
}

///|
pub fn NapiArray::new(
  env : NapiEnv,
  length : Int32,
) -> NapiArray raise NapiError {
  { value: napi_array_new(env, length), }
}

///|
pub fn NapiArray::from_value(
  env : NapiEnv,
  value : NapiValue,
) -> NapiArray raise NapiError {
  let is_array = Ref(false)
  result_from_status(
    env,
    napi_is_array_raw(env, value, is_array),
    b"Inspecting Array",
  )
  if is_array.val {
    { value, }
  } else {
    raise napi_failure(1, TypeError, "ERR_NAPI_ARRAY", "Expected an Array")
  }
}

///|
pub fn NapiArray::value(self : NapiArray) -> NapiValue {
  self.value
}

///|
pub fn NapiArray::length(
  self : NapiArray,
  env : NapiEnv,
) -> Int32 raise NapiError {
  napi_array_length(env, self.value)
}

///|
pub fn NapiArray::get(
  self : NapiArray,
  env : NapiEnv,
  index : Int32,
) -> NapiValue raise NapiError {
  napi_array_get(env, self.value, index)
}

///|
pub fn NapiArray::set(
  self : NapiArray,
  env : NapiEnv,
  index : Int32,
  value : NapiValue,
) -> Unit raise NapiError {
  napi_array_set(env, self.value, index, value)
}

///|
pub struct NapiHandleScopeGuard {
  env : NapiEnv
  scope : NapiHandleScope
  mut closed : Bool
}

///|
pub fn NapiHandleScopeGuard::open(
  env : NapiEnv,
) -> NapiHandleScopeGuard raise NapiError {
  let scope = Ref(napi_dummy_handle_scope())
  result_from_status(
    env,
    napi_open_handle_scope_raw(env, scope),
    b"Opening handle scope",
  )
  { env, scope: scope.val, closed: false, }
}

///|
pub fn NapiHandleScopeGuard::close(
  self : NapiHandleScopeGuard,
) -> Unit raise NapiError {
  if !self.closed {
    self.closed = true
    result_from_status(
      self.env,
      napi_close_handle_scope_raw(self.env, self.scope),
      b"Closing handle scope",
    )
  }
}

///|
pub struct NapiEscapableHandleScopeGuard {
  env : NapiEnv
  scope : NapiEscapableHandleScope
  mut closed : Bool
}

///|
pub fn NapiEscapableHandleScopeGuard::open(
  env : NapiEnv,
) -> NapiEscapableHandleScopeGuard raise NapiError {
  let scope = Ref(napi_dummy_escapable_scope())
  result_from_status(
    env,
    napi_open_escapable_scope_raw(env, scope),
    b"Opening escapable handle scope",
  )
  { env, scope: scope.val, closed: false, }
}

///|
pub fn NapiEscapableHandleScopeGuard::escape(
  self : NapiEscapableHandleScopeGuard,
  value : NapiValue,
) -> NapiValue raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    self.env,
    napi_escape_handle_raw(self.env, self.scope, value, result),
    b"Escaping handle",
  )
  result.val
}

///|
pub fn NapiEscapableHandleScopeGuard::close(
  self : NapiEscapableHandleScopeGuard,
) -> Unit raise NapiError {
  if !self.closed {
    self.closed = true
    result_from_status(
      self.env,
      napi_close_escapable_scope_raw(self.env, self.scope),
      b"Closing escapable handle scope",
    )
  }
}

///|
extern "c" fn napi_dummy_handle_scope() -> NapiHandleScope = "moonbit_dummy_handle_scope"

///|
extern "c" fn napi_dummy_escapable_scope() -> NapiEscapableHandleScope = "moonbit_dummy_escapable_scope"

///|
pub fn napi_coerce_to_string(
  env : NapiEnv,
  value : NapiValue,
) -> String raise NapiError {
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_coerce_string_raw(env, value, result),
    b"Converting value to string",
  )
  get_String(env, result.val)
}
