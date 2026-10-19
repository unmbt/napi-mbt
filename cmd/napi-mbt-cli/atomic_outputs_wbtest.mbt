///|
async test "check mode performs no writes and rejects stale output" {
  let dir = @fs.tmpdir(prefix="napi-mbt-check-")
  defer @fs.rmdir(dir, recursive=true)
  write_file(dir + "/one.txt", "same")
  let before = @fs.mtime(dir + "/one.txt")
  install_outputs(dir, [("one.txt", "same")], true)
  assert_eq(@fs.mtime(dir + "/one.txt"), before)
  assert_true(!@fs.exists(dir + "/.napi-mbt"))
  try install_outputs(dir, [("one.txt", "changed")], true) catch {
    _ => ()
  } noraise {
    _ => fail("Expected stale file rejection")
  }
  assert_eq(@fs.read_file(dir + "/one.txt").text(), "same")
  assert_true(!@fs.exists(dir + "/.napi-mbt"))
}

///|
async test "output batch restores earlier files after a later rename fails" {
  let dir = @fs.tmpdir(prefix="napi-mbt-atomic-")
  defer @fs.rmdir(dir, recursive=true)
  write_file(dir + "/one.txt", "original")
  try
    install_outputs(
      dir,
      [("one.txt", "changed"), ("missing/two.txt", "new")],
      false,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected failed installation")
  }
  assert_eq(@fs.read_file(dir + "/one.txt").text(), "original")
  assert_true(!@fs.exists(dir + "/missing/two.txt"))
  install_outputs(dir, [("one.txt", "changed"), ("two.txt", "new")], false)
  assert_eq(@fs.read_file(dir + "/one.txt").text(), "changed")
  assert_eq(@fs.read_file(dir + "/two.txt").text(), "new")
}
