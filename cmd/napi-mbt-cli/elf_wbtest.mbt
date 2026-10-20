///|
fn fixture_elf(dependencies : Array[String]) -> Bytes {
  let strings = @utf8.encode(dependencies.join("\u0000") + "\u0000")
  let words : Map[Int32, Int32] = {
    32: 64,
    64: 1,
    96: 512,
    120: 2,
    128: 176,
    152: 80,
    176: 5,
    184: 320,
    192: 10,
    200: strings.length(),
  }
  let mut offset = 0
  for i, name in dependencies {
    words[208 + i * 16] = 1
    words[216 + i * 16] = offset
    offset += @utf8.encode(name).length() + 1
  }
  Bytes::makei(512, i => {
    if i < 6 {
      return b"\x7fELF\x02\x01"[i]
    }
    if i == 16 {
      return b'\x03'
    }
    if i == 18 {
      return b'\x3e'
    }
    if i == 54 {
      return b'\x38'
    }
    if i == 56 {
      return b'\x02'
    }
    if i >= 320 && i < 320 + strings.length() {
      return strings[i - 320]
    }
    for start, value in words {
      if i >= start && i < start + 8 {
        return ((value.to_uint64() >> ((i - start) * 8)) & 255UL).to_byte()
      }
    }
    b'\x00'
  })
}

///|
test "ELF dependency tables reject cross-libc labeling and malformed input" {
  for
    (target, library) in [
      ("linux-x64-gnu", "libc.so.6"),
      ("linux-x64-musl", "libc.musl-x86_64.so.1"),
      ("linux-arm64-musl", "libc.musl-aarch64.so.1"),
    ] {
    let bytes = fixture_elf([library])
    assert_eq(validate_linux_libc(bytes, target), [library])
    let wrong = if target.has_suffix("-gnu") {
      "linux-x64-musl"
    } else {
      "linux-x64-gnu"
    }
    try ignore(validate_linux_libc(bytes, wrong)) catch {
      _ => ()
    } noraise {
      _ => fail("Expected libc mismatch")
    }
    for length in [0, 63, 100, 180, 324] {
      try ignore(elf_needed(bytes[:length].to_owned())) catch {
        _ => ()
      } noraise {
        _ => fail("Expected truncated ELF rejection")
      }
    }
  }
  try
    ignore(
      validate_linux_libc(
        fixture_elf(["libc.so.6", "libc.musl-x86_64.so.1"]),
        "linux-x64-musl",
      ),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Mixed libc must fail")
  }
}
