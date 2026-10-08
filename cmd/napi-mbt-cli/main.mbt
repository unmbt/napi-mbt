///|
fn print_targets() -> Unit {
  println("win32-x64-msvc")
  println("darwin-x64")
  println("darwin-arm64")
  println("linux-x64-gnu")
  println("linux-arm64-gnu")
}

///|
async fn main {
  let argv = @env.args()
  let parsed = parse_cli(argv[1:].to_owned())
  if parsed[0] == "targets" {
    print_targets()
    return
  }
  let runtime = resolve_runtime()
  let node = if @env.get_env_var("OS") == Some("Windows_NT") {
    "node.exe"
  } else {
    "node"
  }
  let args : Array[String] = []
  args.push(runtime)
  for arg in parsed {
    args.push(arg)
  }
  let status = @process.run(node, args) catch {
    error => {
      println("napi-mbt: unable to start Node fallback: \{Repr(error)}")
      raise Failure("Node fallback unavailable")
    }
  }
  if status != 0 {
    raise Failure("napi-mbt fallback exited with status \{status}")
  }
}

///|
/// moon install copies only the executable. Resolve the fallback from the
/// project, or use the override supplied by the release installer.
async fn resolve_runtime() -> String {
  if @env.get_env_var("NAPI_MBT_NODE_RUNTIME") is Some(path) {
    return path
  }
  if @fs.exists("cli/bin/napi-mbt.js") {
    return @fs.realpath("cli/bin/napi-mbt.js")
  }
  let mut directory = @fs.realpath(".")
  for ;; {
    let path = directory + "/node_modules/@unmbt/napi-mbt-cli/bin/napi-mbt.js"
    if @fs.exists(path) {
      return path
    }
    let parent = @fs.realpath(directory + "/..")
    if parent == directory {
      break
    }
    directory = parent
  }
  fail(
    "Node fallback not found. Install it with npm install --save-dev @unmbt/napi-mbt-cli, or set NAPI_MBT_NODE_RUNTIME to cli/bin/napi-mbt.js.",
  )
}
