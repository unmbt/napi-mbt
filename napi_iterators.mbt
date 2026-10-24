///|
/// A synchronous iterator owned by the current Node environment.
pub struct NapiIterator[T] {
  priv next : () -> T? raise
  priv close : () -> Unit raise
  priv mut closed : Bool
}

///|
#borrow(result)
extern "c" fn napi_iterator_current_env(result : Ref[NapiEnv]) -> Int32 = "napi_mbt_iterator_current_env"

///|
pub fn[T] NapiIterator::new(
  next : () -> T? raise,
  close~ : () -> Unit raise = fn() { () },
) -> NapiIterator[T] raise NapiError {
  let env = Ref(napi_dummy_env())
  result_from_status(
    env.val,
    napi_iterator_current_env(env),
    b"Reading current N-API environment",
  )
  { next, close, closed: false, }
}

///|
pub fn[T] NapiIterator::next(self : NapiIterator[T]) -> T? raise {
  if self.closed {
    return None
  }
  errdefer {
    self.closed = true
    (self.close)() catch {
      _ => ()
    }
  }
  let result = (self.next)()
  if result is None {
    self.closed = true
    (self.close)()
  }
  result
}

///|
pub fn[T] NapiIterator::close(self : NapiIterator[T]) -> Unit raise {
  if self.closed {
    return
  }
  self.closed = true
  (self.close)()
}

///|
#borrow(result)
extern "c" fn napi_iterator_factory(
  env : NapiEnv,
  input : Bool,
  next : NapiValue,
  close : NapiValue,
  result : Ref[NapiValue],
) -> Int32 = "napi_mbt_iterator_factory"

///|
fn[T] get_NapiIterator(
  env : NapiEnv,
  value : NapiValue,
  convert : (NapiEnv, NapiValue) -> T raise,
) -> NapiIterator[T] raise NapiError {
  let normalized = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_iterator_factory(env, true, value, napi_null(env), normalized),
    b"Reading synchronous iterator",
  )
  let next = NapiCallback::new(
    env,
    napi_field_get(env, normalized.val, "next", true),
  )
  errdefer (next.dispose() catch { _ => () })
  let close = NapiCallback::new(
    env,
    napi_field_get(env, normalized.val, "close", true),
  )
  errdefer (close.dispose() catch { _ => () })
  NapiIterator::new(
    () => {
      let item = next.call(napi_array_new(env, 0))
      napi_require_object(env, item)
      if get_Bool(env, napi_field_get(env, item, "done", true)) {
        None
      } else {
        Some(convert(env, napi_field_get(env, item, "value", true)))
      }
    },
    close=() => {
      errdefer {
        next.dispose() catch {
          _ => ()
        }
        close.dispose() catch {
          _ => ()
        }
      }
      let result = close.call(napi_array_new(env, 0))
      next.dispose() catch {
        _ => ()
      }
      close.dispose() catch {
        _ => ()
      }
      ignore(result)
    },
  )
}

///|
fn[T] set_NapiIterator(
  env : NapiEnv,
  value : NapiIterator[T],
  convert : (NapiEnv, T) -> NapiValue raise,
) -> NapiValue raise NapiError {
  let next = napi_closure_new(env, fn(env, _) {
    try {
      let result = napi_object_new(env)
      let item = value.next()
      napi_field_set(env, result, "done", set_Bool(env, item is None))
      if item is Some(item) {
        napi_field_set(env, result, "value", convert(env, item))
      }
      result
    } catch {
      error => {
        throw_napi_error(env, error)
        moonbit_dummy_napi_value()
      }
    }
  })
  let close = napi_closure_new(env, fn(env, _) {
    try {
      value.close()
      set_Unit(env, ())
    } catch {
      error => {
        throw_napi_error(env, error)
        moonbit_dummy_napi_value()
      }
    }
  })
  let result = Ref(moonbit_dummy_napi_value())
  result_from_status(
    env,
    napi_iterator_factory(env, false, next, close, result),
    b"Writing synchronous iterator",
  )
  result.val
}
