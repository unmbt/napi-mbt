///|
let global_registry : Map[Int, String] = Map([])

///|
let next_id : Ref[Int] = Ref(1)

///|
pub fn registry_retain(obj : String) -> Int {
  let id = next_id.val
  next_id.val += 1
  global_registry[id] = obj
  id
}

///|
pub fn registry_release(id : Int) -> Unit {
  global_registry.remove(id)
}

///|
pub fn registry_get(id : Int) -> String? {
  global_registry.get(id)
}

///|
pub fn moonbit_release_handle(id : Int) -> Unit {
  registry_release(id)
}
