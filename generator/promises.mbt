///|
fn promise_direction_valid(
  value : ValueType,
  types : Array[TypeDefinition],
  read : Bool,
  seen : Array[String],
) -> Bool {
  match value {
    JsPromiseType(inner) =>
      read && promise_direction_valid(inner, types, true, seen)
    OptionType(t)
    | ArrayType(t)
    | MapType(t)
    | SetType(t)
    | IteratorType(t)
    | AsyncIteratorType(t) => promise_direction_valid(t, types, read, seen)
    TupleType(items) =>
      items.all(t => promise_direction_valid(t, types, read, seen))
    CallbackType(params, ret, _) =>
      params.all(t => promise_direction_valid(t, types, !read, seen)) &&
      promise_direction_valid(ret, types, read, seen)
    NamedType(name) if !seen.contains(name) => {
      let path = seen.copy()
      path.push(name)
      types
      .iter()
      .filter(t => t.name == name)
      .all(t => {
        let fields = match t.shape {
          StructShape(fields) => fields
          EnumShape(variants) => variants.map(v => v.parameters).flatten()
        }
        fields.all(p => promise_direction_valid(p.value_type, types, read, path))
      })
    }
    _ => true
  }
}
