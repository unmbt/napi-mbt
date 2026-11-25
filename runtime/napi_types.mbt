// 使用 #external 注解定义 N-API 的不透明指针，由 C 侧管理生命周期

///|
#external
pub type NapiEnv

///|
#external
pub type NapiValue

///|
#external
pub type NapiCallbackInfo

///|
#external
pub type UnmanagedBuffer

///|
#external
pub type NapiDeferred

///|
#external
pub type NapiThreadsafeFunction

///|
/// Opaque handle to a synchronous N-API handle scope.
#external
pub type NapiHandleScope

///|
/// Opaque handle to an escapable N-API handle scope.
#external
pub type NapiEscapableHandleScope

///|
pub struct NapiPromise {
  promise : NapiValue
  deferred : NapiDeferred
  mut settled : Bool
}

///|
pub(all) enum NapiTsfnStatus {
  Accepted
  QueueFull
  Closing
}

///|
pub(all) enum NapiTsfnCallMode {
  Nonblocking
  Blocking
}

///|
pub(all) enum NapiTsfnReleaseMode {
  Release
  Abort
}
