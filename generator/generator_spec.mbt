///|
/// The SDD contract for the source scanner and artifact emitter.
pub(all) struct ExportSpec {
  source_name : String
  export_name : String
  parameters : Array[String]
  return_type : String
}

///|
pub(all) struct GeneratorConfig {
  napi_version : Int
  builder : String
  generator : String
}

///|
#declaration_only
pub fn scan_source(source : String) -> Array[ExportSpec] {
  ...
}

///|
#declaration_only
pub fn render_moonbit_adapters(exports : Array[ExportSpec]) -> String {
  ...
}

///|
#declaration_only
pub fn render_c_glue(exports : Array[ExportSpec], napi_version : Int) -> String {
  ...
}
