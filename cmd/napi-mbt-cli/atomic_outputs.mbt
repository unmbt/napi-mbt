///|
async fn install_outputs(
  dir : String,
  outputs : Array[(String, String)],
  check : Bool,
  removals~ : Array[String] = [],
) -> Unit {
  // Validate all destinations before staging, and never touch the filesystem in
  // check mode (including creating the generator's work directory).
  for (name, text) in outputs {
    let path = dir + "/" + name
    let exists = @fs.exists(path)
    if exists && @fs.kind(path, follow_symlink=false) != Regular {
      fail("Generated output must be a regular file: \{path}")
    }
    if check && (!exists || @fs.read_file(path).text() != text) {
      fail("Generated file is not up-to-date: \{name}")
    }
  }
  for name in removals {
    let path = dir + "/" + name
    if @fs.exists(path) {
      if @fs.kind(path, follow_symlink=false) != Regular {
        fail("Generated output must be a regular file: \{path}")
      }
      if check {
        fail("Disabled generated file still exists: \{name}")
      }
    }
  }
  if check {
    return
  }
  let token = @fs.tmpdir(prefix="napi-mbt-generate-")
  defer @fs.rmdir(token)
  let parts = token.replace_all(old="\\", new="/").split("/").to_array()
  let staging = dir + "/.napi-mbt/" + parts[parts.length() - 1].to_owned()
  mkdirp(staging)
  defer @fs.rmdir(staging, recursive=true)
  for i, (_, text) in outputs {
    write_file(staging + "/\{i}.new", text)
  }
  let backups : Array[Int32] = []
  let installed : Array[Int32] = []
  let removed : Array[Int32] = []
  errdefer {
    for i in installed.rev() {
      @fs.remove(dir + "/" + outputs[i].0)
    }
    for i in backups.rev() {
      @fs.rename(staging + "/\{i}.old", dir + "/" + outputs[i].0, replace=true)
    }
    for i in removed.rev() {
      @fs.rename(
        staging + "/\{i}.removed",
        dir + "/" + removals[i],
        replace=true,
      )
    }
  }
  for i, name in removals {
    if @fs.exists(dir + "/" + name) {
      @fs.rename(dir + "/" + name, staging + "/\{i}.removed")
      removed.push(i)
    }
  }
  for i, (name, _) in outputs {
    let destination = dir + "/" + name
    if @fs.exists(destination) {
      @fs.rename(destination, staging + "/\{i}.old")
      backups.push(i)
    }
    @fs.rename(staging + "/\{i}.new", destination)
    installed.push(i)
  }
}
