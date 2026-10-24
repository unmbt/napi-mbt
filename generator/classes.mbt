///|
pub(all) enum BindingKind {
  FunctionBinding
  ConstructorBinding(Int32)
  MethodBinding(Int32)
  StaticBinding(Int32)
  GetterBinding(Int32)
  SetterBinding(Int32)
}

///|
pub(all) struct ClassProperty {
  name : String
  getter : String?
  setter : String?
}

///|
pub(all) struct ClassConfig {
  name : String
  type_name : String
  construct : String
  methods : Array[(String, String)]
  static_methods : Array[(String, String)]
  properties : Array[ClassProperty]
}

///|
pub(all) struct ClassMember {
  name : String
  function : ParsedExport
}

///|
pub(all) struct ParsedClass {
  id : Int32
  name : String
  type_name : String
  construct : ParsedExport
  members : Array[ClassMember]
}

///|
pub fn ParsedClass::manifest(self : ParsedClass) -> Json {
  {
    "name": self.name,
    "type": self.type_name,
    "constructor": self.construct.manifest(),
    "members": self.members.map(entry => {
      let kind = match entry.function.binding {
        StaticBinding(_) => "static"
        GetterBinding(_) => "getter"
        SetterBinding(_) => "setter"
        _ => "method"
      }
      (
        {
          "name": entry.name,
          "kind": kind,
          "function": entry.function.manifest(),
        } : Json)
    }),
  }
}

///|
fn class_type(value : ValueType, configs : Array[ClassConfig]) -> ValueType {
  match value {
    NamedType(name) => {
      for id, config in configs {
        if name == config.type_name {
          return ClassType(name, config.name, id)
        }
      }
      value
    }
    OptionType(inner) => OptionType(class_type(inner, configs))
    SetType(inner) => SetType(class_type(inner, configs))
    IteratorType(inner) => IteratorType(class_type(inner, configs))
    JsPromiseType(inner) => JsPromiseType(class_type(inner, configs))
    AsyncIteratorType(inner) => AsyncIteratorType(class_type(inner, configs))
    ArrayType(inner) => ArrayType(class_type(inner, configs))
    MapType(inner) => MapType(class_type(inner, configs))
    TupleType(items) => TupleType(items.map(item => class_type(item, configs)))
    CallbackType(params, ret, throws) =>
      CallbackType(
        params.map(p => class_type(p, configs)),
        class_type(ret, configs),
        throws,
      )
    _ => value
  }
}

///|
fn class_function(
  item : ParsedExport,
  configs : Array[ClassConfig],
) -> ParsedExport {
  {
    source_name: item.source_name,
    export_name: item.export_name,
    parameters: item.parameters.map(p => {
      name: p.name,
      value_type: class_type(p.value_type, configs),
    }),
    return_type: class_type(item.return_type, configs),
    throws: item.throws,
    is_async: item.is_async,
    filename: item.filename,
    line: item.line,
    binding: item.binding,
    documentation: item.documentation,
  }
}

///|
fn parse_classes(
  configs : Array[ClassConfig],
  functions : Map[String, (@syntax.Node, String)],
  declarations : Map[String, (@syntax.Node, String)],
) -> Array[ParsedClass] raise {
  let classes = []
  let names : Map[String, Bool] = Map([])
  let type_names : Map[String, Bool] = Map([])
  for id, config in configs {
    if !valid_export(config.name) ||
      names.contains(config.name) ||
      type_names.contains(config.type_name) {
      fail("Invalid or duplicate class name/type: \{config.name}")
    }
    names[config.name] = true
    type_names[config.type_name] = true
    guard declarations.get(config.type_name) is Some((node, filename)) else {
      fail("Unresolved class type: \{config.type_name}")
    }
    if node.kind() != "struct_definition" ||
      child(node, "type_parameters") is Some(_) {
      fail("\{filename}:\{node.line()}: class requires a concrete struct")
    }
    fn function(
      source : String,
      suffix : String,
      binding : BindingKind,
    ) -> ParsedExport raise {
      guard functions.get(source) is Some((node, filename)) else {
        fail("Unknown class member function: \{source}")
      }
      class_function(
        parse_signature(
          node,
          filename,
          "class_\{id}_" + suffix,
          node.line(),
          binding,
        ),
        configs,
      )
    }
    let construct = function(
      config.construct,
      "construct",
      ConstructorBinding(id),
    )
    guard construct.return_type is ClassType(_, _, result_id) && result_id == id else {
      fail("Class constructor must return \{config.type_name}")
    }
    let members : Array[ClassMember] = []
    let member_names : Map[String, Bool] = {
      "dispose": true,
      "constructor": true,
    }
    fn check_name(name : String) -> Unit raise {
      if !valid_export(name) || member_names.contains(name) {
        fail("Invalid or duplicate class member: \{config.name}.\{name}")
      }
      member_names[name] = true
    }
    fn instance(
      source : String,
      suffix : String,
      binding : BindingKind,
    ) -> ParsedExport raise {
      let fn_item = function(source, suffix, binding)
      guard fn_item.parameters.get(0)
        is Some({ value_type: ClassType(_, _, receiver), .. }) &&
        receiver == id else {
        fail("\{source} must take \{config.type_name} as its first parameter")
      }
      fn_item
    }
    for i, (name, source) in config.methods {
      check_name(name)
      members.push({
        name,
        function: instance(source, "method_\{i}", MethodBinding(id)),
      })
    }
    for i, property in config.properties {
      check_name(property.name)
      if property.getter is Some(source) {
        let fn_item = instance(source, "get_\{i}", GetterBinding(id))
        if fn_item.parameters.length() != 1 || fn_item.return_type is UnitType {
          fail(
            "Getter \{source} must take only its receiver and return a value",
          )
        }
        members.push({ name: property.name, function: fn_item, })
      }
      if property.setter is Some(source) {
        let fn_item = instance(source, "set_\{i}", SetterBinding(id))
        if fn_item.parameters.length() != 2 ||
          !(fn_item.return_type is UnitType) {
          fail(
            "Setter \{source} must take its receiver and value and return Unit",
          )
        }
        members.push({ name: property.name, function: fn_item, })
      }
    }
    let static_names : Map[String, Bool] = { "prototype": true }
    for i, (name, source) in config.static_methods {
      if !valid_export(name) || static_names.contains(name) {
        fail("Invalid or duplicate static method: \{config.name}.\{name}")
      }
      static_names[name] = true
      members.push({
        name,
        function: function(source, "static_\{i}", StaticBinding(id)),
      })
    }
    classes.push({
      id,
      name: config.name,
      type_name: config.type_name,
      construct,
      members,
    })
  }
  classes
}

///|
fn ParsedSource::all_functions(self : ParsedSource) -> Array[ParsedExport] {
  let result = self.exports.copy()
  for cls in self.classes {
    result.push(cls.construct)
    for fn_item in cls.members {
      result.push(fn_item.function)
    }
  }
  result
}

///|
pub fn ParsedSource::native_exports(self : ParsedSource) -> Array[String] {
  let result = ["moonbit_init"]
  for item in self.all_functions() {
    result.push("napi_mbt_adapter_" + item.export_name)
  }
  for cls in self.classes {
    result.push("napi_mbt_class_dispose_\{cls.id}")
  }
  result
}

///|
fn class_declarations(classes : Array[ParsedClass]) -> String {
  let out = StringBuilder()
  for cls in classes {
    out.write_string(
      "export class \{cls.name} {\n  private readonly $napiType: never;\n" +
      export_documentation(cls.construct, indent="  ") +
      "  constructor(\{typescript_parameters(cls.construct.parameters)});\n  /** Release this instance. Repeated calls are safe. */\n  dispose(): void;\n",
    )
    for entry in cls.members {
      let item = entry.function
      out.write_string(export_documentation(item, indent="  "))
      match item.binding {
        GetterBinding(_) =>
          out.write_string(
            "  get \{entry.name}(): \{item.return_type.typescript()};\n",
          )
        SetterBinding(_) =>
          out.write_string(
            "  set \{entry.name}(value: \{item.parameters[1].value_type.typescript(input=true)});\n",
          )
        StaticBinding(_) =>
          out.write_string(
            "  static \{entry.name}(\{typescript_parameters(item.parameters, is_async=item.is_async)}): \{typescript_result(item)};\n",
          )
        _ =>
          out.write_string(
            "  \{entry.name}(\{typescript_parameters(item.parameters[1:].to_owned(), is_async=item.is_async)}): \{typescript_result(item)};\n",
          )
      }
    }
    out.write_string("}\n\n")
  }
  out.to_string()
}
