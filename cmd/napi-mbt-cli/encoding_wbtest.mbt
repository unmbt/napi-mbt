///|
test "external diagnostics tolerate non UTF-8 tool output" {
  assert_eq(command_output(b"ok\xff\x80\n"), "ok\uFFFD\uFFFD\n")
  assert_eq(command_output(@utf8.encode("中文 🌙\n")), "中文 🌙\n")
}

///|
async test "project text is UTF-8 and malformed input names its source" {
  let dir = @fs.tmpdir(prefix="napi-mbt-encoding-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/中文.mbt"
  let text = "/// 中文 🌙\n#export_name(\"hello\")\npub fn hello() -> String { \"你好\" }\n"
  write_text_file(path, text)
  assert_eq(@fs.read_file(path).binary(), @utf8.encode(text))
  assert_eq(read_text(path), text)
  write_file(path, b"\xff")
  try read_text(path) catch {
    error =>
      assert_true(
        error.to_string().contains("File is not valid UTF-8: " + path),
      )
  } noraise {
    _ => fail("Expected malformed project source to fail")
  }
  try read_text(dir + "/missing.mbt") catch {
    error => assert_true(!error.to_string().contains("File is not valid UTF-8"))
  } noraise {
    _ => fail("Expected missing project source to fail")
  }
}
