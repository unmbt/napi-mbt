///|
pub struct Counter { mut value : Int }
///|
fn Counter::new(value : Int) -> Counter { { value } }
///|
fn Counter::increment(self : Counter, delta : Int) -> Int { self.value += delta; self.value }
///|
fn Counter::value(self : Counter) -> Int { self.value }
///|
fn Counter::set_value(self : Counter, value : Int) -> Unit { self.value = value }
///|
#export_name("counter")
pub fn counter(value : Int) -> Counter { Counter::new(value) }
