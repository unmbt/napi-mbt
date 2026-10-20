///|
#export_name("read")
pub async fn read(path : String, delay : Int) -> Bytes { @async.sleep(delay); @fs.read_file(path).binary() }
