///|
fn binary_u16(bytes : Bytes, offset : Int32) -> Int32 {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn binary_be_u32(bytes : Bytes, offset : Int32) -> Int64 {
  (bytes[offset].to_int64() << 24) |
  (bytes[offset + 1].to_int64() << 16) |
  (bytes[offset + 2].to_int64() << 8) |
  bytes[offset + 3].to_int64()
}

///|
fn validate_macho_slice(
  bytes : Bytes,
  offset : Int32,
  length : Int32,
  cpu : Int32,
  target : String,
) -> Unit raise {
  if offset < 0 || length < 64 || offset + length > bytes.length() {
    fail("Truncated Mach-O slice for \{target}")
  }
  if bytes[offset:offset + 4] != b"\xcf\xfa\xed\xfe" ||
    binary_u16(bytes, offset + 4) != cpu ||
    binary_u16(bytes, offset + 6) != 0x0100 ||
    binary_u16(bytes, offset + 12) != 6 {
    fail("Invalid Mach-O dynamic library for \{target}")
  }
}

///|
fn validate_artifact(bytes : Bytes, target : String) -> Unit raise {
  if bytes.length() < 64 {
    fail("Truncated native artifact for \{target}")
  }
  if target == "win32-x64-msvc" {
    if bytes[0] != b'M' || bytes[1] != b'Z' {
      fail("Expected a PE DLL for \{target}")
    }
    let offset = binary_u16(bytes, 60) | (binary_u16(bytes, 62) << 16)
    if offset < 64 ||
      offset > bytes.length() - 24 ||
      bytes[offset:offset + 4] != b"PE\x00\x00" ||
      binary_u16(bytes, offset + 4) != 0x8664 ||
      (binary_u16(bytes, offset + 22) & 0x2000) == 0 {
      fail("Invalid x64 DLL for \{target}")
    }
  } else if target.has_prefix("linux-") {
    let machine = if target.contains("arm64") { 183 } else { 62 }
    if bytes[:4] != b"\x7fELF" ||
      bytes[4] != b'\x02' ||
      bytes[5] != b'\x01' ||
      binary_u16(bytes, 16) != 3 ||
      binary_u16(bytes, 18) != machine {
      fail("Invalid 64-bit ELF shared library for \{target}")
    }
  } else if target == "darwin-universal" {
    if bytes[:4] != b"\xca\xfe\xba\xbe" && bytes[:4] != b"\xbe\xba\xfe\xca" {
      fail("Expected a Fat Mach-O binary for \{target}")
    }
    let count = binary_be_u32(bytes, 4)
    if count < 2L || count > 16L {
      fail("Invalid Fat Mach-O architecture count for \{target}")
    }
    let n = count.to_int()
    let header_end = 8 + n * 20
    if header_end > bytes.length() {
      fail("Truncated Fat Mach-O header for \{target}")
    }
    let mut has_x64 = false
    let mut has_arm64 = false
    for i in 0..<n {
      let entry = 8 + i * 20
      let cpu = binary_be_u32(bytes, entry)
      let offset = binary_be_u32(bytes, entry + 8)
      let size = binary_be_u32(bytes, entry + 12)
      if offset < header_end.to_int64() ||
        size < 64L ||
        offset + size > bytes.length().to_int64() {
        fail("Invalid Fat Mach-O slice bounds for \{target}")
      }
      if cpu == 0x01000007L {
        validate_macho_slice(bytes, offset.to_int(), size.to_int(), 7, target)
        has_x64 = true
      } else if cpu == 0x0100000CL {
        validate_macho_slice(bytes, offset.to_int(), size.to_int(), 12, target)
        has_arm64 = true
      }
    }
    if !has_x64 || !has_arm64 {
      fail("darwin-universal requires both x86_64 and arm64 slices")
    }
  } else if target.has_prefix("darwin-") {
    let cpu = if target.contains("arm64") { 12 } else { 7 }
    validate_macho_slice(bytes, 0, bytes.length(), cpu, target)
  } else {
    fail("Unsupported release target: \{target}")
  }
}

///|
async fn validate_package_version(dir : String, version : String) -> Unit {
  let path = dir + "/moon.mod"
  if @fs.exists(path) {
    let tokens = package_tokens(read_text(path))
    for i, token in tokens {
      if token.value == "version" &&
        tokens.get(i + 1).map(t => t.value) == Some("=") {
        if tokens.get(i + 2).map(t => t.value) != Some(version) {
          fail("moon.mod and package.json versions differ")
        }
      }
    }
  }
}
