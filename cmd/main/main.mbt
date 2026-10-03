///|
/// Native entry point for napi-mbt.
///
/// The scanner/build implementation is still shared with the Node transport
/// while the native executable is being rolled out.  Keeping this bridge in
/// MoonBit means the installed command is a native program and does not need
/// npm to be installed globally.  Release installers set
/// `NAPI_MBT_NODE_RUNTIME` to the bundled fallback script; during development
/// the repository's `cli/bin/napi-mbt.js` is used.
const VERSION : String = "0.1.0"

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
  if argv.length() > 1 && (argv[1] == "--version" || argv[1] == "-V") {
    println(VERSION)
    return
  }
  if argv.length() > 1 && argv[1] == "targets" {
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
  for i = 1; i < argv.length(); i = i + 1 {
    args.push(argv[i])
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
