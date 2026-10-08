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
