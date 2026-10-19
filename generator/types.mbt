///|
pub(all) enum ValueType {
  IntType
  Int64Type
  UInt64Type
  DoubleType
  BoolType
  StringType
  BytesType
  BufferViewType
  UnitType
  OptionType(ValueType)
  ArrayType(ValueType)
  NamedType(String)
}

///|
pub fn ValueType::runtime_name(self : ValueType) -> String {
  match self {
    IntType => "Int"
    Int64Type => "Int64"
    UInt64Type => "UInt64"
    DoubleType => "Double"
    BoolType => "Bool"
    StringType => "String"
    BytesType => "Bytes"
    BufferViewType => "NapiBufferView"
    UnitType => "Unit"
    OptionType(inner) => "Option[" + inner.runtime_name() + "]"
    ArrayType(inner) => "Array[" + inner.runtime_name() + "]"
    NamedType(name) => name
  }
}

///|
fn ValueType::moonbit(self : ValueType) -> String {
  match self {
    IntType => "Int32"
    OptionType(inner) => "Option[" + inner.moonbit() + "]"
    ArrayType(inner) => "Array[" + inner.moonbit() + "]"
    _ => self.runtime_name()
  }
}

///|
fn ValueType::typescript(self : ValueType, input~ : Bool = false) -> String {
  match self {
    IntType | DoubleType => "number"
    Int64Type | UInt64Type => "bigint"
    BoolType => "boolean"
    StringType => "string"
    BytesType | BufferViewType => "Buffer"
    UnitType => "void"
    OptionType(inner) =>
      "(" +
      inner.typescript(input~) +
      " | null" +
      (if input { " | undefined" } else { "" }) +
      ")"
    ArrayType(inner) => "Array<" + inner.typescript(input~) + ">"
    NamedType(name) => name + (if input { "$Input" } else { "" })
  }
}

///|
fn parse_value_type(
  text : String,
  location : String,
  parameter : Bool,
) -> ValueType raise {
  let text = text.replace_all(old=" ", new="")
  if text.has_suffix("?") {
    let inner = parse_value_type(
      text[:text.length() - 1].to_owned(),
      location,
      true,
    )
    if inner is BufferViewType {
      fail("\{location}: borrowed BufferView cannot be nested")
    }
    return OptionType(inner)
  }
  for prefix in ["Option[", "Array["] {
    if text.has_prefix(prefix) && text.has_suffix("]") {
      let inner = parse_value_type(
        text[prefix.length():text.length() - 1].to_owned(),
        location,
        true,
      )
      if inner is BufferViewType {
        fail("\{location}: borrowed BufferView cannot be nested")
      }
      return if prefix == "Option[" {
        OptionType(inner)
      } else {
        ArrayType(inner)
      }
    }
  }
  match text {
    "Int" | "Int32" => IntType
    "Int64" => Int64Type
    "UInt64" => UInt64Type
    "Double" => DoubleType
    "Bool" => BoolType
    "String" => StringType
    "Bytes" => BytesType
    "Unit" if !parameter => UnitType
    "NapiBufferView" if parameter => BufferViewType
    _ if valid_identifier(text) && text != "Unit" && text != "NapiBufferView" =>
      NamedType(text)
    _ => fail("\{location}: unsupported or unresolved exported type \{text}")
  }
}

///|
pub(all) struct Variant {
  name : String
  parameters : Array[Parameter]
}

///|
pub(all) enum TypeShape {
  StructShape(Array[Parameter])
  EnumShape(Array[Variant])
}

///|
pub(all) struct TypeDefinition {
  name : String
  shape : TypeShape
  filename : String
  line : Int32
}
