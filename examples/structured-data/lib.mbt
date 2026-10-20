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
