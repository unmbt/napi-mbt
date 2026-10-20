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
      CallbackType(params, ret, throws) => {
        if napi_version < 3 {
          fail("\{location}: callbacks require N-API 3")
        }
        if read && !throws {
          fail("\{location}: JavaScript callback inputs must declare raise")
        }
        for p in params {
          check(p, location, true, !read)
        }
        if !(ret is UnitType) {
          check(ret, location, true, read)
        }
      }
      OptionType(inner) | ArrayType(inner) | MapType(inner) =>
        check(inner, location, true, read)
      TupleType(items) =>
        for item in items {
          check(item, location, true, read)
        }
      NamedType(name) =>
        if !definitions.contains(name) {
          fail("\{location}: unresolved exported type \{name}")
        }
      ClassType(name, js_name, id) => {
        if napi_version < 3 {
          fail("\{location}: classes require N-API 3")
        }
        guard source.classes.get(id) is Some(cls) &&
          cls.type_name == name &&
          cls.name == js_name else {
          fail("\{location}: unresolved class type \{name}")
        }
      }
      BufferViewType if nested || !read =>
        fail(
          "\{location}: BufferView is only supported as a direct synchronous parameter",
        )
      UnitType if nested || read =>
        fail("\{location}: Unit is only supported as a return type")
      Int64Type | UInt64Type if napi_version < 6 =>
        fail("\{location}: bigint requires N-API 6")
      BytesType | BufferViewType | OwnedBinaryType(_) if napi_version < 7 =>
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
  let adapters : Map[String, Bool] = Map([])
  for item in source.all_functions() {
    let location = "\{item.filename}:\{item.line}"
    if item.is_async {
      if napi_version < 8 {
        fail("\{location}: async requires N-API 8")
      }
      if item.binding
        is (ConstructorBinding(_) | GetterBinding(_) | SetterBinding(_)) {
        fail("\{location}: constructors and accessors must be synchronous")
      }
      if item.parameters.any(p => borrowed_type(p.value_type, source.types, [])) ||
        borrowed_type(item.return_type, source.types, []) {
        fail(
          "\{location}: BufferView cannot cross an async boundary; use Bytes",
        )
      }
    }
    if !valid_export(item.export_name) || adapters.contains(item.export_name) {
      fail(
        "\{location}: duplicate or invalid generated adapter: \{item.export_name}",
      )
    }
    adapters[item.export_name] = true
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
  let class_names : Map[String, Bool] = Map([])
  for id, cls in source.classes {
    if cls.id != id ||
      !valid_export(cls.name) ||
      !valid_identifier(cls.type_name) ||
      class_names.contains(cls.name) ||
      definitions.contains(cls.name) {
      fail("Invalid or conflicting class IR: \{cls.name}")
    }
    class_names[cls.name] = true
    guard cls.construct.binding is ConstructorBinding(binding_id) &&
      binding_id == id &&
      cls.construct.return_type is ClassType(name, js_name, return_id) &&
      name == cls.type_name &&
      js_name == cls.name &&
      return_id == id else {
      fail("Invalid constructor IR: \{cls.name}")
    }
    let members : Map[String, Bool] = Map([])
    for entry in cls.members {
      let item = entry.function
      let (key, binding_id) = match item.binding {
        StaticBinding(id) => ("static:" + entry.name, id)
        GetterBinding(id) => ("get:" + entry.name, id)
        SetterBinding(id) => ("set:" + entry.name, id)
        MethodBinding(id) => ("method:" + entry.name, id)
        _ => fail("Invalid class member binding")
      }
      if binding_id != id ||
        !valid_export(entry.name) ||
        entry.name == "dispose" ||
        entry.name == "constructor" ||
        members.contains(key) {
        fail("Invalid class member IR: \{entry.name}")
      }
      members[key] = true
      if !(item.binding is StaticBinding(_)) {
        guard item.parameters.get(0)
          is Some({ value_type: ClassType(_, _, receiver), .. }) &&
          receiver == id else {
          fail("Invalid class receiver IR")
        }
      }
      if item.binding is GetterBinding(_) &&
        (item.parameters.length() != 1 || item.return_type is UnitType) {
        fail("Invalid getter IR")
      }
      if item.binding is SetterBinding(_) &&
        (item.parameters.length() != 2 || !(item.return_type is UnitType)) {
        fail("Invalid setter IR")
      }
    }
  }
}
