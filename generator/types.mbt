///|
pub(all) enum ValueType {
  IntType
  DoubleType
  BoolType
  StringType
  BytesType
  BufferViewType
  UnitType
}

///|
pub fn ValueType::runtime_name(self : ValueType) -> String {
  match self {
    IntType => "Int"
    DoubleType => "Double"
    BoolType => "Bool"
    StringType => "String"
    BytesType => "Bytes"
    BufferViewType => "NapiBufferView"
    UnitType => "Unit"
  }
}

///|
fn ValueType::moonbit(self : ValueType) -> String {
  match self {
    IntType => "Int32"
    _ => self.runtime_name()
  }
}

///|
fn ValueType::typescript(self : ValueType) -> String {
  match self {
    IntType | DoubleType => "number"
    BoolType => "boolean"
    StringType => "string"
    BytesType | BufferViewType => "Buffer"
    UnitType => "void"
  }
}

///|
fn parse_value_type(
  text : String,
  location : String,
  parameter : Bool,
) -> ValueType raise {
  match text {
    "Int" | "Int32" => IntType
    "Double" => DoubleType
    "Bool" => BoolType
    "String" => StringType
    "Bytes" => BytesType
    "Unit" if !parameter => UnitType
    "NapiBufferView" if parameter => BufferViewType
    _ => fail("\{location}: unsupported or unresolved exported type \{text}")
  }
}
