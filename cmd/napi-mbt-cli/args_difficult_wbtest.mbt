///|
test "reject invalid commands options and values" {
  for
    argv in [
      ["unknown"],
      ["targets", "extra"],
      ["init", "a", "b"],
      ["build", "--unknown"],
      ["generate", "--generator"],
      ["generate", "--generator=invalid"],
      ["init", "--name"],
      ["generate", "--release"],
    ] {
    let rejected = try {
      ignore(parse_cli(argv))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg="Expected rejection: \{Repr(argv)}")
  }
}
