///|
test "normalize options and directory for Node transport" {
  assert_eq(parse_cli(["init", "--name=demo", "--force", "my project"]), [
    "init", "my project", "--name", "demo", "--force",
  ])
  assert_eq(
    parse_cli(["generate", "--check", "--generator", "moonbit", "src"]),
    ["generate", "src", "--generator", "moonbit", "--check"],
  )
  assert_eq(
    parse_cli(["build", "--release", "--target=linux-x64-gnu", "--dry-run"]),
    ["build", ".", "--target", "linux-x64-gnu", "--release", "--dry-run"],
  )
  assert_eq(parse_cli(["prepublish", "pkg", "--target", "darwin-arm64"]), [
    "prepublish", "pkg", "--target", "darwin-arm64",
  ])
}
