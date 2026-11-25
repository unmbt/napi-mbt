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

///|
test "darwin-universal validates Fat Mach-O with x64 and arm64 slices" {
  fn macho_slice(cpu : Byte) -> Bytes {
    Bytes::makei(64, i => {
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
  }
  fn put_be32(buf : Array[Byte], v : Int32) -> Unit {
    buf.push(((v >> 24) & 0xff).to_byte())
    buf.push(((v >> 16) & 0xff).to_byte())
    buf.push(((v >> 8) & 0xff).to_byte())
    buf.push((v & 0xff).to_byte())
  }
  fn fat_binary(cpus : Array[Int32], slice_cpus : Array[Byte]) -> Bytes {
    let buf : Array[Byte] = [b'\xca', b'\xfe', b'\xba', b'\xbe']
    put_be32(buf, cpus.length())
    let data_start = 8 + cpus.length() * 20
    for i, cpu in cpus {
      put_be32(buf, cpu)
      put_be32(buf, 0)
      put_be32(buf, data_start + i * 64)
      put_be32(buf, 64)
      put_be32(buf, 14)
    }
    for sc in slice_cpus {
      for b in macho_slice(sc) {
        buf.push(b)
      }
    }
    Bytes::from_array(buf)
  }
  let valid = fat_binary([0x01000007, 0x0100000C], [b'\x07', b'\x0c'])
  validate_artifact(valid, "darwin-universal")
  let missing_arm = fat_binary([0x01000007, 0x01000007], [b'\x07', b'\x07'])
  try validate_artifact(missing_arm, "darwin-universal") catch {
    _ => ()
  } noraise {
    _ => fail("Expected missing arm64 slice error")
  }
  let truncated = valid[:40].to_owned()
  try validate_artifact(truncated, "darwin-universal") catch {
    _ => ()
  } noraise {
    _ => fail("Expected truncated fat binary error")
  }
}
