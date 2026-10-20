///|
#export_name("range")
pub fn range(count : Int) -> NapiAsyncIterator[Int] raise {
  let index = Ref(0)
  NapiAsyncIterator::new(() => {
    if index.val >= count { return None }
    @async.sleep(1)
    let value = index.val
    index.val += 1
    Some(value)
  }, () => ())
}

///|
#export_name("sum")
pub async fn sum(values : NapiAsyncIterator[Int]) -> Int {
  defer values.close()
  let mut result = 0
  while values.next() is Some(value) { result += value }
  result
}
