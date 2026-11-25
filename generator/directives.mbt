///|
fn is_napi_directive(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed == "@napi" || trimmed.has_prefix("@napi ")
}

///|
fn strip_napi_directives(lines : Array[String]) -> Array[String] {
  lines.filter(line => !is_napi_directive(line))
}

///|
fn napi_directives(lines : Array[String]) -> Array[String] {
  let result = []
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed == "@napi" {
      result.push("")
    } else if trimmed.has_prefix("@napi ") {
      result.push(trimmed[6:].trim().to_owned())
    }
  }
  result
}

///|
fn parse_directive_call(
  directive : String,
  location : String,
) -> (String, String?) raise {
  match directive.find("(") {
    None => (directive.trim().to_owned(), None)
    Some(open) => {
      guard directive.has_suffix(")") else {
        fail("\{location}: malformed @napi directive: \{directive}")
      }
      let keyword = directive[:open].trim().to_owned()
      let raw = directive[open + 1:directive.length() - 1].trim().to_owned()
      if raw.is_empty() {
        return (keyword, None)
      }
      guard @json.parse(raw) is String(value) else {
        fail("\{location}: @napi directive argument must be a string literal")
      }
      (keyword, Some(value))
    }
  }
}

///|
priv struct DocClassBuilder {
  name : String
  type_name : String
  location : String
  mut construct : String?
  methods : Array[(String, String)]
  static_methods : Array[(String, String)]
  properties : Array[ClassProperty]
}

///|
fn strip_method_prefix(name : String, prefix : String) -> String {
  if name.has_prefix(prefix) && name.length() > prefix.length() {
    name[prefix.length():].to_owned()
  } else {
    name
  }
}

///|
fn upsert_property_accessor(
  properties : Array[ClassProperty],
  prop_name : String,
  source : String,
  is_getter : Bool,
  location : String,
) -> Unit raise {
  for i, prop in properties {
    if prop.name == prop_name {
      if is_getter {
        if prop.getter is Some(_) {
          fail("\{location}: duplicate @napi getter for \{prop_name}")
        }
        properties[i] = { ..prop, getter: Some(source), }
      } else {
        if prop.setter is Some(_) {
          fail("\{location}: duplicate @napi setter for \{prop_name}")
        }
        properties[i] = { ..prop, setter: Some(source), }
      }
      return
    }
  }
  properties.push({
    name: prop_name,
    getter: if is_getter {
      Some(source)
    } else {
      None
    },
    setter: if is_getter {
      None
    } else {
      Some(source)
    },
  })
}

///|
fn collect_doc_directives(
  declarations : Map[String, (@syntax.Node, String)],
  functions : Map[String, (@syntax.Node, String)],
  json_classes : Array[ClassConfig],
  config_module_exports : String?,
) -> (Array[ClassConfig], String?) raise {
  let builders : Map[String, DocClassBuilder] = Map([])
  let order : Array[String] = []
  let json_type_names = json_classes.map(c => c.type_name)
  let json_js_names = json_classes.map(c => c.name)
  for type_name, entry in declarations {
    let (node, filename) = entry
    let location = "\{filename}:\{node.line()}"
    let directives = napi_directives(node.documentation())
    for directive in directives {
      let (keyword, arg) = parse_directive_call(directive, location)
      if keyword != "class" {
        fail(
          "\{location}: unsupported @napi directive on type declaration: \{directive}",
        )
      }
      if node.kind() != "struct_definition" {
        fail("\{location}: @napi class is only valid on struct definitions")
      }
      if builders.contains(type_name) {
        fail("\{location}: duplicate @napi class on \{type_name}")
      }
      let js_name = arg.unwrap_or(type_name)
      if json_type_names.contains(type_name) || json_js_names.contains(js_name) {
        fail(
          "\{location}: cannot mix JSON classes config and @napi class directives for \{type_name}",
        )
      }
      builders[type_name] = {
        name: js_name,
        type_name,
        location,
        construct: None,
        methods: [],
        static_methods: [],
        properties: [],
      }
      order.push(type_name)
    }
  }
  let mut doc_module_exports : String? = None
  for source_name, entry in functions {
    let (node, filename) = entry
    let location = "\{filename}:\{node.line()}"
    let directives = napi_directives(node.documentation())
    if directives.is_empty() {
      continue
    }
    let has_export_name = match child(node, "attributes") {
      Some(attributes) =>
        attributes
        .children()
        .any(attr => attr.tokens() is ["#", "export_name", ..])
      None => false
    }
    for directive in directives {
      let (keyword, arg) = parse_directive_call(directive, location)
      if keyword == "module_exports" {
        if arg is Some(_) {
          fail("\{location}: @napi module_exports does not accept an argument")
        }
        if has_export_name {
          fail(
            "\{location}: @napi module_exports cannot be combined with #export_name",
          )
        }
        if !child(node, "visibility")
          .map(v => v.tokens().contains("pub"))
          .unwrap_or(false) {
          fail("\{location}: @napi module_exports requires a public function")
        }
        if doc_module_exports is Some(_) || config_module_exports is Some(_) {
          fail("\{location}: duplicate moduleExports hook")
        }
        doc_module_exports = Some(source_name)
        continue
      }
      if !["constructor", "method", "static", "getter", "setter"].contains(
          keyword,
        ) {
        fail("\{location}: unknown @napi directive: \{directive}")
      }
      if has_export_name {
        fail(
          "\{location}: @napi class member directives cannot be combined with #export_name",
        )
      }
      guard source_name.find("::") is Some(sep) else {
        fail(
          "\{location}: @napi \{keyword} requires an associated method Type::fn",
        )
      }
      let type_name = source_name[:sep].to_owned()
      let raw_fn_name = source_name[sep + 2:].to_owned()
      if json_type_names.contains(type_name) {
        fail(
          "\{location}: cannot mix JSON classes config and @napi directives for \{type_name}",
        )
      }
      guard builders.get(type_name) is Some(builder) else {
        fail(
          "\{location}: @napi \{keyword} requires @napi class on struct \{type_name}",
        )
      }
      match keyword {
        "constructor" => {
          if arg is Some(_) {
            fail("\{location}: @napi constructor does not accept an argument")
          }
          if builder.construct is Some(_) {
            fail("\{location}: duplicate @napi constructor on \{type_name}")
          }
          builder.construct = Some(source_name)
        }
        "method" =>
          builder.methods.push((arg.unwrap_or(raw_fn_name), source_name))
        "static" =>
          builder.static_methods.push((arg.unwrap_or(raw_fn_name), source_name))
        "getter" =>
          upsert_property_accessor(
            builder.properties,
            arg.unwrap_or(strip_method_prefix(raw_fn_name, "get_")),
            source_name,
            true,
            location,
          )
        "setter" =>
          upsert_property_accessor(
            builder.properties,
            arg.unwrap_or(strip_method_prefix(raw_fn_name, "set_")),
            source_name,
            false,
            location,
          )
        _ => ()
      }
    }
  }
  let merged = json_classes.copy()
  for type_name in order {
    let builder = builders[type_name]
    guard builder.construct is Some(construct) else {
      fail(
        "\{builder.location}: @napi class \{type_name} requires a @napi constructor method",
      )
    }
    merged.push({
      name: builder.name,
      type_name: builder.type_name,
      construct,
      methods: builder.methods,
      static_methods: builder.static_methods,
      properties: builder.properties,
    })
  }
  let resolved_hook = match (config_module_exports, doc_module_exports) {
    (Some(name), None) | (None, Some(name)) => Some(name)
    (None, None) => None
    (Some(_), Some(_)) => fail("Duplicate moduleExports configuration")
  }
  (merged, resolved_hook)
}
