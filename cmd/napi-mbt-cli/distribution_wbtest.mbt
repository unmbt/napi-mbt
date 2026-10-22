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

///|
test "ARM64 ELF and both Mach-O CPU headers are distinct" {
  let arm = Bytes::makei(64, i => {
    if i < 6 {
      b"\x7fELF\x02\x01"[i]
    } else if i == 16 {
      b'\x03'
    } else if i == 18 {
      b'\xb7'
    } else {
      b'\x00'
    }
  })
  validate_artifact(arm, "linux-arm64-gnu")
  for (target, cpu) in [("darwin-x64", b'\x07'), ("darwin-arm64", b'\x0c')] {
    let macho = Bytes::makei(64, i => {
      if i < 4 {
        b"\xcf\xfa\xed\xfe"[i]
      } else if i == 4 {
        cpu
      } else if i == 7 {
        b'\x01'
      } else if i == 12 {
        b'\x06'
      } else {
        b'\x00'
      }
    })
    validate_artifact(macho, target)
    try
      validate_artifact(
        macho,
        if target == "darwin-x64" {
          "darwin-arm64"
        } else {
          "darwin-x64"
        },
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("Expected CPU mismatch")
    }
  }
}
