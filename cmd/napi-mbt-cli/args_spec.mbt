///|
/// Parse with core argparse and normalize arguments for native commands.
/// Missing directories default to '.', invalid commands/options raise before
/// command execution. Help/version are handled by argparse itself.
#declaration_only
fn parse_cli(argv : Array[String]) -> Array[String] raise {
  ...
}
