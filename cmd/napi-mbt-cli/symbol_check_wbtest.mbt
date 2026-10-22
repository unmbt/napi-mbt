///|
test "Unix symbol parser strips ELF versions and Mach-O prefixes" {
  assert_eq(
    parse_unix_symbols(
      "00000000 T read@@GLIBC_2.2.5\n00000000 T write\n                 U memcpy\n",
    ),
    ["read", "write"],
  )
  assert_eq(
    parse_unix_symbols(
      "00000000 T _read\n00000000 T __foo\n                 U _write\n",
      darwin=true,
    ),
    ["read", "_foo"],
  )
}

///|
test "Unix export collision check only rejects libc names" {
  assert_eq(
    unix_symbol_collisions(["read", "readFile", "write"], ["read", "write"]),
    ["read", "write"],
  )
  assert_eq(unix_symbol_collisions(["readFile"], ["read"]), [])
}
