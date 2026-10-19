///|
fn jsdoc(lines : Array[String], indent~ : String = "") -> String {
  if lines.is_empty() {
    return ""
  }
  indent +
  "/**\n" +
  lines
  .map(line => indent + " * " + line.replace_all(old="*/", new="* / "))
  .join("\n") +
  "\n" +
  indent +
  " */\n"
}

///|
/// Error documentation shares the same validated signature as code generation.
pub fn ParsedExport::error_contract(self : ParsedExport) -> Array[String] {
  let lines = [
    "Node-API errors carry code, status and context; existing JS exceptions preserve identity.",
  ]
  if !self.parameters.is_empty() {
    lines.push("Argument conversion failure prevents business execution.")
  }
  if self.throws || self.is_async {
    lines.push(
      "Business errors use ERR_NAPI_CALL unless they already carry NapiError details.",
    )
  }
  if self.binding is (MethodBinding(_) | GetterBinding(_) | SetterBinding(_)) {
    lines.push(
      "Foreign, forged and disposed receivers are rejected before execution.",
    )
  }
  if self.is_async {
    lines.push(
      "Failures reject the Promise; cancellation rejects with signal.reason or ABORT_ERR.",
    )
  }
  lines
}

///|
fn export_documentation(item : ParsedExport, indent~ : String = "") -> String {
  let lines = item.documentation.copy()
  for line in item.error_contract() {
    lines.push((if item.is_async { "@remarks " } else { "@throws " }) + line)
  }
  jsdoc(lines, indent~)
}
