///|
test "release gate rejects truncated and wrong architecture binaries" {
  for target in supported_targets {
    for bytes in [b"", b"not a native module", Bytes::make(64, b'\x00')] {
      try validate_artifact(bytes, target) catch {
        _ => ()
      } noraise {
        _ => fail("Expected corrupt artifact rejection")
      }
    }
  }
  let elf = Bytes::makei(64, i => {
    if i < 6 {
      b"\x7fELF\x02\x01"[i]
    } else if i == 16 {
      b'\x03'
    } else if i == 18 {
      b'\x3e'
    } else {
      b'\x00'
    }
  })
  validate_artifact(elf, "linux-x64-gnu")
  try validate_artifact(elf, "linux-arm64-gnu") catch {
    _ => ()
  } noraise {
    _ => fail("Expected architecture mismatch")
  }
}
