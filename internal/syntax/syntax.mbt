///|
type Tree

///|
pub struct Node {
  tree : Tree
  raw : Bytes
  source : Bytes
}

///|
#borrow(source)
extern "c" fn parse_raw(source : Bytes) -> Tree = "napi_mbt_parse"

///|
#borrow(tree)
extern "c" fn parse_ok(tree : Tree) -> Bool = "napi_mbt_parse_ok"

///|
#borrow(tree)
extern "c" fn root_raw(tree : Tree) -> Bytes = "napi_mbt_root"

///|
#borrow(tree, raw)
extern "c" fn child_raw(tree : Tree, raw : Bytes, i : Int) -> Bytes = "napi_mbt_child"

///|
#borrow(tree, raw)
extern "c" fn token_child_raw(tree : Tree, raw : Bytes, i : Int) -> Bytes = "napi_mbt_token_child"

///|
#borrow(tree, raw)
extern "c" fn node_info(tree : Tree, raw : Bytes, what : Int) -> Int = "napi_mbt_node_info"

///|
#borrow(tree, raw)
extern "c" fn node_kind(tree : Tree, raw : Bytes) -> Bytes = "napi_mbt_node_kind"

///|
pub fn parse(source : String) -> Node raise {
  let source = @utf8.encode(source)
  let tree = parse_raw(source)
  if !parse_ok(tree) {
    fail("Unable to initialize the bundled MoonBit parser")
  }
  { tree, raw: root_raw(tree), source, }
}

///|
pub fn Node::children(self : Node) -> Array[Node] {
  Array::makei(node_info(self.tree, self.raw, 0), i => {
    tree: self.tree,
    raw: child_raw(self.tree, self.raw, i),
    source: self.source,
  })
}

///|
pub fn Node::kind(self : Node) -> String {
  @utf8.decode_lossy(node_kind(self.tree, self.raw))
}

///|
pub fn Node::text(self : Node) -> String {
  let start = node_info(self.tree, self.raw, 1)
  let end = node_info(self.tree, self.raw, 2)
  @utf8.decode_lossy(self.source[start:end])
}

///|
pub fn Node::line(self : Node) -> Int {
  node_info(self.tree, self.raw, 3)
}

///|
pub fn Node::has_error(self : Node) -> Bool {
  node_info(self.tree, self.raw, 4) != 0
}

///|
pub fn Node::is_error(self : Node) -> Bool {
  node_info(self.tree, self.raw, 5) != 0
}

///|
/// Syntax tokens without comments; keep string literals intact.
pub fn Node::tokens(self : Node) -> Array[String] {
  let kind = self.kind()
  if kind.contains("comment") {
    return []
  }
  let count = node_info(self.tree, self.raw, 6)
  if count == 0 || kind.contains("string") {
    return [self.text()]
  }
  let result = []
  for i in 0..<count {
    let child = {
      tree: self.tree,
      raw: token_child_raw(self.tree, self.raw, i),
      source: self.source,
    }
    result.append(child.tokens())
  }
  result
}
