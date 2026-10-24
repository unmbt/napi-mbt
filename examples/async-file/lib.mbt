///|
#export_name("readFile")
pub async fn read(path : String, data : Bytes) -> Bytes {
  @fs.write_file(path, data)
  @fs.read_file(path).binary()
}

///|
#export_name("suspend")
pub async fn suspend(delay : Int32) -> String {
  @async.sleep(delay)
  "pending"
}

///|
/// Wait for a JavaScript Promise before consuming its typed result.
#export_name("twice")
pub async fn twice(value : NapiJsPromise[Int32]) -> Int32 {
  value.wait() * 2
}
