///|
fn binary_u16(bytes : Bytes, offset : Int32) -> Int32 {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
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
  } else if target.has_prefix("darwin-") {
    let cpu = if target.contains("arm64") { 12 } else { 7 }
    if bytes[:4] != b"\xcf\xfa\xed\xfe" ||
      binary_u16(bytes, 4) != cpu ||
      binary_u16(bytes, 6) != 0x0100 ||
      binary_u16(bytes, 12) != 6 {
      fail("Invalid Mach-O dynamic library for \{target}")
    }
  } else {
    fail("Unsupported release target: \{target}")
  }
}

///|
async fn validate_package_version(dir : String, version : String) -> Unit {
  let path = dir + "/moon.mod"
  if @fs.exists(path) {
    let tokens = package_tokens(@fs.read_file(path).text())
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
