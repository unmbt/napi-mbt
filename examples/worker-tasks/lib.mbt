///|
#export_name("fibonacci")
pub fn fibonacci(n : Int) -> UInt64 raise {
  if n < 0 || n > 93 { fail("Expected 0 <= n <= 93") }
  for i = 0, a = 0UL, b = 1UL; i < n; {
    continue i + 1, b, a + b
  } nobreak { a }
}
