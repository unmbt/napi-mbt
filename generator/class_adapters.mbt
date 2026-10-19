///|
fn class_bindings(
  classes : Array[ParsedClass],
  readers : Array[ValueType],
  writers : Array[ValueType],
) -> String {
  let out = StringBuilder()
  for cls in classes {
    if readers.any(t => t is ClassType(_, _, id) && id == cls.id) {
      out.write_string(
        "\n///|\nextern \"c\" fn napi_mbt_class_payload_\{cls.id}(handle : UnmanagedBuffer) -> \{cls.type_name} = \"napi_mbt_class_payload\"\n",
      )
    }
    if writers.any(t => t is ClassType(_, _, id) && id == cls.id) {
      out.write_string(
        "\n///|\n#borrow(value, result)\nextern \"c\" fn napi_mbt_class_create_\{cls.id}(env : NapiEnv, value : \{cls.type_name}, type_id : Int32, result : Ref[NapiValue]) -> Int32 = \"napi_mbt_class_create\"\n",
      )
    }
    out.write_string(
      "\n///|\n#borrow(value)\nextern \"c\" fn napi_mbt_class_wrap_\{cls.id}(env : NapiEnv, receiver : NapiValue, value : \{cls.type_name}, type_id : Int32) -> Int32 = \"napi_mbt_class_wrap\"\n",
    )
    out.write_string(
      "\n///|\n#export_name(\"napi_mbt_class_dispose_\{cls.id}\")\npub fn napi_mbt_class_dispose_\{cls.id}(env : NapiEnv, receiver : NapiValue) -> NapiValue {\n  try {\n    napi_class_dispose(env, receiver, \{cls.id})\n    set_Unit(env, ())\n  } catch { error => { throw_napi_error(env, error); moonbit_dummy_napi_value() } }\n}\n",
    )
  }
  out.to_string()
}
