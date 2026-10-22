///|
// Bounds-checked ELF64 little-endian offsets. Files larger than Int.MAX are
// deliberately rejected; shared addons do not need multi-gigabyte offsets.
fn elf_u64(bytes : Bytes, offset : Int32) -> Int32 raise {
  if offset < 0 || offset > bytes.length() - 8 {
    fail("Truncated ELF table")
  }
  let mut value = 0UL
  for i in 0..<8 {
    value = value | (bytes[offset + i].to_uint64() << (i * 8))
  }
  if value > 2147483647UL {
    fail("ELF offset exceeds supported file size")
  }
  value.to_int()
}

///|
fn elf_needed(bytes : Bytes) -> Array[String] raise {
  if bytes.length() < 64 || bytes[:6] != b"\x7fELF\x02\x01" {
    fail("Expected little-endian ELF64")
  }
  let table = elf_u64(bytes, 32)
  let size = binary_u16(bytes, 54)
  let count = binary_u16(bytes, 56)
  if size < 56 ||
    table > bytes.length() ||
    count > (bytes.length() - table) / size {
    fail("Invalid ELF program headers")
  }
  let loads : Array[(Int32, Int32, Int32)] = []
  let mut dynamic : (Int32, Int32)? = None
  for i in 0..<count {
    let header = table + i * size
    let kind = binary_u16(bytes, header) | (binary_u16(bytes, header + 2) << 16)
    if kind != 1 && kind != 2 {
      continue
    }
    let offset = elf_u64(bytes, header + 8)
    let length = elf_u64(bytes, header + 32)
    if offset > bytes.length() || length > bytes.length() - offset {
      fail("Truncated ELF segment")
    }
    if kind == 1 {
      loads.push((elf_u64(bytes, header + 16), offset, length))
    } else {
      dynamic = Some((offset, length))
    }
  }
  guard dynamic is Some((offset, length)) else {
    fail("Missing ELF dynamic segment")
  }
  let mut strings = -1
  let mut string_size = 0
  let needed = []
  let mut terminated = false
  for i in 0..<(length / 16) {
    let entry = offset + i * 16
    let tag = elf_u64(bytes, entry)
    if tag == 0 {
      terminated = true
      break
    }
    if tag == 1 {
      needed.push(elf_u64(bytes, entry + 8))
    }
    if tag == 5 {
      strings = elf_u64(bytes, entry + 8)
    }
    if tag == 10 {
      string_size = elf_u64(bytes, entry + 8)
    }
  }
  if !terminated || strings < 0 || string_size <= 0 {
    fail("Invalid ELF dynamic string table")
  }
  let mut base = -1
  for (address, offset, length) in loads {
    if strings >= address &&
      strings - address < length &&
      string_size <= length - (strings - address) {
      base = offset + strings - address
      break
    }
  }
  if base < 0 {
    fail("ELF string table is outside loaded segments")
  }
  needed.map(index => {
    if index >= string_size {
      fail("Invalid ELF dependency name")
    }
    let mut end = index
    while end < string_size && bytes[base + end] != b'\x00' {
      end += 1
    }
    if end == string_size {
      fail("Unterminated ELF dependency name")
    }
    @utf8.decode_lossy(bytes[base + index:base + end].to_owned())
  })
}

///|
fn validate_linux_libc(bytes : Bytes, target : String) -> Array[String] raise {
  let needed = elf_needed(bytes)
  let musl = if target.contains("arm64") {
    "libc.musl-aarch64.so.1"
  } else {
    "libc.musl-x86_64.so.1"
  }
  let valid = if target.has_suffix("-musl") {
    needed.contains(musl) &&
    !needed.contains("libc.so.6") &&
    !needed.contains("ld-linux-x86-64.so.2") &&
    !needed.contains("ld-linux-aarch64.so.1")
  } else {
    needed.contains("libc.so.6") &&
    !needed.any(name => name.has_prefix("libc.musl-"))
  }
  if !valid {
    fail(
      "ELF libc dependencies do not match " + target + ": " + needed.join(", "),
    )
  }
  needed
}
