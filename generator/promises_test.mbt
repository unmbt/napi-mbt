///|
test "typed Promise inputs share IR and reject output or borrowed use" {
  let source = @generator.parse_source(
    "#export_name(\"f\")\npub async fn f(x : NapiJsPromise[Map[String, (Int64, Json)]]) -> Int { 1 }",
    "promise.mbt",
  )
  assert_true(source.features.contains("async"))
  for
    (name, text) in @generator.render(
      source,
      "fixture",
      8,
      package_version="0.1.0",
    ) {
    if name == "index.d.ts" {
      assert_true(text.contains("Promise<Record<string, [bigint, $NapiJson]>>"))
    }
  }
  for
    text in [
      "#export_name(\"f\")\npub fn f(x : NapiJsPromise[Int]) -> NapiJsPromise[Int] { x }",
      "pub struct Box { p : NapiJsPromise[Int] }\n#export_name(\"f\")\npub fn f(x : Box) -> Box { x }",
      "#export_name(\"f\")\npub async fn f(x : NapiJsPromise[NapiBufferView]) -> Int { 1 }",
    ] {
    try {
      let parsed = @generator.parse_source(text, "invalid-promise.mbt")
      ignore(@generator.render(parsed, "fixture", 8, package_version="0.1.0"))
    } catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid Promise type rejection")
    }
  }
}
