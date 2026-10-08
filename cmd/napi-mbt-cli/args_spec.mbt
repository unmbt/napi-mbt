///|
/// Parse with core argparse and normalize arguments for the Node transport.
/// Missing directories default to '.', invalid commands/options raise before
/// the transport starts. Help/version are handled by argparse itself.
#declaration_only
fn parse_cli(argv : Array[String]) -> Array[String] raise {
  ...
}
