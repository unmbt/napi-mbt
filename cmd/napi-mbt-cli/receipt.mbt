///|
async fn verify_receipt(
  dir : String,
  target : String,
  artifact_root : String,
) -> Unit {
  let path = dir + "/.napi-mbt/receipt-" + target + ".json"
  if !@fs.exists(path) {
    fail(
      "Missing build receipt for " +
      target +
      "; run build --release before prepublish",
    )
  }
  guard @json.parse(read_text(path))
    is {
      "schema": Number(1, ..),
      "target": String(recorded_target),
      "mode": String(mode),
      "inputs": inputs,
      "identity": identity,
      "outputs": Object(outputs),
      "binary": String(binary),
      ..
    } else {
    fail("Invalid build receipt; rebuild before prepublish")
  }
  if recorded_target != target || !["release", "debug"].contains(mode) {
    fail("A matching build receipt for " + target + " is required")
  }
  let excluded = if @fs.exists(artifact_root) {
    [@fs.realpath(artifact_root)]
  } else {
    []
  }
  if input_snapshot(dir, excluded) != inputs {
    fail("Build inputs changed; run build --release before prepublish")
  }
  if content_digest(
      @fs.read_file(artifact_root + "/" + target + "/napi_mbt.node").binary(),
    ) !=
    binary {
    fail("Binary does not match its build receipt; rebuild before prepublish")
  }
  for name, digest in outputs {
    if !generated_input_files.contains(name) {
      fail("Invalid receipt output: " + name)
    }
    if !@fs.exists(dir + "/" + name) ||
      Json(content_digest(@fs.read_file(dir + "/" + name).binary())) != digest {
      fail("Generated output does not match its build receipt: " + name)
    }
  }
  if target == host_target() {
    let toolchain = build_toolchain(dir, config(dir).builder, true)
    defer toolchain.close()
    if cache_identity(dir, toolchain, target, mode) != identity {
      fail(
        "Build toolchain or configuration changed; rebuild before prepublish",
      )
    }
  }
}
