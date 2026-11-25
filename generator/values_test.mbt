///|
test "date set iterator and extended typed arrays render end to end" {
  let source = @generator.parse_source(
    "#export_name(\"roundtrip\")\npub fn roundtrip(date : NapiDate, symbol : NapiSymbol, values : NapiSet[Int], input : NapiIterator[Int], bytes : NapiInt16Array) -> (NapiDate, NapiSymbol, NapiSet[Int], NapiIterator[Int], NapiUint16Array) { (date, symbol, values, input, NapiUint16Array::new([])) }",
    "values.mbt",
  )
  let files = @generator.render(source, "fixture", 7, package_version="0.1.0")
  for (name, text) in files {
    if name == "index.d.ts" {
      assert_true(text.contains("date: Date"))
      assert_true(text.contains("symbol: symbol"))
      assert_true(text.contains("values: Set<number>"))
      assert_true(text.contains("input: Iterable<number>"))
      assert_true(text.contains("Uint16Array"))
    }
    if name == "napi_exports.mbt" {
      assert_true(text.contains("let p0 : NapiDate = napi_from_value(env, a0)"))
      assert_true(
        text.contains("let p1 : NapiSymbol = napi_from_value(env, a1)"),
      )
      assert_true(
        text.contains("let p2 : NapiSet[Int32] = napi_from_value(env, a2)"),
      )
      assert_true(
        text.contains("let p3 : NapiIterator[Int32] = napi_from_value(env, a3)"),
      )
      assert_true(
        text.contains("let p4 : NapiInt16Array = napi_from_value(env, a4)"),
      )
      assert_true(text.contains("napi_to_value(env, value.4)"))
    }
  }
}

///|
test "date requires N-API 5" {
  let source = @generator.parse_source(
    "#export_name(\"read\")\npub fn read(value : NapiDate) -> NapiDate { value }",
    "date.mbt",
  )
  try
    ignore(@generator.render(source, "fixture", 4, package_version="0.1.0"))
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected Date to require N-API 5")
  }
}

///|
test "low-level environment and JS values are injected without JS parameters" {
  let source = @generator.parse_source(
    "#export_name(\"inspect\")\npub fn inspect(env : NapiEnv, value : NapiValue, object : NapiObject) -> NapiValue { let _ = NapiObject::from_value(env, value); object.value() }",
    "low-level.mbt",
  )
  let files = @generator.render(source, "fixture", 1, package_version="0.1.0")
  for (name, text) in files {
    if name == "index.d.ts" {
      assert_true(text.contains("inspect(value: unknown, object: object)"))
    }
    if name == "napi_glue.c" {
      assert_true(text.contains("size_t argc = 2;"))
    }
    if name == "napi_exports.mbt" {
      assert_true(text.contains("let p0 = env"))
      assert_true(!text.contains("(env, env, []"))
    }
  }
}
