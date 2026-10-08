///|
test "command defaults" {
  assert_eq(parse_cli(["targets"]), ["targets"])
  for command in ["init", "generate", "build", "prepublish"] {
    assert_eq(parse_cli([command]), [command, "."])
  }
}
