///|
test "watch options and output directory are explicit" {
  assert_eq(
    parse_cli(["build", "--watch", "--verbose", "--output-dir=custom out"]),
    ["build", ".", "--output-dir", "custom out", "--watch", "--verbose"],
  )
  try parse_cli(["build", "--watch", "--dry-run"]) catch {
    _ => ()
  } noraise {
    _ => fail("Expected conflict")
  }
}

///|
test "watch excludes generated outputs and includes native inputs" {
  for
    path in [
      "napi_exports.mbt", "napi_glue.c", "index.d.mts", ".napi-mbt/build-output.json",
      "_build/output.c", "custom out/a.node", "node_modules/x/a.c", "pkg/pkg.generated.mbti",
    ] {
    assert_true(watch_ignored(path, "custom out"), msg=path)
  }
  for
    path in [
      "lib.mbt", "moon.pkg", "package.json", "native_dep/extra.c", "native_dep/include/config.h",
      "napi-mbt.json",
    ] {
    assert_true(!watch_ignored(path, "custom out"), msg=path)
  }
  assert_eq(output_path("project", Some("custom")), "project/custom")
  assert_eq(output_path("project", Some("D:/custom")), "D:/custom")
}
