///|
fn class_configurations(value : Json?) -> Array[@generator.ClassConfig] raise {
  guard value is Some(value) else { return [] }
  guard value is Array(values) else { fail("classes must be an array") }
  fn members(value : Json?) -> Array[(String, String)] raise {
    guard value is Some(value) else { return [] }
    let items = object(value)
    let names = items.keys().to_array()
    names.sort_by(lexical_compare)
    names.map(name => {
      let source = str(items, name, "")
      if source.is_empty() {
        fail("Class member \{name} requires a function name")
      }
      (name, source)
    })
  }
  values.map(value => {
    let items = object(value)
    for key in items.keys() {
      if ![
          "name", "type", "constructor", "methods", "staticMethods", "properties",
        ].contains(key) {
        fail("Unknown class field: \{key}")
      }
    }
    let properties : Array[@generator.ClassProperty] = []
    if items.get("properties") is Some(value) {
      let props = object(value)
      let names = props.keys().to_array()
      names.sort_by(lexical_compare)
      for name in names {
        let property = object(props[name])
        for key in property.keys() {
          if key != "get" && key != "set" {
            fail("Unknown class property field: \{key}")
          }
        }
        let get = str(property, "get", "")
        let set = str(property, "set", "")
        if (property.contains("get") && get.is_empty()) ||
          (property.contains("set") && set.is_empty()) {
          fail("Class accessors must be nonempty function names")
        }
        if get.is_empty() && set.is_empty() {
          fail("Class property \{name} needs get or set")
        }
        properties.push({
          name,
          getter: if get.is_empty() {
            None
          } else {
            Some(get)
          },
          setter: if set.is_empty() {
            None
          } else {
            Some(set)
          },
        })
      }
    }
    let name = str(items, "name", "")
    let type_name = str(items, "type", "")
    let construct = str(items, "constructor", "")
    if name.is_empty() || type_name.is_empty() || construct.is_empty() {
      fail("Class requires nonempty name, type and constructor")
    }
    {
      name,
      type_name,
      construct,
      properties,
      methods: members(items.get("methods")),
      static_methods: members(items.get("staticMethods")),
    }
  })
}

///|
fn class_configuration_schema() -> Json {
  let symbol : Json = { "type": "string", "minLength": 1 }
  let members : Json = { "type": "object", "additionalProperties": symbol }
  {
    "type": "array",
    "items": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "type", "constructor"],
      "properties": {
        "name": symbol,
        "type": symbol,
        "constructor": symbol,
        "methods": members,
        "staticMethods": members,
        "properties": {
          "type": "object",
          "additionalProperties": {
            "type": "object",
            "additionalProperties": false,
            "properties": { "get": symbol, "set": symbol },
            "anyOf": [{ "required": ["get"] }, { "required": ["set"] }],
          },
        },
      },
    },
  }
}
