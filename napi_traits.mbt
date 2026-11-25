///|
pub(open) trait FromNapiValue {
  fn from_napi_value(NapiEnv, NapiValue) -> Self raise
}

///|
pub(open) trait ToNapiValue {
  fn to_napi_value(Self, NapiEnv) -> NapiValue raise
}

///|
pub fn[T : FromNapiValue] napi_from_value(
  env : NapiEnv,
  value : NapiValue,
) -> T raise {
  T::from_napi_value(env, value)
}

///|
pub fn[T : ToNapiValue] napi_to_value(
  env : NapiEnv,
  value : T,
) -> NapiValue raise {
  T::to_napi_value(value, env)
}

///|
pub impl FromNapiValue for Int32 with fn from_napi_value(env, value) {
  get_Int(env, value)
}

///|
pub impl ToNapiValue for Int32 with fn to_napi_value(self, env) {
  set_Int(env, self)
}

///|
pub impl FromNapiValue for UInt32 with fn from_napi_value(env, value) {
  get_UInt(env, value)
}

///|
pub impl ToNapiValue for UInt32 with fn to_napi_value(self, env) {
  set_UInt(env, self)
}

///|
pub impl FromNapiValue for Float with fn from_napi_value(env, value) {
  get_Float(env, value)
}

///|
pub impl ToNapiValue for Float with fn to_napi_value(self, env) {
  set_Float(env, self)
}

///|
pub impl FromNapiValue for Double with fn from_napi_value(env, value) {
  get_Double(env, value)
}

///|
pub impl ToNapiValue for Double with fn to_napi_value(self, env) {
  set_Double(env, self)
}

///|
pub impl FromNapiValue for Bool with fn from_napi_value(env, value) {
  get_Bool(env, value)
}

///|
pub impl ToNapiValue for Bool with fn to_napi_value(self, env) {
  set_Bool(env, self)
}

///|
pub impl FromNapiValue for String with fn from_napi_value(env, value) {
  get_String(env, value)
}

///|
pub impl ToNapiValue for String with fn to_napi_value(self, env) {
  set_String(env, self)
}

///|
pub impl FromNapiValue for Bytes with fn from_napi_value(env, value) {
  get_Bytes(env, value)
}

///|
pub impl ToNapiValue for Bytes with fn to_napi_value(self, env) {
  set_Bytes(env, self)
}

///|
pub impl FromNapiValue for Int64 with fn from_napi_value(env, value) {
  get_Int64(env, value)
}

///|
pub impl ToNapiValue for Int64 with fn to_napi_value(self, env) {
  set_Int64(env, self)
}

///|
pub impl FromNapiValue for UInt64 with fn from_napi_value(env, value) {
  get_UInt64(env, value)
}

///|
pub impl ToNapiValue for UInt64 with fn to_napi_value(self, env) {
  set_UInt64(env, self)
}

///|
pub impl FromNapiValue for Unit with fn from_napi_value(_env, _value) {
  ()
}

///|
pub impl ToNapiValue for Unit with fn to_napi_value(self, env) {
  set_Unit(env, self)
}

///|
pub impl FromNapiValue for Json with fn from_napi_value(env, value) {
  napi_read_json(env, value, napi_cycle_stack)
}

///|
pub impl ToNapiValue for Json with fn to_napi_value(self, env) {
  napi_write_json(env, self, napi_write_depth.val)
}

///|
pub impl FromNapiValue for NapiDate with fn from_napi_value(env, value) {
  get_NapiDate(env, value)
}

///|
pub impl ToNapiValue for NapiDate with fn to_napi_value(self, env) {
  set_NapiDate(env, self)
}

///|
pub impl FromNapiValue for NapiSymbol with fn from_napi_value(env, value) {
  get_NapiSymbol(env, value)
}

///|
pub impl ToNapiValue for NapiSymbol with fn to_napi_value(self, env) {
  set_NapiSymbol(env, self)
}

///|
pub impl FromNapiValue for NapiObject with fn from_napi_value(env, value) {
  NapiObject::from_value(env, value)
}

///|
pub impl ToNapiValue for NapiObject with fn to_napi_value(self, _env) {
  self.value()
}

///|
pub impl FromNapiValue for NapiFunction with fn from_napi_value(env, value) {
  NapiFunction::from_value(env, value)
}

///|
pub impl ToNapiValue for NapiFunction with fn to_napi_value(self, _env) {
  self.value()
}

///|
pub impl FromNapiValue for NapiArray with fn from_napi_value(env, value) {
  NapiArray::from_value(env, value)
}

///|
pub impl ToNapiValue for NapiArray with fn to_napi_value(self, _env) {
  self.value()
}

///|
pub impl FromNapiValue for NapiExternal with fn from_napi_value(env, value) {
  NapiExternal::from_value(env, value)
}

///|
pub impl ToNapiValue for NapiExternal with fn to_napi_value(self, _env) {
  self.value()
}

///|
pub impl FromNapiValue for NapiBufferView with fn from_napi_value(env, value) {
  get_NapiBufferView(env, value)
}

///|
pub impl FromNapiValue for NapiArrayBuffer with fn from_napi_value(env, value) {
  get_NapiArrayBuffer(env, value)
}

///|
pub impl ToNapiValue for NapiArrayBuffer with fn to_napi_value(self, env) {
  set_NapiArrayBuffer(env, self)
}

///|
pub impl FromNapiValue for NapiDataView with fn from_napi_value(env, value) {
  get_NapiDataView(env, value)
}

///|
pub impl ToNapiValue for NapiDataView with fn to_napi_value(self, env) {
  set_NapiDataView(env, self)
}

///|
pub impl FromNapiValue for NapiInt8Array with fn from_napi_value(env, value) {
  get_NapiInt8Array(env, value)
}

///|
pub impl ToNapiValue for NapiInt8Array with fn to_napi_value(self, env) {
  set_NapiInt8Array(env, self)
}

///|
pub impl FromNapiValue for NapiUint8Array with fn from_napi_value(env, value) {
  get_NapiUint8Array(env, value)
}

///|
pub impl ToNapiValue for NapiUint8Array with fn to_napi_value(self, env) {
  set_NapiUint8Array(env, self)
}

///|
pub impl FromNapiValue for NapiUint8ClampedArray with fn from_napi_value(
  env,
  value,
) {
  get_NapiUint8ClampedArray(env, value)
}

///|
pub impl ToNapiValue for NapiUint8ClampedArray with fn to_napi_value(self, env) {
  set_NapiUint8ClampedArray(env, self)
}

///|
pub impl FromNapiValue for NapiInt16Array with fn from_napi_value(env, value) {
  get_NapiInt16Array(env, value)
}

///|
pub impl ToNapiValue for NapiInt16Array with fn to_napi_value(self, env) {
  set_NapiInt16Array(env, self)
}

///|
pub impl FromNapiValue for NapiUint16Array with fn from_napi_value(env, value) {
  get_NapiUint16Array(env, value)
}

///|
pub impl ToNapiValue for NapiUint16Array with fn to_napi_value(self, env) {
  set_NapiUint16Array(env, self)
}

///|
pub impl FromNapiValue for NapiInt32Array with fn from_napi_value(env, value) {
  get_NapiInt32Array(env, value)
}

///|
pub impl ToNapiValue for NapiInt32Array with fn to_napi_value(self, env) {
  set_NapiInt32Array(env, self)
}

///|
pub impl FromNapiValue for NapiUint32Array with fn from_napi_value(env, value) {
  get_NapiUint32Array(env, value)
}

///|
pub impl ToNapiValue for NapiUint32Array with fn to_napi_value(self, env) {
  set_NapiUint32Array(env, self)
}

///|
pub impl FromNapiValue for NapiFloat32Array with fn from_napi_value(env, value) {
  get_NapiFloat32Array(env, value)
}

///|
pub impl ToNapiValue for NapiFloat32Array with fn to_napi_value(self, env) {
  set_NapiFloat32Array(env, self)
}

///|
pub impl FromNapiValue for NapiFloat64Array with fn from_napi_value(env, value) {
  get_NapiFloat64Array(env, value)
}

///|
pub impl ToNapiValue for NapiFloat64Array with fn to_napi_value(self, env) {
  set_NapiFloat64Array(env, self)
}

///|
pub impl FromNapiValue for NapiBigInt64Array with fn from_napi_value(env, value) {
  get_NapiBigInt64Array(env, value)
}

///|
pub impl ToNapiValue for NapiBigInt64Array with fn to_napi_value(self, env) {
  set_NapiBigInt64Array(env, self)
}

///|
pub impl FromNapiValue for NapiBigUint64Array with fn from_napi_value(
  env,
  value,
) {
  get_NapiBigUint64Array(env, value)
}

///|
pub impl ToNapiValue for NapiBigUint64Array with fn to_napi_value(self, env) {
  set_NapiBigUint64Array(env, self)
}

///|
pub impl[T : FromNapiValue] FromNapiValue for T? with fn from_napi_value(
  env,
  value,
) {
  if napi_is_nullish(env, value) {
    None
  } else {
    Some(T::from_napi_value(env, value))
  }
}

///|
pub impl[T : ToNapiValue] ToNapiValue for T? with fn to_napi_value(self, env) {
  match self {
    None => napi_null(env)
    Some(inner) => inner.to_napi_value(env)
  }
}

///|
pub impl[T : FromNapiValue] FromNapiValue for Array[T] with fn from_napi_value(
  env,
  value,
) {
  napi_with_cycle_guard(env, value, () => {
    let length = napi_array_length(env, value)
    Array::makei(length, i => {
      T::from_napi_value(env, napi_array_get(env, value, i))
    })
  })
}

///|
pub impl[T : ToNapiValue] ToNapiValue for Array[T] with fn to_napi_value(
  self,
  env,
) {
  napi_with_depth_guard(() => {
    let result = napi_array_new(env, self.length())
    for i, element in self {
      napi_array_set(env, result, i, element.to_napi_value(env))
    }
    result
  })
}

///|
pub impl[T : FromNapiValue] FromNapiValue for Map[String, T] with fn from_napi_value(
  env,
  value,
) {
  napi_with_cycle_guard(env, value, () => {
    let result : Map[String, T] = Map([])
    for key in napi_object_keys(env, value) {
      result[key] = T::from_napi_value(env, napi_key_get(env, value, key))
    }
    result
  })
}

///|
pub impl[T : ToNapiValue] ToNapiValue for Map[String, T] with fn to_napi_value(
  self,
  env,
) {
  napi_with_depth_guard(() => {
    let result = napi_object_new(env)
    for key, item in self {
      napi_key_set(env, result, key, item.to_napi_value(env))
    }
    result
  })
}

///|
pub impl[T : FromNapiValue] FromNapiValue for NapiSet[T] with fn from_napi_value(
  env,
  value,
) {
  napi_with_cycle_guard(env, value, () => {
    let raw = napi_set_values(env, value)
    let length = napi_array_length(env, raw)
    NapiSet::new(
      Array::makei(length, i => {
        T::from_napi_value(env, napi_array_get(env, raw, i))
      }),
    )
  })
}

///|
pub impl[T : ToNapiValue] ToNapiValue for NapiSet[T] with fn to_napi_value(
  self,
  env,
) {
  napi_with_depth_guard(() => {
    let raw = napi_array_new(env, self.length())
    for i, item in self.to_array() {
      napi_array_set(env, raw, i, item.to_napi_value(env))
    }
    napi_set_new(env, raw)
  })
}

///|
pub impl[T : FromNapiValue] FromNapiValue for NapiIterator[T] with fn from_napi_value(
  env,
  value,
) {
  get_NapiIterator(env, value, T::from_napi_value)
}

///|
pub impl[T : ToNapiValue] ToNapiValue for NapiIterator[T] with fn to_napi_value(
  self,
  env,
) {
  set_NapiIterator(env, self, (env, item) => item.to_napi_value(env))
}

///|
pub impl[A : FromNapiValue, B : FromNapiValue] FromNapiValue for NapiEither[
  A,
  B,
] with fn from_napi_value(env, value) {
  A(A::from_napi_value(env, value)) catch {
    error => {
      if error is NapiError::JavaScriptException(_) ||
        (napi_is_exception_pending(env) catch { _ => false }) {
        raise error
      }
      B(B::from_napi_value(env, value))
    }
  }
}

///|
pub impl[A : ToNapiValue, B : ToNapiValue] ToNapiValue for NapiEither[A, B] with fn to_napi_value(
  self,
  env,
) {
  match self {
    A(a) => a.to_napi_value(env)
    B(b) => b.to_napi_value(env)
  }
}

///|
pub impl[A : FromNapiValue, B : FromNapiValue] FromNapiValue for (A, B) with fn from_napi_value(
  env,
  value,
) {
  napi_with_cycle_guard(env, value, () => {
    if napi_array_length(env, value) != 2 {
      raise napi_failure(
        1,
        TypeError,
        "ERR_NAPI_TUPLE_LENGTH",
        "Unexpected tuple length",
      )
    }
    (
      A::from_napi_value(env, napi_array_get(env, value, 0)),
      B::from_napi_value(env, napi_array_get(env, value, 1)),
    )
  })
}

///|
pub impl[A : ToNapiValue, B : ToNapiValue] ToNapiValue for (A, B) with fn to_napi_value(
  self,
  env,
) {
  napi_with_depth_guard(() => {
    let result = napi_array_new(env, 2)
    napi_array_set(env, result, 0, self.0.to_napi_value(env))
    napi_array_set(env, result, 1, self.1.to_napi_value(env))
    result
  })
}

///|
pub impl[A : FromNapiValue, B : FromNapiValue, C : FromNapiValue] FromNapiValue for (
  A,
  B,
  C,
) with fn from_napi_value(env, value) {
  napi_with_cycle_guard(env, value, () => {
    if napi_array_length(env, value) != 3 {
      raise napi_failure(
        1,
        TypeError,
        "ERR_NAPI_TUPLE_LENGTH",
        "Unexpected tuple length",
      )
    }
    (
      A::from_napi_value(env, napi_array_get(env, value, 0)),
      B::from_napi_value(env, napi_array_get(env, value, 1)),
      C::from_napi_value(env, napi_array_get(env, value, 2)),
    )
  })
}

///|
pub impl[A : ToNapiValue, B : ToNapiValue, C : ToNapiValue] ToNapiValue for (
  A,
  B,
  C,
) with fn to_napi_value(self, env) {
  napi_with_depth_guard(() => {
    let result = napi_array_new(env, 3)
    napi_array_set(env, result, 0, self.0.to_napi_value(env))
    napi_array_set(env, result, 1, self.1.to_napi_value(env))
    napi_array_set(env, result, 2, self.2.to_napi_value(env))
    result
  })
}

///|
pub impl[
  A : FromNapiValue,
  B : FromNapiValue,
  C : FromNapiValue,
  D : FromNapiValue,
] FromNapiValue for (A, B, C, D) with fn from_napi_value(env, value) {
  napi_with_cycle_guard(env, value, () => {
    if napi_array_length(env, value) != 4 {
      raise napi_failure(
        1,
        TypeError,
        "ERR_NAPI_TUPLE_LENGTH",
        "Unexpected tuple length",
      )
    }
    (
      A::from_napi_value(env, napi_array_get(env, value, 0)),
      B::from_napi_value(env, napi_array_get(env, value, 1)),
      C::from_napi_value(env, napi_array_get(env, value, 2)),
      D::from_napi_value(env, napi_array_get(env, value, 3)),
    )
  })
}

///|
pub impl[A : ToNapiValue, B : ToNapiValue, C : ToNapiValue, D : ToNapiValue] ToNapiValue for (
  A,
  B,
  C,
  D,
) with fn to_napi_value(self, env) {
  napi_with_depth_guard(() => {
    let result = napi_array_new(env, 4)
    napi_array_set(env, result, 0, self.0.to_napi_value(env))
    napi_array_set(env, result, 1, self.1.to_napi_value(env))
    napi_array_set(env, result, 2, self.2.to_napi_value(env))
    napi_array_set(env, result, 3, self.3.to_napi_value(env))
    result
  })
}
