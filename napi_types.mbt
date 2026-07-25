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
