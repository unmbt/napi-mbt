///|
test "syntax nodes keep their tree and UTF8 source alive" {
  let node = @syntax.parse("let greeting = \"你好🌙\"\n").children()[0]
  assert_true(node.text().contains("你好🌙"))
  for _ in 0..<100 {
    ignore(@syntax.parse("pub fn f() -> Int { 1 }").children())
  }
  assert_true(node.text().contains("你好🌙"))
  assert_eq(node.line(), 1)
}

///|
test "parser handles modern labeled optional async raise and doc directives" {
  let source =
    #|/// @napi class("Box")
    #|pub(all) struct Box { value : Int }
    #|/// @napi method
    #|pub async fn f(x~ : Int, y? : Int = 1) -> Int raise { x + y }
    #|
  let root = @syntax.parse(source)
  assert_true(!root.has_error())
  let children = root.children()
  assert_true(children.any(n => n.kind() == "struct_definition"))
  assert_true(children.any(n => n.kind() == "function_definition"))
  let struct_node = children.filter(n => n.kind() == "struct_definition")[0]
  assert_eq(struct_node.documentation(), ["@napi class(\"Box\")"])
}
