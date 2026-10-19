///|
async fn copy_build_workspace(
  source : String,
  destination : String,
  ancestors : Array[String],
) -> Unit {
  let canonical = @fs.realpath(source)
  if ancestors.contains(canonical) {
    fail("Cyclic directory link in build inputs: \{source}")
  }
  let parents = ancestors.copy()
  parents.push(canonical)
  mkdirp(destination)
  for name in @fs.readdir(source, sort=true) {
    if [
        ".git", ".codegraph", ".napi-mbt", ".moonagent", "_build", "target", "node_modules",
        "artifacts", "dist", "npm",
      ].contains(name) {
      continue
    }
    let src = source + "/" + name
    let dst = destination + "/" + name
    if @fs.kind(src) == Directory {
      copy_build_workspace(src, dst, parents)
    } else {
      write_file(dst, @fs.read_file(src))
      if !windows() && @fs.can_execute(src) {
        @fs.chmod(dst, 0o755)
      }
    }
  }
}
