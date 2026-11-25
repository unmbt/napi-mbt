///|
fn class_bindings(
  classes : Array[ParsedClass],
  readers : Array[ValueType],
  writers : Array[ValueType],
  rt~ : String = "",
) -> String {
  let out = StringBuilder()
  for cls in classes {
    if readers.any(t => t is ClassType(_, _, id) && id == cls.id) {
      out.write_string(
        "\n///|\nextern \"c\" fn napi_mbt_class_payload_\{cls.id}(handle : \{rt}UnmanagedBuffer) -> \{cls.type_name} = \"napi_mbt_class_payload_\{cls.id}\"\n",
      )
    }
    if writers.any(t => t is ClassType(_, _, id) && id == cls.id) {
      out.write_string(
        "\n///|\n#borrow(value, result)\nextern \"c\" fn napi_mbt_class_create_\{cls.id}(env : \{rt}NapiEnv, value : \{cls.type_name}, type_id : Int32, result : Ref[\{rt}NapiValue]) -> Int32 = \"napi_mbt_class_create_\{cls.id}\"\n",
      )
    }
    out.write_string(
      "\n///|\n#borrow(value)\nextern \"c\" fn napi_mbt_class_wrap_\{cls.id}(env : \{rt}NapiEnv, receiver : \{rt}NapiValue, value : \{cls.type_name}, type_id : Int32) -> Int32 = \"napi_mbt_class_wrap_\{cls.id}\"\n",
    )
    out.write_string(
      "\n///|\n#export_name(\"napi_mbt_class_dispose_\{cls.id}\")\npub fn napi_mbt_class_dispose_\{cls.id}(env : \{rt}NapiEnv, receiver : \{rt}NapiValue) -> \{rt}NapiValue {\n  try {\n    \{rt}napi_class_dispose(env, receiver, \{cls.id})\n    \{rt}set_Unit(env, ())\n  } catch { error => { \{rt}throw_napi_error(env, error); \{rt}moonbit_dummy_napi_value() } }\n}\n",
    )
  }
  out.to_string()
}
