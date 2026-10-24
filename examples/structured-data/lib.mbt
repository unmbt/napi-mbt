///|
pub(all) struct Profile { name : String; age : Int? }
///|
pub(all) enum Event { Ready; Message(String) }
///|
#export_name("profile")
pub fn profile(value : Profile) -> Profile { value }
///|
#export_name("event")
pub fn event(value : Event) -> Event { value }

///|
/// Map uses a plain JS record, not the JavaScript Map class.
#export_name("records")
pub fn records(value : Map[String, Profile]) -> Map[String, Profile] { value }

///|
#export_name("json")
pub fn json(value : Json) -> Json { value }

///|
#export_name("tuple")
pub fn tuple(value : (String, Int, Bool?)) -> (String, Int, Bool?) { value }

///|
#export_name("tomorrow")
pub fn tomorrow(value : NapiDate) -> NapiDate {
  NapiDate::new(value.milliseconds() + 86400000.0)
}

///|
#export_name("symbol")
pub fn symbol(value : NapiSymbol) -> NapiSymbol { value }

///|
#export_name("set")
pub fn set(value : NapiSet[Int]) -> NapiSet[Int] { value }

///|
/// Early exit closes the source, including a JavaScript generator's finally.
#export_name("first")
pub fn first(value : NapiIterator[Int]) -> Int? raise {
  defer (value.close() catch { _ => () })
  value.next()
}

///|
#export_name("range")
pub fn range(limit : Int) -> NapiIterator[Int] raise {
  let current = Ref(0)
  NapiIterator::new(() => {
    if current.val >= limit { None } else {
      let value = current.val
      current.val += 1
      Some(value)
    }
  })
}
