///|
test "strict parser validates complete syntax and ignores comments and strings" {
  let source =
    #|// #export_name("fake")
    #|let example = "#export_name(\"fake\") napi_bigint"
    #|#export_name("sum")
    #|pub fn add(
    #| a : Int,
    #| b : Int,
    #|) -> Int { a + b }
  let parsed = @generator.parse_source(source, "fixture.mbt")
  assert_eq(parsed.exports.length(), 1)
  assert_eq(parsed.exports[0].return_type, "Int")
  assert_eq(parsed.exports[0].parameters.length(), 2)
  assert_eq(parsed.features.length(), 0)
  assert_eq(
    @generator.parse_source(
      source.replace_all(old="\n", new="\r\n"),
      "fixture.mbt",
    ).exports[0].line,
    parsed.exports[0].line,
  )
}

///|
test "strict parser rejects unsupported and malformed exports" {
  for
    source in [
      "#export_name\npub fn f() -> Unit { () }", "pub fn broken(", "#export_name(\"class\")\npub fn f() -> Unit { () }",
      "#export_name(\"x\")\npub fn f(a : Int64) -> Unit { () }", "#export_name(\"x\")\npub fn f(a~ : Int) -> Unit { () }",
    ] {
    try @generator.parse_source(source, "invalid.mbt") catch {
      _ => ()
    } noraise {
      _ => fail("Expected rejection")
    }
  }
}

///|
test "strict emitter invalidates borrowed buffer after call on success and error" {
  let parsed = @generator.parse_source(
    "#export_name(\"touch\")\npub fn touch(buf : NapiBufferView) -> Unit raise { () }",
    "a.mbt",
  )
  assert_true(parsed.exports[0].throws)
  let output = @generator.adapters(parsed.exports)
  assert_true(output.contains("touch(p0) catch"))
  assert_true(output.contains("p0.invalidate()"))
  assert_true(output.contains("return moonbit_dummy_napi_value()"))
  let call = output.find("touch(p0) catch").unwrap()
  assert_true(output.find("p0.invalidate()").unwrap() > call)
  assert_true(@generator.c_glue(parsed.exports).contains("napi_is_buffer"))
}

///|
test "zero argument Unit, noraise and Unicode source positions" {
  let source = "// 你好🌙\n#export_name(\"noop\")\npub fn noop() -> Unit noraise { () }"
  let parsed = @generator.parse_source(source, "unicode.mbt")
  assert_eq(parsed.exports[0].line, 2)
  assert_eq(parsed.exports[0].parameters.length(), 0)
  assert_true(!parsed.exports[0].throws)
  assert_true(@generator.c_glue(parsed.exports).contains("napi_value argv[1]"))
  assert_true(@generator.declarations(parsed.exports).contains("noop(): void"))
}

///|
test "N-API feature detection ignores comments and strings" {
  let parsed = @generator.parse_source(
    "fn f() {\n // napi_create_bigint_int64\n let _ = \"napi_create_promise\"\n napi_create_threadsafe_function()\n}",
    "features.mbt",
  )
  assert_eq(parsed.features, ["threadsafe_function"])
}

///|
test "Unicode source names and associated functions remain callable" {
  let unicode = @generator.parse_source(
    "#export_name(\"greet\")\nfn 问候() -> Int { 1 }", "unicode.mbt",
  )
  assert_eq(unicode.exports[0].source_name, "问候")
  assert_true(@generator.adapters(unicode.exports).contains("问候()"))
  let associated = @generator.parse_source(
    "#export_name(\"plus\")\nfn Int::plus(self : Int) -> Int { self + 1 }", "method.mbt",
  )
  assert_eq(associated.exports[0].source_name, "Int::plus")
  assert_true(@generator.adapters(associated.exports).contains("Int::plus(p0)"))
}

///|
test "signature comments and async text do not change syntax" {
  let source =
    #|#export_name("async_job")
    #|pub fn
    #| run(
    #|   a : // argument
    #|     Int,
    #| ) -> // result
    #| Int { a }
  let parsed = @generator.parse_source(source, "comments.mbt")
  assert_eq(parsed.exports[0].source_name, "run")
  assert_eq(parsed.exports[0].parameters[0].type_name, "Int")
  assert_eq(parsed.exports[0].return_type, "Int")
  for
    invalid in [
      "#export_name(\"f\")\nasync fn f() -> Unit { () }", "#export_name(\"f\")\nfn[T] f() -> Unit { () }",
    ] {
    try @generator.parse_source(invalid, "invalid.mbt") catch {
      _ => ()
    } noraise {
      _ => fail("Expected rejection")
    }
  }
}
