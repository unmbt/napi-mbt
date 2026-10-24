# 低层 JS 与 N-API 扩展

本页面向需要手写 JavaScript 互操作的同步绑定。`NapiEnv` 不会出现在生成的 JS/TS
参数中；它只作为 MoonBit 导出函数的隐藏直接参数。

## 环境绑定值

```moonbit
///|
#export_name("readName")
pub fn read_name(env : NapiEnv, object : NapiObject) -> String raise {
  get_String(env, object.get(env, "name"))
}
```

JS 签名是 `readName(object: object): string`。`NapiObject`、`NapiFunction`、
`NapiArray`、`NapiValue` 和 `NapiExternal` 只能作为直接参数或返回值，不能嵌套在
owned struct、Promise、stream、worker payload 中，也不能跨 async 边界。需要长期保存
的 JS 值使用 `NapiReference`。

`NapiObject` 提供 `get`、`set`、`has`、`define_property`、`keys`、`prototype`、
`is_instance_of`；`NapiFunction` 提供 `call`、`new_instance`；`NapiArray` 提供
`new`、`length`、`get`、`set`。`napi_value_type`、`napi_strict_equal`、
`napi_global`、`napi_undefined` 用于通用值操作。HandleScope guard 必须在环境线程
关闭。

## External 与零拷贝内存

`NapiExternal::new(env, pointer)` 包装调用方管理的 `UnmanagedBuffer`，不会释放指针。
以下 helper 会持有传入 Bytes，直到 JS GC 回收：

```moonbit
let buffer = napi_external_buffer(env, bytes)
let arraybuffer = napi_external_arraybuffer(env, bytes)
let (latin1, copied) = napi_external_string_latin1(env, bytes)
```

backing store 是共享的，JavaScript 可以修改它；需要拷贝时使用拥有型
`NapiUint8Array`、`NapiArrayBuffer` 或 `NapiDataView`。`napi_buffer_from_arraybuffer`
在 N-API 10 上创建 ArrayBuffer-backed Buffer view，并在 C 层检查 offset/length。

`NapiDataView` 是拥有型字节快照：

```moonbit
let view = get_NapiDataView(env, input)
let output = set_NapiDataView(env, view)
```

拥有型 `NapiBigInt64Array`、`NapiBigUint64Array` 与其他 TypedArray 一样提供 `new`、
`length`、`to_array`。所有拥有型二进制转换都会拒绝 detached ArrayBuffer 和
SharedArrayBuffer backing。

## N-API 8/9/10 helper

- N-API 8：`napi_object_freeze`、`napi_object_seal`、`napi_type_tag_object`、
  `napi_check_object_type_tag`。
- N-API 6：`napi_set_instance_data`、`napi_get_instance_data`。
- N-API 9：`napi_symbol_for`、`napi_syntax_error`、`napi_throw_syntax_error`、
  `napi_module_file_name`。
- N-API 10：`napi_property_key`、`napi_external_string_latin1`、
  `napi_buffer_from_arraybuffer`。
- 运行时检查：`napi_version`、`napi_adjust_external_memory`、
  `napi_detach_arraybuffer`、`napi_is_detached_arraybuffer`。

在 `napi-mbt.json` 声明 feature，CLI 会在生成前检查最低版本：

```json
{
  "napiVersion": 10,
  "features": ["external_string", "property_key", "buffer_from_arraybuffer"]
}
```

## 高层 typed TSFN

`NapiTypedThreadsafeFunction[T]` 用于后台生产者。编码器返回 `Bytes`，运行时先复制
到 C-owned payload，JS callback 在 Node 线程收到 Buffer：

```moonbit
let tsfn = NapiTypedThreadsafeFunction::new(
  env,
  callback,
  32,
  fn(value : Int32) { b"payload" },
)
ignore(tsfn.try_call(42))
ignore(tsfn.acquire())
ignore(tsfn.release())
```

`call` 接收 `Nonblocking` 或 `Blocking`，`try_call` 是非阻塞；队列满或关闭状态以
`NapiTsfnStatus` 返回，由生产者决定重试或丢弃。`abort` 停止 TSFN 并结束 producer
计数。后台线程不会调用 MoonBit 闭包或访问 JS handle。

## 错误与验证

所有 C status 都转换为 `NapiError`，并保留 pending JS exception 的原身份。生成器在
写出文件前拒绝嵌套或跨 async/worker 的低层句柄。完整所有权、版本门槛和测试命令见
[SDD](sdd.md)。
