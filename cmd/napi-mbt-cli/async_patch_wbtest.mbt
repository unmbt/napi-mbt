///|
test "embedded async checksum uses stable FNV1a64" {
  assert_eq(adapter_checksum(""), "cbf29ce484222325")
  assert_eq(adapter_checksum("hello"), "a430d84680aabd0b")
}

///|
test "async package import overlay preserves existing imports and configuration" {
  let source = "import { \"mine/library\" @mine }\noptions(\"native-stub\": [\"mine.c\"])\n"
  assert_eq(
    append_package_import(
      source, "moonbitlang/async/napi_host", "napi_mbt_async",
    ),
    "import {\n  \"moonbitlang/async/napi_host\" @napi_mbt_async, \"mine/library\" @mine }\noptions(\"native-stub\": [\"mine.c\"])\n",
  )
  let tests = "import { \"mine/test\" } for \"test\"\n"
  assert_true(
    append_package_import(
      tests, "moonbitlang/async/napi_host", "napi_mbt_async",
    ).has_suffix(tests),
  )
}
