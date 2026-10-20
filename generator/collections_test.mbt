///|
test "collection IR resolves nested types and emits strict tuple and record conversions" {
  let source = @generator.parse_source(
    "pub(all) struct Item { count : UInt; sample : Float }\n#export_name(\"echo\")\npub fn echo(value : Map[String, (Item, Json?)]) -> Map[String, (Item, Json?)] { value }",
    "collections.mbt",
  )
  assert_eq(source.types.length(), 1)
  let files = @generator.render(source, "fixture", 4, package_version="0.1.0")
  for (name, contents) in files {
    if name == "index.d.ts" {
      assert_true(
        contents.contains(
          "Record<string, [Item$Input, ($NapiJson | null | undefined)]>",
        ),
      )
      assert_true(contents.contains("export type $NapiJson = null"))
    }
    if name == "napi_exports.mbt" {
      assert_true(contents.contains("ERR_NAPI_TUPLE_LENGTH"))
      assert_true(contents.contains("napi_object_keys(env, value)"))
      assert_true(contents.contains("napi_read_json(env, value, _path)"))
    }
  }
}

///|
test "collections reject non-string keys and nested borrowed values" {
  for
    ty in [
      "Map[Int, String]", "Map[String, NapiBufferView]", "(Int, NapiBufferView)",
    ] {
    try {
      let parsed = @generator.parse_source(
        "#export_name(\"echo\")\npub fn echo(v : " + ty + ") -> Unit { () }",
        "invalid.mbt",
      )
      ignore(@generator.render(parsed, "fixture", 7, package_version="0.1.0"))
    } catch {
      _ => ()
    } noraise {
      _ => fail("Expected rejection of " + ty)
    }
  }
}
