///|
/// Implementation of the scanner and deterministic emitters.
fn trim(text : String) -> String {
  String::trim(text).to_owned()
}

///|
fn between(text : String, left : String, right : String) -> String? {
  match text.find(left) {
    Some(start) => {
      let begin = start + left.length()
      match text.find(right) {
        Some(end) if end >= begin =>
          Some(text.unsafe_substring(start=begin, end~))
        _ => None
      }
    }
    None => None
  }
}

///|
fn parse_parameters(signature : String) -> Array[String] {
  let result : Array[String] = Array()
  match between(signature, "(", ")") {
    Some(raw) =>
      String::split(raw, ",").each(fn(part) {
        let value = trim(part.to_owned())
        if !value.is_empty() {
          result.push(value)
        }
      })
    None => ()
  }
  result
}

///|
/// Scans the small, stable subset of MoonBit declarations needed by the
/// generator.
pub fn scan_source(source : String) -> Array[ExportSpec] {
  let result : Array[ExportSpec] = Array()
  let lines = String::split(source, "\n")
    .map(fn(line) { line.to_owned() })
    .to_array()
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if line.contains("#export_name(") {
      let export_name = match between(line, "#export_name(\"", "\")") {
        Some(value) => value
        None => continue
      }
      let mut signature = ""
      let mut source_name = ""
      let mut return_type = "Unit"
      let mut j = i + 1
      while j < lines.length() && j < i + 8 && source_name.is_empty() {
        let candidate = trim(lines[j])
        if candidate.contains("fn ") {
          let mut full_signature = candidate
          let mut k = j + 1
          while !full_signature.contains(")") &&
                k < lines.length() &&
                k < i + 16 {
            full_signature = full_signature + " " + trim(lines[k])
            k = k + 1
          }
          signature = full_signature
          match full_signature.find("fn ") {
            Some(fn_start) => {
              let rest = full_signature.unsafe_substring(
                start=fn_start + 3,
                end=full_signature.length(),
              )
              match rest.find("(") {
                Some(name_end) =>
                  source_name = trim(
                    rest.unsafe_substring(start=0, end=name_end),
                  )
                None => ()
              }
            }
            None => ()
          }
          match full_signature.find("->") {
            Some(arrow) =>
              return_type = trim(
                full_signature.unsafe_substring(
                  start=arrow + 2,
                  end=full_signature.length(),
                ),
              )
            None => ()
          }
        }
        j = j + 1
      }
      if !source_name.is_empty() {
        result.push({
          source_name,
          export_name,
          parameters: parse_parameters(signature),
          return_type,
        })
      }
    }
  }
  result
}

///|
fn moonbit_type(parameter : String) -> String {
  match parameter.find(":") {
    Some(index) =>
      trim(parameter.unsafe_substring(start=index + 1, end=parameter.length()))
    None => parameter
  }
}

///|
