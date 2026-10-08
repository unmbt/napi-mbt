///|
pub(all) struct Parameter {
  name : String
  type_name : String
}

///|
pub(all) struct ParsedExport {
  source_name : String
  export_name : String
  parameters : Array[Parameter]
  return_type : String
  throws : Bool
  filename : String
  line : Int
}

///|
pub(all) struct ParsedSource {
  exports : Array[ParsedExport]
  features : Array[String]
}

///|
fn valid_identifier(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for i, c in value {
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      c == '_' ||
      (i > 0 && c >= '0' && c <= '9')) {
      return false
    }
  }
  true
}

///|
fn valid_export(value : String) -> Bool {
  let reserved = "auto break case char const continue default do double else enum extern float for goto if int long register return short signed sizeof static struct switch typedef union unsigned void volatile while inline restrict _Bool _Complex _Imaginary await catch class debugger delete export extends finally function import in instanceof let new super this throw try typeof var with yield implements interface package private protected public null true false"
  valid_identifier(value) && !reserved.split(" ").any(word => word == value)
}

///|
fn child(node : @syntax.Node, kind : String) -> @syntax.Node? {
  for item in node.children() {
    if item.kind() == kind {
      return Some(item)
    }
  }
  None
}

///|
fn syntax_error_line(node : @syntax.Node) -> Int {
  for item in node.children() {
    if item.has_error() || item.is_error() {
      return syntax_error_line(item)
    }
  }
  node.line()
}

///|
fn parse_function(
  node : @syntax.Node,
  filename : String,
) -> ParsedExport? raise {
  guard child(node, "attributes") is Some(attributes) else { return None }
  let attrs = attributes
    .children()
    .filter(attr => attr.tokens() is ["#", "export_name", ..])
  if attrs.is_empty() {
    return None
  }
  if attrs.length() != 1 {
    fail("\{filename}:\{node.line()}: duplicate #export_name")
  }
  let attr = attrs[0]
  let location = "\{filename}:\{attr.line()}"
  let text = attr.tokens().join("")
  guard text.find("(") is Some(begin) && text.has_suffix(")") else {
    fail("\{location}: malformed #export_name")
  }
  let raw = text[begin + 1:text.length() - 1].trim().to_owned()
  guard @json.parse(raw) is String(export_name) && valid_export(export_name) else {
    fail("\{location}: invalid export name")
  }
  let name = child(node, "function_identifier")
  guard name is Some(name) && child(node, "parameters") is Some(params) else {
    fail("\{location}: expected an ordinary function")
  }
  let parameters = []
  for p in params.children() {
    if p.kind() != "parameter" {
      continue
    }
    let text = p.tokens().join("")
    guard text.find(":") is Some(colon) else {
      fail("\{location}: parameter must have a type")
    }
    let name = text[:colon].trim().to_owned()
    let type_name = text[colon + 1:].trim().to_owned()
    if !valid_identifier(name) ||
      !["Int", "Double", "Bool", "String", "Bytes", "NapiBufferView"].contains(
        type_name,
      ) {
      fail("\{location}: unsupported parameter \{text}")
    }
    parameters.push({ name, type_name, })
  }
  let return_text = child(node, "return_type")
    .map(n => n.tokens().join(" "))
    .unwrap_or("")
  let mut ret = return_text.replace_all(old="->", new="").trim().to_owned()
  let error_annotation = child(node, "error_annotation")
    .map(n => n.text())
    .unwrap_or("")
  let throws = (ret.contains("raise") && !ret.contains("noraise")) ||
    ret.contains("!") ||
    error_annotation.has_prefix("raise")
  for separator in ["noraise", "raise", "!"] {
    if ret.find(separator) is Some(index) {
      ret = ret[:index].trim().to_owned()
    }
  }
  if ret.is_empty() {
    ret = "Unit"
  }
  if !["Int", "Double", "Bool", "String", "Bytes", "Unit"].contains(ret) {
    fail("\{location}: unsupported return type \{ret}")
  }
  let mut is_async = false
  for token in node.tokens() {
    if token == "fn" {
      break
    }
    if token == "async" {
      is_async = true
    }
  }
  if is_async || child(node, "type_parameters") is Some(_) {
    fail("\{location}: async and generic exports are unsupported")
  }
  Some({
    source_name: name.tokens().join(""),
    export_name,
    parameters,
    return_type: ret,
    throws,
    filename,
    line: attr.line(),
  })
}

///|
fn visit(
  node : @syntax.Node,
  filename : String,
  exports : Array[ParsedExport],
  features : Array[String],
) -> Unit raise {
  let kind = node.kind()
  if kind.contains("comment") || kind.contains("string") {
    return
  }
  if kind == "function_definition" {
    if parse_function(node, filename) is Some(item) {
      exports.push(item)
    }
  }
  if kind == "identifier" ||
    kind == "function_identifier" ||
    kind == "lowercase_identifier" {
    let text = node.text()
    for feature in ["threadsafe_function", "bigint", "promise"] {
      if text.has_prefix("napi_") &&
        text.contains(feature) &&
        !features.contains(feature) {
        features.push(feature)
      }
    }
  }
  for item in node.children() {
    visit(item, filename, exports, features)
  }
}

///|
/// Parse complete MoonBit syntax, then validate the supported exported signatures.
pub fn parse_source(source : String, filename : String) -> ParsedSource raise {
  let tree = @syntax.parse(source.replace_all(old="\r\n", new="\n"))
  if tree.has_error() {
    fail("\{filename}:\{syntax_error_line(tree)}: MoonBit syntax error")
  }
  let exports = []
  let features = []
  visit(tree, filename, exports, features)
  { exports, features, }
}
