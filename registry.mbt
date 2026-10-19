///|
let global_registry : Map[Int32, String] = Map([])

///|
let next_id : Ref[Int32] = Ref(1)

///|
pub fn registry_retain(obj : String) -> Int32 {
  let id = next_id.val
  next_id.val += 1
  global_registry[id] = obj
  id
}

///|
pub fn registry_release(id : Int32) -> Unit {
  global_registry.remove(id)
}

///|
pub fn registry_get(id : Int32) -> String? {
  global_registry.get(id)
}

///|
pub fn moonbit_release_handle(id : Int32) -> Unit {
  registry_release(id)
}
