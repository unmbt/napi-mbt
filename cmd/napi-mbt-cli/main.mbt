///|
async fn main {
  let args = parse_cli(@env.args()[1:].to_owned())
  let options : Map[String, String] = Map([])
  let flags : Array[String] = []
  for i = 2; i < args.length(); {
    if [
        "--name", "--target", "--output-dir", "--runtime", "--x64", "--arm64", "--output",
      ].contains(args[i]) {
      options[args[i]] = args[i + 1]
      continue i + 2
    } else {
      flags.push(args[i])
      continue i + 1
    }
  }
  if args[0] == "targets" {
    for target in supported_targets {
      println(target)
    }
    return
  }
  let dir = args[1]
  match args[0] {
    "doctor" => doctor(dir, flags.contains("--json"))
    "init" =>
      initialize(
        dir,
        options.get("--name"),
        flags.contains("--force"),
        runtime=options.get("--runtime").unwrap_or("vendored"),
      )
    "generate" => ignore(generate(dir, flags.contains("--check")))
    "clean" => clean_cache(dir)
    "build" => {
      verbose_commands.val = flags.contains("--verbose")
      if flags.contains("--watch") {
        watch_build(
          dir,
          flags.contains("--release"),
          options.get("--target"),
          options.get("--output-dir"),
          no_cache=flags.contains("--no-cache"),
        )
      } else {
        build(
          dir,
          flags.contains("--release"),
          flags.contains("--dry-run"),
          options.get("--target"),
          output_directory=options.get("--output-dir"),
          no_cache=flags.contains("--no-cache"),
        )
      }
    }
    "prepublish" => prepublish(dir, options.get("--target"))
    "universalize" =>
      universalize(
        dir,
        x64_path=options.get("--x64"),
        arm64_path=options.get("--arm64"),
        output_path=options.get("--output"),
      )
    _ => fail("Unknown command")
  }
}
