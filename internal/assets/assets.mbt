///|
pub fn files() -> Map[String, String] raise {
  guard @json.parse(bundled) is Object(items) else {
    fail("Invalid bundled resources")
  }
  let result = Map([])
  for name, value in items {
    guard value is String(text) else { fail("Invalid bundled resource") }
    result[name] = text
  }
  result
}
