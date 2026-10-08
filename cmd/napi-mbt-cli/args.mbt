///|
fn cli_command() -> @argparse.Command {
  let directory = @argparse.PositionArg(
    "directory",
    about="Project directory",
    default_values=["."],
    num_args=ValueRange(lower=0, upper=1),
  )
  let generator = @argparse.OptionArg(
    "generator",
    long="generator",
    about="Generator: auto, moonbit, node",
  )
  let target = @argparse.OptionArg(
    "target",
    long="target",
    about="Build target",
  )
  Command(
    "napi-mbt-cli",
    version=VERSION,
    about="Generate and build MoonBit Node-API addons",
    arg_required_else_help=true,
    subcommand_required=true,
    subcommands=[
      Command(
        "init",
        about="Create the official addon template",
        positionals=[directory],
        options=[OptionArg("name", long="name", about="Package name")],
        flags=[FlagArg("force", long="force", about="Overwrite existing files")],
      ),
      Command(
        "generate",
        about="Generate bindings and loaders",
        positionals=[directory],
        options=[generator],
        flags=[
          FlagArg(
            "check",
            long="check",
            about="Check generated files without writing",
          ),
        ],
      ),
      Command(
        "build",
        about="Build the native addon",
        positionals=[directory],
        options=[generator, target],
        flags=[
          FlagArg("release", long="release", about="Release build"),
          FlagArg("dry-run", long="dry-run", about="Show build commands"),
        ],
      ),
      Command(
        "prepublish",
        about="Prepare platform npm packages",
        positionals=[directory],
        options=[target],
      ),
      Command("targets", about="List supported targets"),
    ],
  )
}

///|
fn parse_cli(argv : Array[String]) -> Array[String] raise {
  let matches = cli_command().parse(argv=argv[:])
  guard matches.subcommand is Some((command, values)) else {
    fail("A subcommand is required")
  }
  let normalized = [command]
  if command == "targets" {
    return normalized
  }
  normalized.push(values.values.get("directory").unwrap()[0])
  for option in ["name", "generator", "target"] {
    if values.values.get(option) is Some([value, ..]) {
      if option == "generator" &&
        value != "auto" &&
        value != "moonbit" &&
        value != "node" {
        fail("Unknown generator: \{value}; expected auto, moonbit or node")
      }
      normalized.push("--" + option)
      normalized.push(value)
    }
  }
  for flag in ["force", "check", "release", "dry-run"] {
    if values.flags.get(flag) == Some(true) {
      normalized.push("--" + flag)
    }
  }
  normalized
}
