///|
pub fn TypeDefinition::manifest(self : TypeDefinition) -> Json {
  fn parameter(p : Parameter) -> Json {
    { "name": p.name, "type": p.value_type.runtime_name() }
  }
  match self.shape {
    StructShape(fields) =>
      { "name": self.name, "kind": "struct", "fields": fields.map(parameter) }
    EnumShape(variants) =>
      {
        "name": self.name,
        "kind": "enum",
        "variants": variants.map(v => {
          ({ "name": v.name, "parameters": v.parameters.map(parameter) } : Json)
        }),
      }
  }
}

///|
fn definition(node : @syntax.Node, filename : String) -> TypeDefinition raise {
  let location = "\{filename}:\{node.line()}"
  if child(node, "type_parameters") is Some(_) ||
    child(node, "struct_constructor_declaration") is Some(_) {
    fail(
      "\{location}: generic types and structs with custom constructors cannot be exported as values",
    )
  }
  let name = child(node, "identifier").unwrap().text()
  if !valid_identifier(name) {
    fail("\{location}: unsupported type name \{name}")
  }
  let shape = if node.kind() == "struct_definition" {
    let fields = []
    for field in node.children() {
      if field.kind() != "struct_field_declaration" {
        continue
      }
      let text = field.tokens().join("")
      guard text.find(":") is Some(colon) else {
        fail("\{location}: untyped field")
      }
      let name = child(field, "lowercase_identifier").unwrap().text()
      if !valid_identifier(name) {
        fail("\{location}: unsupported field name \{name}")
      }
      fields.push({
        name,
        value_type: parse_value_type(
          text[colon + 1:].to_owned(),
          location,
          true,
        ),
      })
    }
    StructShape(fields)
  } else {
    let variants = []
    for item in node.children() {
      if item.kind() != "enum_constructor" {
        continue
      }
      let name = child(item, "uppercase_identifier").unwrap().text()
      let parameters = []
      if child(item, "enum_constructor_payload") is Some(payload) {
        for p in payload.children() {
          if p.kind() != "constructor_parameter" {
            continue
          }
          let text = p.tokens().filter(t => t != "mut").join("")
          let (name, text) = match text.find(":") {
            Some(colon) =>
              (
                text[:colon].to_owned().replace_all(old="~", new=""),
                text[colon + 1:].to_owned(),
              )
            None => ("", text)
          }
          parameters.push({
            name,
            value_type: parse_value_type(text, location, true),
          })
        }
      }
      variants.push({ name, parameters, })
    }
    if variants.is_empty() {
      fail("\{location}: empty enum cannot be exported")
    }
    EnumShape(variants)
  }
  { name, shape, filename, line: node.line(), }
}

///|
fn resolve_type(
  value : ValueType,
  declarations : Map[String, (@syntax.Node, String)],
  types : Array[TypeDefinition],
  features : Array[String],
  location : String,
) -> Unit raise {
  match value {
    OptionType(inner) | ArrayType(inner) =>
      resolve_type(inner, declarations, types, features, location)
    NamedType(name) => {
      if types.any(t => t.name == name) {
        return
      }
      guard declarations.get(name) is Some((node, filename)) else {
        fail("\{location}: unresolved exported type \{name}")
      }
      let def = definition(node, filename)
      types.push(def)
      let fields = match def.shape {
        StructShape(fields) => fields
        EnumShape(variants) => variants.map(v => v.parameters).flatten()
      }
      for field in fields {
        if field.value_type is BufferViewType {
          fail(
            "\{filename}:\{def.line}: borrowed BufferView cannot be stored in a value type",
          )
        }
        resolve_type(
          field.value_type,
          declarations,
          types,
          features,
          "\{filename}:\{def.line}",
        )
      }
    }
    BytesType | BufferViewType =>
      if !features.contains("buffer") {
        features.push("buffer")
      }
    Int64Type | UInt64Type =>
      if !features.contains("bigint") {
        features.push("bigint")
      }
    _ => ()
  }
}

///|
fn declarations_types(types : Array[TypeDefinition]) -> String {
  let out = StringBuilder()
  for def in types {
    for input in [true, false] {
      let name = def.name + (if input { "$Input" } else { "" })
      match def.shape {
        StructShape(fields) => {
          out.write_string("export interface \{name} {\n")
          for field in fields {
            let optional = if input && field.value_type is OptionType(_) {
              "?"
            } else {
              ""
            }
            out.write_string(
              "  \{field.name}\{optional}: \{field.value_type.typescript(input~)};\n",
            )
          }
          out.write_string("}\n\n")
        }
        EnumShape(variants) => {
          let plain = variants.all(v => v.parameters.is_empty())
          let alternatives = variants.map(v => {
            let tag = Json(v.name).stringify()
            if plain {
              tag
            } else {
              "{ tag: " +
              tag +
              "; args: [" +
              v.parameters.map(p => p.value_type.typescript(input~)).join(", ") +
              "] }"
            }
          })
          out.write_string(
            "export type \{name} = " + alternatives.join(" | ") + ";\n\n",
          )
        }
      }
    }
  }
  out.to_string()
}
