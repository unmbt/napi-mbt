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
      assert_true(text.contains("get_NapiDate"))
      assert_true(text.contains("get_NapiSymbol"))
      assert_true(text.contains("napi_set_values(env, value)"))
      assert_true(text.contains("get_NapiIterator"))
      assert_true(text.contains("get_NapiInt16Array"))
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
