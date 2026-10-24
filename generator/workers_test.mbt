///|
test "worker tasks require owned synchronous signatures" {
  for
    source in [
      "#export_name(\"work\")\npub async fn work() -> Int { 1 }", "#export_name(\"work\")\npub fn work(value : NapiBufferView) -> Int { 1 }",
      "#export_name(\"work\")\npub fn work(value : (Int) -> Int raise) -> Int { 1 }",
      "#export_name(\"work\")\npub fn work(value : NapiSymbol) -> Int { 1 }", "#export_name(\"work\")\npub fn work(value : NapiIterator[Int]) -> Int { 1 }",
      "pub struct Item { callback : (Int) -> Int raise }\n#export_name(\"work\")\npub fn work(value : Array[Item]) -> Int { 1 }",
    ] {
    try {
      let parsed = @generator.parse_source(source, "workers.mbt")
      ignore(
        @generator.render(parsed, "workers", 8, package_version="0.1.0", worker_tasks=[
          "work",
        ]),
      )
    } catch {
      _ => ()
    } noraise {
      _ => fail("Expected rejected worker signature")
    }
  }
  let source = @generator.parse_source(
    "#export_name(\"work\")\npub fn work(x : Map[String, (Int64, NapiFloat32Array)]) -> Json { Json::null() }",
    "workers.mbt",
  )
  for
    (name, text) in @generator.render(
      source,
      "workers",
      8,
      package_version="0.1.0",
      worker_tasks=["work"],
    ) {
    if name == "index.d.ts" {
      assert_true(text.contains("Promise<$NapiJson>"))
    }
    if name == "napi_exports.mbt" {
      assert_true(text.contains("napi_mbt_adapter___napi_mbt_snapshot_work"))
    }
  }
  try
    @generator.render(source, "workers", 8, package_version="0.1.0", worker_tasks=[
      "missing",
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected unknown task error")
  }
  try
    @generator.render(source, "workers", 7, package_version="0.1.0", worker_tasks=[
      "work",
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected cleanup version error")
  }
}
