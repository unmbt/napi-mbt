///|
test "configuration rejects silent mistakes and invalid feature levels" {
  for
    value in (
      [
        { "generator": "moonbit" },
        { "unknown": true },
        { "cjs": "false" },
        { "cjs": false, "esm": false },
        { "napiVersion": 4.5 },
        { "napiVersion": 11 },
        { "builder": "unknown" },
        { "targets": ["linux-x64-musl"] },
        { "targets": ["darwin-arm64", "darwin-arm64"] },
        { "features": ["promise", "promise"] },
        { "features": ["unknown"] },
        { "features": ["bigint"] },
        { "features": ["buffer"], "napiVersion": 6 },
        { "classes": {} },
        { "classes": [{}] },
        {
          "classes": [
            {
              "name": "C",
              "type": "C",
              "constructor": "C::new",
              "unknown": true,
            },
          ],
        },
        {
          "classes": [
            {
              "name": "C",
              "type": "C",
              "constructor": "C::new",
              "methods": { "f": "" },
            },
          ],
        },
        {
          "classes": [
            {
              "name": "C",
              "type": "C",
              "constructor": "C::new",
              "properties": { "x": {} },
            },
          ],
        },
        {
          "classes": [
            {
              "name": "C",
              "type": "C",
              "constructor": "C::new",
              "properties": { "x": { "get": "", "set": "C::set" } },
            },
          ],
        },
        {
          "classes": [
            {
              "name": "C",
              "type": "C",
              "constructor": "C::new",
              "properties": { "x": { "typo": "C::get" } },
            },
          ],
        },
        {
          "classes": [{ "name": "C", "type": "C", "constructor": "C::new" }],
          "napiVersion": 2,
        },
        { "features": ["callback"], "napiVersion": 2 },
        { "features": ["async"], "napiVersion": 7 },
        { "nativeTasks": { "compute": "my_task" } },
        { "nativeTasks": { "compute": "my_task" }, "napiVersion": 7 },
        { "nativeTasks": [], "napiVersion": 8 },
        { "nativeTasks": { "compute": 1 }, "napiVersion": 8 },
        { "nativeTasks": { "compute": "x;evil" }, "napiVersion": 8 },
        { "nativeTasks": { "napi_mbt_reserved": "x" }, "napiVersion": 8 },
        { "workerTasks": ["work"] },
        { "workerTasks": ["work", "work"], "napiVersion": 8 },
        { "workerPool": { "size": 0 } },
        { "workerPool": { "maxQueue": -1 } },
        { "workerPool": { "idleTimeoutMs": 0 } },
        { "workerPool": { "size": 1.5 } },
        { "workerPool": { "unknown": 1 } },
      ] : Array[Json]) {
    try parse_config(value) catch {
      _ => ()
    } noraise {
      _ => fail("Expected rejected config: " + value.stringify())
    }
  }
  let default = parse_config({})
  assert_eq(default.napi_version, 4)
  assert_true(default.cjs && default.esm)
  assert_true(!parse_config({ "cjs": false }).cjs)
  assert_true(!parse_config({ "esm": false }).esm)
  assert_eq(
    parse_config({ "features": ["buffer"], "napiVersion": 7 }).napi_version,
    7,
  )
}

///|
test "Node engines follow NAPI and module requirements" {
  assert_eq(node_engine(4, false), ">=10.16.0 <11 || >=11.8.0 <12 || >=12.0.0")
  assert_eq(node_engine(4, true), ">=12.20.0 <13 || >=14.13.1")
  assert_eq(
    node_engine(8, true),
    ">=12.22.0 <13 || >=14.17.0 <15 || >=15.12.0 <16 || >=16.0.0",
  )
  assert_eq(node_engine(10, false), ">=22.14.0 <23 || >=23.6.0")
  assert_eq(node_engine(8, true, streams=true), ">=18.0.0")
  assert_eq(node_engine(10, true, streams=true), ">=22.14.0 <23 || >=23.6.0")
}

///|
test "metadata preserves custom fields subpaths engines and files" {
  let original : Json = {
    "name": "test",
    "custom": true,
    "files": ["custom.txt", "index.cjs"],
    "engines": { "npm": ">=10" },
    "exports": { "./custom": "./custom.txt" },
  }
  let updated = package_metadata(
    object(original),
    parse_config({ "cjs": false }),
  )
  assert_true(
    updated
    is {
      "custom": true,
      "engines": { "npm": ">=10", .. },
      "exports": {
        "./custom": "./custom.txt",
        ".": {
          "import": { "types": "./index.d.mts", .. },
          "require"? : None,
          ..
        },
        ..
      },
      ..
    },
  )
  let files = strings(object(updated), "files")
  assert_true(
    files.contains("custom.txt") &&
    files.contains("index.d.mts") &&
    !files.contains("index.cjs"),
  )
}
