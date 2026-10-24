///|
test "owned binary types are recursive values and require checked backing stores" {
  let source = @generator.parse_source(
    "#export_name(\"echo\")\npub fn echo(v : (NapiInt32Array, NapiArrayBuffer)) -> NapiUint8Array { abort(\"unused\") }",
    "binary.mbt",
  )
  assert_true(source.features.contains("buffer"))
  try
    ignore(@generator.render(source, "fixture", 6, package_version="0.1.0"))
  catch {
    _ => ()
  } noraise {
    _ => fail("N-API 7 required")
  }
  let files = @generator.render(source, "fixture", 7, package_version="0.1.0")
  for (name, text) in files {
    if name == "index.d.ts" {
      assert_true(text.contains("[Int32Array, ArrayBuffer]"))
      assert_true(text.contains("Uint8Array"))
    }
  }
}

///|
test "extended binary types map to BigInt arrays and DataView" {
  let source = @generator.parse_source(
    "#export_name(\"echo\")\npub fn echo(a : NapiBigInt64Array, b : NapiBigUint64Array, c : NapiDataView) -> NapiBigInt64Array { abort(\"unused\") }",
    "binary-extended.mbt",
  )
  let files = @generator.render(source, "fixture", 7, package_version="0.1.0")
  for (name, text) in files {
    if name == "index.d.ts" {
      assert_true(text.contains("BigInt64Array"))
      assert_true(text.contains("BigUint64Array"))
      assert_true(text.contains("DataView"))
    }
  }
}
