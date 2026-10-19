///|
fn validate_ir(source : ParsedSource, napi_version : Int32) -> Unit raise {
  if napi_version < 1 || napi_version > 10 {
    fail("N-API version must be between 1 and 10")
  }
  let definitions : Map[String, Bool] = Map([])
  for def in source.types {
    if !valid_identifier(def.name) || definitions.contains(def.name) {
      fail("\{def.filename}:\{def.line}: invalid or duplicate type \{def.name}")
    }
    definitions[def.name] = true
  }
  fn check(
    value : ValueType,
    location : String,
    nested : Bool,
    read : Bool,
  ) -> Unit raise {
    match value {
      OptionType(inner) | ArrayType(inner) => check(inner, location, true, read)
      NamedType(name) =>
        if !definitions.contains(name) {
          fail("\{location}: unresolved exported type \{name}")
        }
      BufferViewType if nested || !read =>
        fail(
          "\{location}: BufferView is only supported as a direct synchronous parameter",
        )
      UnitType if nested || read =>
        fail("\{location}: Unit is only supported as a return type")
      Int64Type | UInt64Type if napi_version < 6 =>
        fail("\{location}: bigint requires N-API 6")
      BytesType | BufferViewType if napi_version < 7 =>
        fail("\{location}: checked Buffer access requires N-API 7")
      _ => ()
    }
  }
  for def in source.types {
    let location = "\{def.filename}:\{def.line}"
    let fields = match def.shape {
      StructShape(fields) => fields
      EnumShape(variants) => {
        if variants.is_empty() {
          fail("\{location}: empty enum")
        }
        let names : Map[String, Bool] = Map([])
        for variant in variants {
          if !valid_identifier(variant.name) || names.contains(variant.name) {
            fail("\{location}: invalid or duplicate enum variant")
          }
          names[variant.name] = true
        }
        variants.map(v => v.parameters).flatten()
      }
    }
    for field in fields {
      check(field.value_type, location, true, true)
    }
  }
  for item in source.exports {
    let location = "\{item.filename}:\{item.line}"
    let names : Map[String, Bool] = Map([])
    for p in item.parameters {
      if !valid_identifier(p.name) || names.contains(p.name) {
        fail("\{location}: invalid or duplicate parameter \{p.name}")
      }
      names[p.name] = true
      check(p.value_type, location, false, true)
    }
    check(item.return_type, location, false, false)
  }
}
