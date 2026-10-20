///|
let saved : Ref[((Int) -> Int raise)?] = Ref(None)
///|
#export_name("save")
pub fn save(callback : (Int) -> Int raise) -> Unit { saved.val = Some(callback) }
///|
#export_name("invoke")
pub fn invoke(value : Int) -> Int raise { saved.val.unwrap()(value) }
///|
#export_name("clear")
pub fn clear() -> Unit { saved.val = None }
///|
#export_name("make_adder")
pub fn make_adder(delta : Int) -> ((Int) -> Int) { value => value + delta }
