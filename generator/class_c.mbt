///|
fn class_callbacks(classes : Array[ParsedClass]) -> String {
  let out = StringBuilder()
  if !classes.is_empty() {
    out.write_string(
      "\nextern int napi_mbt_save_constructor(napi_env, napi_value, int);\nextern int napi_mbt_construct_pending(napi_env, napi_value, int, bool *);\n",
    )
  }
  for cls in classes {
    let functions = [cls.construct]
    for entry in cls.members {
      functions.push(entry.function)
    }
    for item in functions {
      let construct = item.binding is ConstructorBinding(_)
      let instance = item.binding
        is (MethodBinding(_) | GetterBinding(_) | SetterBinding(_))
      let parameters = item.parameters[if instance { 1 } else { 0 }:]
      let n = parameters.length() + (if item.is_async { 1 } else { 0 })
      let mut required = 0
      for i, p in parameters {
        if !(p.value_type is OptionType(_)) {
          required = i + 1
        }
      }
      if item.is_async {
        required = 0
      }
      out.write_string(
        "extern napi_value napi_mbt_adapter_\{item.export_name}(napi_env",
      )
      if construct {
        out.write_string(", napi_value")
      }
      for _ in item.parameters {
        out.write_string(", napi_value")
      }
      if item.is_async {
        out.write_string(", napi_value")
      }
      out.write_string(");\n")
      out.write_string(
        (
          $|static napi_value napi_mbt_callback_\{item.export_name}(napi_env env, napi_callback_info info) {
          $|  size_t argc = \{n};
          $|  napi_value argv[\{if n == 0 { 1 } else { n }}], receiver;
          $|  napi_status status = napi_get_cb_info(env, info, &argc, argv, &receiver, NULL);
          $|  if (status != napi_ok) return napi_mbt_error(env, status, 0, "ERR_NAPI_CALLBACK", "Reading class arguments");
          $|  void *previous;
          $|  int entered = napi_mbt_enter(env, &previous);
          $|  if (entered != napi_ok) return napi_mbt_error(env, entered, 0, "ERR_NAPI_ENVIRONMENT", "Entering class environment");
          $|  napi_value result = NULL;
          $|
        ),
      )
      if construct {
        out.write_string(
          (
            $|  napi_value target;
            $|  status = napi_get_new_target(env, info, &target);
            $|  if (status != napi_ok || target == NULL) {
            $|    result = napi_mbt_error(env, status == napi_ok ? napi_invalid_arg : status, 1, "ERR_NAPI_CONSTRUCTOR", "Class constructor requires new");
            $|    goto leave;
            $|  }
            $|  bool handled = false;
            $|  int pending = napi_mbt_construct_pending(env, receiver, \{cls.id}, &handled);
            $|  if (pending != napi_ok) { result = napi_mbt_error(env, pending, 0, "ERR_NAPI_CONSTRUCTOR", "Wrapping factory result"); goto leave; }
            $|  if (handled) { result = receiver; goto leave; }
            $|
          ),
        )
      }
      out.write_string(
        (
          $|  if (argc < \{required}) { result = napi_mbt_error(env, napi_invalid_arg, 1, "ERR_NAPI_ARGUMENTS", "Missing argument"); goto leave; }
          $|  for (size_t i = argc; i < \{n}; ++i) {
          $|    status = napi_get_undefined(env, &argv[i]);
          $|    if (status != napi_ok) { result = napi_mbt_error(env, status, 0, "ERR_NAPI_CALLBACK", "Filling class arguments"); goto leave; }
          $|  }
          $|
        ),
      )
      out.write_string("  result = napi_mbt_adapter_\{item.export_name}(env")
      if construct || instance {
        out.write_string(", receiver")
      }
      for i in 0..<n {
        out.write_string(", argv[\{i}]")
      }
      out.write_string(
        ");\nleave:\n  napi_mbt_leave(previous);\n  return result;\n}\n",
      )
    }
    out.write_string(
      (
        $|extern napi_value napi_mbt_class_dispose_\{cls.id}(napi_env, napi_value);
        $|static napi_value napi_mbt_dispose_callback_\{cls.id}(napi_env env, napi_callback_info info) {
        $|  napi_value receiver;
        $|  napi_status status = napi_get_cb_info(env, info, NULL, NULL, &receiver, NULL);
        $|  if (status != napi_ok) return napi_mbt_error(env, status, 0, "ERR_NAPI_CALLBACK", "Reading dispose receiver");
        $|  void *previous;
        $|  int entered = napi_mbt_enter(env, &previous);
        $|  if (entered != napi_ok) return napi_mbt_error(env, entered, 0, "ERR_NAPI_ENVIRONMENT", "Disposing class instance");
        $|  napi_value result = napi_mbt_class_dispose_\{cls.id}(env, receiver);
        $|  napi_mbt_leave(previous);
        $|  return result;
        $|}
        $|
      ),
    )
  }
  out.to_string()
}

///|
fn class_registration(classes : Array[ParsedClass]) -> String {
  let out = StringBuilder()
  for cls in classes {
    let indexes : Map[String, Int32] = Map([])
    for entry in cls.members {
      let key = (if entry.function.binding is StaticBinding(_) {
          "static:"
        } else {
          "instance:"
        }) +
        entry.name
      if !indexes.contains(key) {
        indexes[key] = indexes.length()
      }
    }
    let dispose = indexes.length()
    out.write_string(
      "  napi_property_descriptor class_\{cls.id}_properties[\{dispose + 1}] = {0};\n",
    )
    for entry in cls.members {
      let key = (if entry.function.binding is StaticBinding(_) {
          "static:"
        } else {
          "instance:"
        }) +
        entry.name
      let p = "class_\{cls.id}_properties[\{indexes[key]}]"
      let (field, attributes) = match entry.function.binding {
        GetterBinding(_) => ("getter", "napi_configurable")
        SetterBinding(_) => ("setter", "napi_configurable")
        StaticBinding(_) =>
          ("method", "napi_writable | napi_configurable | napi_static")
        _ => ("method", "napi_writable | napi_configurable")
      }
      out.write_string(
        "  \{p}.utf8name = " +
        Json(entry.name).stringify() +
        ";\n  \{p}.\{field} = napi_mbt_callback_\{entry.function.export_name};\n  \{p}.attributes = (napi_property_attributes)(\{attributes});\n",
      )
    }
    out.write_string(
      (
        $|  class_\{cls.id}_properties[\{dispose}].utf8name = "dispose";
        $|  class_\{cls.id}_properties[\{dispose}].method = napi_mbt_dispose_callback_\{cls.id};
        $|  class_\{cls.id}_properties[\{dispose}].attributes = (napi_property_attributes)(napi_writable | napi_configurable);
        $|  napi_value class_\{cls.id};
        $|  int class_\{cls.id}_status = napi_define_class(env, \{Json(cls.name).stringify()}, NAPI_AUTO_LENGTH, napi_mbt_callback_\{cls.construct.export_name}, NULL, 0, NULL, &class_\{cls.id});
        $|  if (class_\{cls.id}_status != napi_ok) return napi_mbt_registration_error(env, class_\{cls.id}_status, previous, "Defining class");
        $|  napi_value prototype_\{cls.id};
        $|  class_\{cls.id}_status = napi_get_named_property(env, class_\{cls.id}, "prototype", &prototype_\{cls.id});
        $|  if (class_\{cls.id}_status != napi_ok) return napi_mbt_registration_error(env, class_\{cls.id}_status, previous, "Reading class prototype");
        $|  for (size_t i = 0; i < \{dispose + 1}; ++i) {
        $|    napi_property_descriptor *property = &class_\{cls.id}_properties[i];
        $|    napi_value target = (property->attributes & napi_static) ? class_\{cls.id} : prototype_\{cls.id};
        $|    property->attributes = (napi_property_attributes)(property->attributes & ~napi_static);
        $|    class_\{cls.id}_status = napi_define_properties(env, target, 1, property);
        $|    if (class_\{cls.id}_status != napi_ok) return napi_mbt_registration_error(env, class_\{cls.id}_status, previous, "Defining class member");
        $|  }
        $|  class_\{cls.id}_status = napi_mbt_save_constructor(env, class_\{cls.id}, \{cls.id});
        $|  if (class_\{cls.id}_status != napi_ok) return napi_mbt_registration_error(env, class_\{cls.id}_status, previous, "Retaining class constructor");
        $|  class_\{cls.id}_status = moonbit_napi_field_set(env, exports, \{Json(cls.name).stringify()}, class_\{cls.id});
        $|  if (class_\{cls.id}_status != napi_ok) return napi_mbt_registration_error(env, class_\{cls.id}_status, previous, "Exporting class");
        $|
      ),
    )
  }
  out.to_string()
}
