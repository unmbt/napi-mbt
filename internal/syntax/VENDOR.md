# Pinned parser sources

- Tree-sitter v0.26.8, commit cd5b087cd9f45ca6d93ab1954f6b7c8534f324d2: https://github.com/tree-sitter/tree-sitter
- MoonBit grammar 190881df47760f1dfa500b9a1d9e331072456f01 (ABI 15): https://github.com/unmbt/tree-sitter-moonbit
- Node-API resources in ../assets/data/resources.json: node-api-headers 1.9.0, https://github.com/nodejs/node-api-headers

License texts accompany the vendored sources and embedded headers. C wrapper
translation units compile the checked-in sources; no grammar generator, npm,
network download, or WASM runtime is involved in normal builds.
