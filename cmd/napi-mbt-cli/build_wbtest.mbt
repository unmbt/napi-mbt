///|
test "Visual Studio generator names come from CMake capabilities" {
  let capabilities : Json = {
    "generators": [
      { "name": "Ninja" },
      { "name": "Visual Studio 180 2100" },
      { "name": "Visual Studio 18 2026" },
      { "name": "Visual Studio 17 2022" },
    ],
  }
  assert_eq(
    visual_studio_generator("18.0.1", capabilities),
    "Visual Studio 18 2026",
  )
  assert_eq(
    visual_studio_generator("17.12.1", capabilities),
    "Visual Studio 17 2022",
  )
  try visual_studio_generator("19.0", capabilities) catch {
    _ => ()
  } noraise {
    _ => fail("Expected unsupported CMake rejection")
  }
}

///|
test "package option editing preserves unrelated configuration and escaped strings" {
  assert_eq(
    insert_package_option("options()", "link: {}"),
    "options(link: {},\n)",
  )
  let input = "options(link: { \"native\": { \"cc-link-flags\": \"/LD \\\"old.lib\\\"\", \"exports\": [\"old\"], \"other\": \"keep\" } })"
  let output = replace_option(input, "cc-link-flags", "\"-c\"")
  assert_true(output.contains("\"cc-link-flags\": \"-c\""))
  assert_true(output.contains("\"other\": \"keep\""))
  let output = replace_option(output, "exports", "[\"moonbit_init\"]")
  assert_true(output.contains("[\"moonbit_init\"]"))
}

///|
test "export ordering is lexical rather than length based" {
  assert_true(lexical_compare("z", "aa") > 0)
  assert_true(lexical_compare("add", "add_one") < 0)
  assert_eq(lexical_compare("same", "same"), 0)
}

///|
test "removed node generator is rejected" {
  try validate_generator("node") catch {
    _ => ()
  } noraise {
    _ => fail("Node must not be available")
  }
}
