///|
let ignored_build_directories : Array[String] = [
  ".git", ".github", ".githooks", ".codegraph", ".napi-mbt", ".moonagent", ".vscode",
  ".idea", "_build", "target", "node_modules", "artifacts", "dist", "npm", "licenses",
  "docs", "napi-rs", "packages",
]

///|
async fn copy_build_workspace(
  source : String,
  destination : String,
  ancestors : Array[String],
  excluded~ : Array[String] = [],
) -> Unit {
  let canonical = @fs.realpath(source)
  if excluded.contains(canonical) {
    return
  }
  if ancestors.contains(canonical) {
    fail("Cyclic directory link in build inputs: \{source}")
  }
  let parents = ancestors.copy()
  parents.push(canonical)
  mkdirp(destination)
  for name in @fs.readdir(source, sort=true) {
    if ignored_build_directories.contains(name) {
      continue
    }
    let src = source + "/" + name
    let dst = destination + "/" + name
    if @fs.kind(src) == Directory {
      copy_build_workspace(src, dst, parents, excluded~)
    } else {
      write_file(dst, @fs.read_file(src))
      if !windows() && @fs.can_execute(src) {
        @fs.chmod(dst, 0o755)
      }
    }
  }
}
