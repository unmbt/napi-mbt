///|
test "doctor accepts an optional directory and JSON output" {
  assert_eq(parse_cli(["doctor", "--json"]), ["doctor", ".", "--json"])
  assert_eq(parse_cli(["doctor", "project 空格", "--json"]), [
    "doctor", "project 空格", "--json",
  ])
}

///|
test "builder validation rejects incompatible host toolchains" {
  validate_builder("auto", true)
  validate_builder("clang", true)
  validate_builder("gcc", false)
  for (builder, host) in [("gcc", true), ("msvc", false), ("invalid", false)] {
    try validate_builder(builder, host) catch {
      _ => ()
    } noraise {
      _ => fail("Expected incompatible builder rejection")
    }
  }
}

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
test "package overlay preserves user fields flags exports and stubs" {
  let input = "// \"exports\": [\"not_a_field\"]\noptions(\"native-stub\": [\"extra.c\",], link: { \"native\": { \"cc-flags\": \"-DKEEP=1\", \"cc-link-flags\": \"\\\"my lib.a\\\"\", exports: [\"custom\",], \"other\": \"keep\" } })"
  let output = build_package_overlay(
    input,
    ["moonbit_init", "custom"],
    4,
    false,
  )
  let open = native_block(output)
  assert_eq(package_strings(package_value(output, open, "exports")), [
    "custom", "moonbit_init",
  ])
  assert_eq(package_value(output, open, "cc-flags"), Some("\"-DKEEP=1 -fPIC\""))
  assert_eq(
    package_value(output, open, "cc-link-flags"),
    Some("\"\\\"my lib.a\\\" -shared -fPIC\""),
  )
  assert_eq(package_value(output, open, "other"), Some("\"keep\""))
  let options = package_call(package_tokens(output), "options").unwrap()
  assert_eq(package_strings(package_value(output, options, "native-stub")), [
    "extra.c", "stub.c", "napi_glue.c",
  ])
  assert_true(output.has_prefix("// \"exports\": [\"not_a_field\"]\n"))
}

///|
test "package overlay accepts native DSL and rejects conflicting NAPI flags" {
  let input = "link(native(\"stub-cc-flags\": \"-DKEEP=42\", exports: [\"keep\"]))"
  let output = build_package_overlay(input, ["moonbit_init"], 4, true)
  assert_eq(
    package_strings(package_value(output, native_block(output), "exports")),
    ["keep", "moonbit_init"],
  )
  for
    input in [
      "link(native(\"stub-cc-flags\": \"-DNAPI_VERSION=1\"))", "pkgtype(kind: \"executable\")",
    ] {
    try build_package_overlay(input, [], 4, true) catch {
      _ => ()
    } noraise {
      _ => fail("Expected conflict")
    }
  }
}

///|
test "package overlay treats punctuation inside strings as data" {
  let output = build_package_overlay(
    "options(link: {\"native\": {\"other\": \"}\", \"exports\": [\"{\", \",\"]}})",
    ["moonbit_init"],
    4,
    false,
  )
  assert_eq(
    package_strings(package_value(output, native_block(output), "exports")),
    ["{", ",", "moonbit_init"],
  )
  assert_eq(package_value(output, native_block(output), "other"), Some("\"}\""))
}

///|
test "export ordering is lexical rather than length based" {
  assert_true(lexical_compare("z", "aa") > 0)
  assert_true(lexical_compare("add", "add_one") < 0)
  assert_eq(lexical_compare("same", "same"), 0)
}

///|
test "generator selector is not an accepted CLI option" {
  try parse_cli(["generate", "--generator=moonbit"]) catch {
    _ => ()
  } noraise {
    _ => fail("Node must not be available")
  }
}

///|
test "dependency PIC overlay preserves flags and rejects explicit conflicts" {
  let pure = "import { \"moonbitlang/core/json\" }"
  assert_eq(dependency_pic_overlay(pure), pure)
  for
    input in [
      "options(\"native-stub\": [\"extra.c\"])", "options(\"native-stub\": [\"extra.c\"], link: { \"native\": { \"stub-cc-flags\": \"-DUSER=1\" } })",
      "options(\"native-stub\": [\"extra.c\"])\nlink(native(\"stub-cc-flags\": \"-DUSER=1\"))",
    ] {
    let output = dependency_pic_overlay(input)
    assert_eq(
      package_value(output, native_block(output), "stub-cc-flags"),
      Some(
        if input.contains("-DUSER") {
          "\"-DUSER=1 -fPIC\""
        } else {
          "\"-fPIC\""
        },
      ),
    )
    let options = package_call(package_tokens(output), "options").unwrap()
    assert_eq(package_strings(package_value(output, options, "native-stub")), [
      "extra.c",
    ])
  }
  try
    dependency_pic_overlay(
      "options(\"native-stub\": [\"extra.c\"])\nlink(native(\"stub-cc-flags\": \"-fno-PIC\"))",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected explicit PIC conflict")
  }
}

///|
test "root PIC conflicts fail and ELF exports preserve the user contract" {
  for key in ["cc-flags", "stub-cc-flags"] {
    try
      build_package_overlay(
        "link(native(\"\{key}\": \"-fno-PIC\"))",
        [],
        4,
        false,
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("Expected PIC conflict")
    }
  }
  assert_eq(
    elf_export_map(["keep", "moonbit_init"]),
    "{\n  global:\n    \"keep\";\n    \"moonbit_init\";\n    \"napi_register_module_v1\";\n  local: *;\n};\n",
  )
}
