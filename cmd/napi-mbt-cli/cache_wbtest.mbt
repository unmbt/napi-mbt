///|
test "cache command arguments are explicit" {
  assert_eq(parse_cli(["build", "--no-cache"]), ["build", ".", "--no-cache"])
  assert_eq(parse_cli(["clean", "work", "--cache"]), [
    "clean", "work", "--cache",
  ])
  try ignore(parse_cli(["clean"])) catch {
    _ => ()
  } noraise {
    _ => fail("clean needs --cache")
  }
}

///|
async test "cache sync retains timestamps, removes stale inputs and rebuilds corrupt metadata" {
  let temp = @fs.tmpdir(prefix="napi-mbt-cache-unit-")
  defer @fs.rmdir(temp, recursive=true)
  let source = temp + "/source"
  let workspace = temp + "/workspace"
  let metadata = temp + "/inputs.json"
  mkdirp(source)
  write_text_file(source + "/keep.mbt", "same")
  write_text_file(source + "/remove.mbt", "old")
  sync_cache_tree(source, workspace, metadata)
  let stamp = @fs.mtime(workspace + "/keep.mbt")
  sync_cache_tree(source, workspace, metadata)
  assert_eq(@fs.mtime(workspace + "/keep.mbt"), stamp)
  @fs.remove(source + "/remove.mbt")
  write_text_file(source + "/new.mbt", "new")
  sync_cache_tree(source, workspace, metadata)
  assert_true(!@fs.exists(workspace + "/remove.mbt"))
  assert_eq(read_text(workspace + "/new.mbt"), "new")
  mkdirp(workspace + "/_build")
  write_text_file(workspace + "/_build/sentinel", "cached object")
  write_text_file(source + "/new.h", "changed native input")
  sync_cache_tree(source, workspace, metadata)
  assert_true(!@fs.exists(workspace + "/_build"))
  write_text_file(temp + "/outside", "preserve")
  write_text_file(metadata, "{\"../outside\":\"invalid\"}")
  sync_cache_tree(source, workspace, metadata)
  assert_eq(read_text(temp + "/outside"), "preserve")
  assert_eq(read_text(workspace + "/keep.mbt"), "same")
}
