///|
async fn universalize(
  directory : String,
  x64_path~ : String? = None,
  arm64_path~ : String? = None,
  output_path~ : String? = None,
) -> Unit {
  if !host_target().has_prefix("darwin-") {
    fail("universalize requires macOS lipo; current host is \{host_target()}")
  }
  let dir = @fs.realpath(directory)
  let root = local_artifact_root(dir)
  let x64 = x64_path.unwrap_or(root + "/darwin-x64/napi_mbt.node")
  let arm64 = arm64_path.unwrap_or(root + "/darwin-arm64/napi_mbt.node")
  let output = output_path.unwrap_or(root + "/darwin-universal/napi_mbt.node")
  if !@fs.exists(x64) {
    fail("Missing darwin-x64 addon: \{x64}")
  }
  if !@fs.exists(arm64) {
    fail("Missing darwin-arm64 addon: \{arm64}")
  }
  validate_artifact(@fs.read_binary(x64), "darwin-x64")
  validate_artifact(@fs.read_binary(arm64), "darwin-arm64")
  match output.replace_all(old="\\", new="/").rev_find("/") {
    Some(slash) if slash > 0 =>
      mkdirp(output[:slash].to_owned(), recursive=true)
    _ => ()
  }
  let lipo = require_command("lipo")
  ignore(command(lipo, ["-create", x64, arm64, "-output", output], dir))
  validate_artifact(@fs.read_binary(output), "darwin-universal")
  println("[napi-mbt] universalized \{output}")
}
