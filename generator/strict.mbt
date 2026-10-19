///|
pub(all) struct Parameter {
  name : String
  value_type : ValueType
}

///|
pub(all) struct ParsedExport {
  source_name : String
  export_name : String
  parameters : Array[Parameter]
  return_type : ValueType
  throws : Bool
  is_async : Bool
  filename : String
  line : Int32
  binding : BindingKind
}

///|
pub(all) struct ParsedSource {
  exports : Array[ParsedExport]
  features : Array[String]
  types : Array[TypeDefinition]
  classes : Array[ParsedClass]
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
fn syntax_error_line(node : @syntax.Node) -> Int32 {
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
  if !child(node, "visibility")
    .map(v => v.tokens().contains("pub"))
    .unwrap_or(false) {
    fail("\{location}: #export_name requires a public function")
  }
  let text = attr.tokens().join("")
  guard text.find("(") is Some(begin) && text.has_suffix(")") else {
    fail("\{location}: malformed #export_name")
  }
  let raw = text[begin + 1:text.length() - 1].trim().to_owned()
  guard @json.parse(raw) is String(export_name) && valid_export(export_name) else {
    fail("\{location}: invalid export name")
  }
  Some(
    parse_signature(node, filename, export_name, attr.line(), FunctionBinding),
  )
}

///|
fn parse_signature(
  node : @syntax.Node,
  filename : String,
  export_name : String,
  line : Int32,
  binding : BindingKind,
) -> ParsedExport raise {
  let location = "\{filename}:\{line}"
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
    let raw_type = text[colon + 1:].trim().to_owned()
    if !valid_identifier(name) {
      fail("\{location}: unsupported parameter \{text}")
    }
    parameters.push({
      name,
      value_type: parse_value_type(raw_type, location, true),
    })
  }
  let return_text = child(node, "return_type")
    .map(n => n.tokens().join(" "))
    .unwrap_or("")
  let mut ret = return_text.trim().to_owned()
  if ret.has_prefix("->") {
    ret = ret[2:].trim().to_owned()
  }
  let error_annotation = child(node, "error_annotation")
    .map(n => n.text())
    .unwrap_or("")
  let mut throws = error_annotation.has_prefix("raise")
  let mut depth = 0
  for i, c in ret {
    if c == '(' || c == '[' {
      depth += 1
    }
    if c == ')' || c == ']' {
      depth -= 1
    }
    if depth == 0 &&
      (
        ret[i:].has_prefix(" raise") ||
        ret[i:].has_prefix(" noraise") ||
        c == '!'
      ) {
      throws = !ret[i:].has_prefix(" noraise")
      ret = ret[:i].trim().to_owned()
      break
    }
  }
  if ret.is_empty() {
    ret = "Unit"
  }
  let return_type = parse_value_type(ret, location, false)
  let mut is_async = false
  for token in node.tokens() {
    if token == "fn" {
      break
    }
    if token == "async" {
      is_async = true
    }
  }
  if child(node, "type_parameters") is Some(_) {
    fail("\{location}: generic exports are unsupported")
  }
  if is_async &&
    binding is (ConstructorBinding(_) | GetterBinding(_) | SetterBinding(_)) {
    fail("\{location}: constructors and accessors must be synchronous")
  }
  {
    source_name: name.tokens().join(""),
    export_name,
    parameters,
    return_type,
    throws,
    is_async,
    filename,
    line,
    binding,
  }
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
    for feature in ["threadsafe_function", "bigint", "promise", "async"] {
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
  parse_sources([(filename, source)])
}

///|
/// Resolve all exported types across the package before rendering any output.
pub fn parse_sources(
  sources : Array[(String, String)],
  classes~ : Array[ClassConfig] = [],
) -> ParsedSource raise {
  let exports = []
  let features = []
  let declarations : Map[String, (@syntax.Node, String)] = Map([])
  let functions : Map[String, (@syntax.Node, String)] = Map([])
  for (filename, source) in sources {
    let tree = @syntax.parse(source.replace_all(old="\r\n", new="\n"))
    if tree.has_error() {
      fail("\{filename}:\{syntax_error_line(tree)}: MoonBit syntax error")
    }
    for node in tree.children() {
      if node.kind() == "function_definition" {
        if child(node, "function_identifier") is Some(name) {
          functions[name.tokens().join("")] = (node, filename)
        }
      }
      if node.kind() == "struct_definition" || node.kind() == "enum_definition" {
        if child(node, "identifier") is Some(name) {
          let name = name.text()
          if declarations.contains(name) {
            fail("\{filename}:\{node.line()}: duplicate type \{name}")
          }
          declarations[name] = (node, filename)
        }
      }
    }
    visit(tree, filename, exports, features)
  }
  let types : Array[TypeDefinition] = []
  for i, item in exports {
    exports[i] = class_function(item, classes)
  }
  let parsed = {
    exports,
    features,
    types,
    classes: parse_classes(classes, functions, declarations),
  }
  if !classes.is_empty() {
    features.push("class")
  }
  for item in parsed.all_functions() {
    let location = "\{item.filename}:\{item.line}"
    if item.is_async && !features.contains("async") {
      features.push("async")
    }
    for p in item.parameters {
      resolve_type(
        p.value_type,
        declarations,
        types,
        features,
        location,
        classes,
      )
    }
    resolve_type(
      item.return_type,
      declarations,
      types,
      features,
      location,
      classes,
    )
  }
  for item in parsed.all_functions() {
    if item.is_async {
      for p in item.parameters {
        if borrowed_type(p.value_type, types, []) {
          fail(
            "\{item.filename}:\{item.line}: BufferView cannot cross an async boundary; use Bytes",
          )
        }
      }
      if borrowed_type(item.return_type, types, []) {
        fail(
          "\{item.filename}:\{item.line}: BufferView cannot cross an async boundary; use Bytes",
        )
      }
    }
  }
  parsed
}
