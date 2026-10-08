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
  let runtime = @env.get_env_var("NAPI_MBT_NODE_RUNTIME").unwrap_or(
    "cli/bin/napi-mbt.js",
  )
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
