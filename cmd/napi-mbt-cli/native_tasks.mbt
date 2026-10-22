///|
fn native_task_configurations(value : Json?) -> Array[(String, String)] raise {
  let fields = match value {
    None => Map([])
    Some(value) => object(value)
  }
  let names = fields.keys().to_array()
  names.sort_by(lexical_compare)
  names.map(name => {
    guard fields[name] is String(symbol) else {
      fail("nativeTasks values must be C ABI symbol names")
    }
    for value in [name, symbol] {
      if value.is_empty() ||
        value.has_prefix("napi_mbt_") ||
        value.has_prefix("__") ||
        !value
        .iter()
        .all(c => {
          (c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '_'
        }) ||
        (value[0] >= '0' && value[0] <= '9') {
        fail("Invalid or reserved native task name/symbol: " + value)
      }
    }
    (name, symbol)
  })
}

///|
fn native_task_source(tasks : Array[(String, String)]) -> String {
  tasks
  .map(task => {
    "///|\n#export_name(\"" +
    task.0 +
    "\")\npub async fn napi_mbt_task_export_" +
    task.0 +
    "(input : Bytes) -> Bytes { napi_native_task(\"" +
    task.0 +
    "\", input) }\n"
  })
  .join("\n")
}

///|
fn native_task_glue(tasks : Array[(String, String)]) -> String {
  if tasks.is_empty() {
    return ""
  }
  "\n#include \"napi_native_task_runtime.h\"\n" +
  tasks
  .map(task => "extern void " + task.1 + "(napi_mbt_task_context *);")
  .join("\n") +
  "\nstatic napi_mbt_task_function napi_mbt_task_lookup(const char *name) {\n" +
  tasks
  .map(task => {
    "  if (strcmp(name, \"" + task.0 + "\") == 0) return " + task.1 + ";"
  })
  .join("\n") +
  "\n  return NULL;\n}\n"
}

///|
async fn prepare_native_tasks(workspace : String) -> Unit {
  let path = workspace + "/moon.pkg"
  let source = read_text(path)
  let imports = package_tokens(source)
  // Reuse an existing import alias, otherwise add an internal one.
  let mut package_alias = "napi_mbt_tasks"
  let mut found = false
  for i, token in imports {
    if token.value == "import" &&
      imports.get(i + 1).map(t => t.value) == Some("{") {
      let end = package_close(imports, i + 1)
      if imports.get(end + 1).map(t => t.value) == Some("for") {
        continue
      }
      for j in (i + 2)..<end {
        if imports[j].quoted && imports[j].value == "moonbitlang/async" {
          found = true
          package_alias = if imports.get(j + 1).map(t => t.value) == Some("@") {
            imports[j + 2].value
          } else {
            "async"
          }
          break
        }
      }
      if found {
        break
      }
    }
  }
  if !found {
    write_text_file(
      path,
      append_package_import(source, "moonbitlang/async", package_alias),
    )
  }
  write_text_file(
    workspace + "/napi_native_tasks.mbt",
    @assets.files()["async/native_tasks.mbt"].replace_all(
      old="@napi_mbt_tasks",
      new="@" + package_alias,
    ),
  )
}
