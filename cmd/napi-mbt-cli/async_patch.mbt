///|
fn adapter_checksum(text : String) -> String {
  let mut digest = 14695981039346656037UL
  for byte in @utf8.encode(text) {
    digest = (digest ^ byte.to_uint64()) * 1099511628211UL
  }
  digest.to_string(radix=16)
}

///|
/// Only call on a copied build workspace. Validate all upstream files before
/// applying any replacements; never patch the user's dependency cache.
async fn patch_async_dependency(workspace : String) -> Unit {
  let assets = @assets.files()
  let root = workspace + "/.mooncakes/moonbitlang/async"
  if !@fs.exists(root + "/moon.mod") {
    fail(
      "Async exports require moonbitlang/async@0.22.4; run moon add moonbitlang/async@0.22.4 first",
    )
  }
  let manifest = @fs.read_file(root + "/moon.mod").text()
  let tokens = package_tokens(manifest)
  let mut version : String? = None
  for i, token in tokens {
    if token.value == "version" &&
      tokens.get(i + 1).map(t => t.value) == Some("=") {
      version = tokens.get(i + 2).map(t => t.value)
      break
    }
  }
  if version != Some("0.22.4") {
    fail(
      "Async adapter requires exactly moonbitlang/async 0.22.4; found " +
      version.unwrap_or("no version"),
    )
  }
  guard assets.get("async/manifest.json") is Some(metadata) &&
    @json.parse(metadata) is { "files": Array(files), .. } else {
    fail("Missing embedded async adapter manifest")
  }
  let outputs : Array[(String, String)] = []
  for entry in files {
    guard entry
      is { "path": String(path), "before": before, "after": String(after), .. } else {
      fail("Invalid async adapter entry")
    }
    if path.contains("..") || !path.has_prefix("src/") {
      fail("Invalid async adapter path")
    }
    let target = root + "/" + path
    match before {
      String(checksum) => {
        let source = @fs.read_file(target)
          .text()
          .replace_all(old="\r\n", new="\n")
        if adapter_checksum(source) != checksum {
          fail("Async 0.22.4 source checksum mismatch: \{path}")
        }
      }
      Null =>
        if @fs.exists(target) {
          fail("Async adapter file already exists: \{path}")
        }
      _ => fail("Invalid async adapter checksum")
    }
    guard assets.get("async/files/" + path) is Some(patched) &&
      adapter_checksum(patched) == after else {
      fail("Corrupt embedded async adapter: \{path}")
    }
    outputs.push((target, patched))
  }
  mkdirp(root + "/src/napi_host")
  for (path, text) in outputs {
    write_file(path, text)
  }
  let event_package = root + "/src/internal/event_loop/moon.pkg"
  write_file(
    event_package,
    append_package_import(
      @fs.read_file(event_package).text(),
      "moonbitlang/async/io",
      "io",
    ),
  )
  for name in ["napi_async.h", "napi_async.mbt", "LIBUV-LICENSE"] {
    write_file(workspace + "/" + name, assets["async/" + name])
  }
  let pkg = @fs.read_file(workspace + "/moon.pkg").text()
  if pkg.contains("@napi_mbt_async") {
    fail("Package alias @napi_mbt_async is reserved for the async adapter")
  }
  write_file(
    workspace + "/moon.pkg",
    append_package_import(pkg, "moonbitlang/async/napi_host", "napi_mbt_async"),
  )
  write_file(
    workspace + "/stub.c",
    @fs.read_file(workspace + "/stub.c").text() +
    "\n#include \"napi_async.h\"\n",
  )
}

///|
fn append_package_import(
  source : String,
  path : String,
  package_alias : String,
) -> String raise {
  let tokens = package_tokens(source)
  for i, token in tokens {
    if token.value == "import" &&
      tokens.get(i + 1).map(t => t.value) == Some("{") {
      let end = package_close(tokens, i + 1)
      if tokens.get(end + 1).map(t => t.value) == Some("for") {
        continue
      }
      if tokens[i + 1:end].any(t => t.quoted && t.value == path) {
        fail(
          "Async adapter import conflicts with an existing import of \{path}",
        )
      }
      let insert = tokens[i + 1].end
      return source[:insert].to_owned() +
        "\n  " +
        Json(path).stringify() +
        " @" +
        package_alias +
        "," +
        source[insert:].to_owned()
    }
  }
  "import { " + Json(path).stringify() + " @" + package_alias + " }\n" + source
}
