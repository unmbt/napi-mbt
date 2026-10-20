///|
test "stream IR infers features and validates element lifetime" {
  let source = @generator.parse_source(
    "#export_name(\"f\")\npub fn f(x : NapiAsyncIterator[Int]) -> NapiAsyncIterator[Int] { x }",
    "stream.mbt",
  )
  assert_true(source.features.contains("streams"))
  assert_true(source.features.contains("async"))
  for
    (name, text) in @generator.render(
      source,
      "fixture",
      8,
      package_version="0.1.0",
    ) {
    if name == "index.d.ts" {
      assert_true(
        text.contains("AsyncIterable<number> | ReadableStream<number>"),
      )
      assert_true(
        text.contains("toReadableStream(options?: { signal?: AbortSignal })"),
      )
    }
  }
  for
    text in [
      "#export_name(\"f\")\npub fn f(x : NapiAsyncIterator[NapiBufferView]) -> Int { 0 }",
      "#export_name(\"f\")\npub fn f(x : NapiAsyncIterator[NapiJsPromise[Int]]) -> NapiAsyncIterator[NapiJsPromise[Int]] { x }",
    ] {
    try
      ignore(
        @generator.render(
          @generator.parse_source(text, "invalid.mbt"),
          "fixture",
          8,
          package_version="0.1.0",
        ),
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("Expected stream validation failure")
    }
  }
}
