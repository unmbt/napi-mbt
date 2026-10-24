# 低层 JS 与 N-API 扩展

`NapiObject`、`NapiFunction` 和 `NapiArray` 是通用 JS 值的环境绑定包装，
支持属性读写、属性描述符、调用/构造、原型、`instanceof`、类型检查以及
同步和 escapable HandleScope。作用域必须在创建它的回调中关闭；需要跨回调保存
的值使用 `NapiReference`。

导出函数可以把 `env : NapiEnv` 放在参数中取得当前环境；它不会出现在 JS 或
TypeScript 参数列表中。`NapiValue`、`NapiObject`、`NapiFunction` 和 `NapiArray`
作为直接参数时也由生成器注入/校验，适合组合下面的低层 API；这些借用句柄不能
嵌入容器或跨 async/worker 边界。

`NapiExternal::new` 接受调用方管理的 `UnmanagedBuffer`。`napi_external_buffer`
和 `napi_external_arraybuffer` 则持有 MoonBit `Bytes` 的引用，并在 JavaScript
GC 回收时释放；因此 backing store 在 JS 存活期间不会悬空。`NapiDataView` 是
拥有型快照，`napi_buffer_from_arraybuffer` 在 N-API 10 上创建 ArrayBuffer 的
零拷贝 Buffer view。

N-API 8 的 object freeze/seal 与 type tag、N-API 6 的 instance data、N-API 9
的 `Symbol.for`/SyntaxError/module filename，以及 N-API 10 的 property key、
external Latin-1 string 都有直接包装。配置中可用 `features` 对这些能力声明
最低 N-API 版本，CLI 会在生成前检查版本。

## typed TSFN

`NapiTypedThreadsafeFunction[T]` 需要一个 `T -> Bytes` 编码器。`call` 在后台
线程只复制编码后的 bytes；Node 的 JS 线程回调接收一个 Buffer。队列满返回
`QueueFull`，关闭后返回 `Closing`，不把 MoonBit 闭包或 GC 对象传入后台线程：

```moonbit
let tsfn = NapiTypedThreadsafeFunction::new(env, callback, 32, fn(_value : Int32) {
  b"payload"
})
ignore(tsfn.try_call(42))
```
