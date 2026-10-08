///|
async fn main {
  let args = parse_cli(@env.args()[1:].to_owned())
  let options : Map[String, String] = Map([])
  let flags : Array[String] = []
  for i = 2; i < args.length(); {
    if ["--name", "--generator", "--target"].contains(args[i]) {
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
    "init" => initialize(dir, options.get("--name"), flags.contains("--force"))
    "generate" =>
      ignore(
        generate(dir, flags.contains("--check"), options.get("--generator")),
      )
    "build" =>
      build(
        dir,
        flags.contains("--release"),
        flags.contains("--dry-run"),
        options.get("--target"),
        options.get("--generator"),
      )
    "prepublish" => prepublish(dir, options.get("--target"))
    _ => fail("Unknown command")
  }
}
