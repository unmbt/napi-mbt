///|
fn config_schema() -> Json raise {
  let features = [
    "promise", "threadsafe_function", "bigint", "buffer", "class", "callback", "async",
    "native_tasks",
  ]
  let conditions : Array[Json] = features.map(name => {
    let level = feature_version(name)
    (
      {
        "if": {
          "required": ["features"],
          "properties": { "features": { "contains": { "const": name } } },
        },
        "then": if level > 4 {
          (
            {
              "required": ["napiVersion"],
              "properties": { "napiVersion": { "minimum": level } },
            } : Json)
        } else {
          ({ "properties": { "napiVersion": { "minimum": level } } } : Json)
        },
      } : Json)
  })
  conditions.push({
    "if": {
      "required": ["workerTasks"],
      "properties": { "workerTasks": { "minItems": 1 } },
    },
    "then": {
      "required": ["napiVersion"],
      "properties": { "napiVersion": { "minimum": 8 } },
    },
  })
  conditions.push({
    "if": {
      "required": ["nativeTasks"],
      "properties": { "nativeTasks": { "minProperties": 1 } },
    },
    "then": {
      "required": ["napiVersion"],
      "properties": { "napiVersion": { "minimum": 8 } },
    },
  })
  conditions.push({
    "if": {
      "required": ["classes"],
      "properties": { "classes": { "minItems": 1 } },
    },
    "then": { "properties": { "napiVersion": { "minimum": 3 } } },
  })
  {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "napi-mbt configuration",
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "$schema": { "type": "string" },
      "napiVersion": {
        "type": "integer",
        "minimum": 1,
        "maximum": 10,
        "default": 4,
      },
      "builder": {
        "enum": ["auto", "cmake", "gcc", "clang", "msvc"],
        "default": "auto",
      },
      "targets": {
        "type": "array",
        "uniqueItems": true,
        "items": { "enum": supported_targets },
      },
      "features": {
        "type": "array",
        "uniqueItems": true,
        "items": { "enum": features },
      },
      "cjs": { "type": "boolean", "default": true },
      "esm": { "type": "boolean", "default": true },
      "classes": class_configuration_schema(),
      "workerTasks": {
        "type": "array",
        "uniqueItems": true,
        "items": { "type": "string" },
      },
      "workerPool": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "size": {
            "type": "integer",
            "minimum": 1,
            "maximum": 64,
            "default": 2,
          },
          "maxQueue": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100000,
            "default": 64,
          },
          "idleTimeoutMs": {
            "type": "integer",
            "minimum": 1,
            "maximum": 2147483647,
            "default": 30000,
          },
        },
      },
      "nativeTasks": {
        "type": "object",
        "propertyNames": { "pattern": "^[A-Za-z_][A-Za-z0-9_]*$" },
        "additionalProperties": {
          "type": "string",
          "pattern": "^[A-Za-z_][A-Za-z0-9_]*$",
        },
      },
    },
    "not": {
      "required": ["cjs", "esm"],
      "properties": { "cjs": { "const": false }, "esm": { "const": false } },
    },
    "allOf": conditions,
  }
}
