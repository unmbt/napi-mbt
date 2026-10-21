///|
#export_name("readFile")
pub async fn read(path : String, data : Bytes) -> Bytes {
  @fs.write_file(path, data)
  @fs.read_file(path).binary()
}

///|
#export_name("suspend")
pub async fn suspend(delay : Int) -> String { @async.sleep(delay); "pending" }
