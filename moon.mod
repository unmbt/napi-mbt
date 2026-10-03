// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "unmbt/napi-mbt"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/unmbt/napi-mbt"

license = "MIT"

keywords = [ ]

supported_targets = "native"

description = "Generate and build Node-API bindings for MoonBit."

preferred_target = "native"

import {
  "moonbitlang/async@0.20.2",
}
