# 异步导出

在 `moon.mod` 固定 `moonbitlang/async@0.22.4`，导入需要的包，
并在 `napi-mbt.json` 设置 `"napiVersion": 8`。CLI 校验依赖版本和源码校验值后，
只修改隔离构建副本，不修改依赖缓存，也不注册进程信号处理器。

```moonbit
#export_name("delay")
pub async fn delay(ms : Int, value : String) -> String {
  @async.sleep(ms)
  value
}
```

生成的声明是
`delay(ms: number, value: string, options?: { signal?: AbortSignal }): Promise<string>`。
options 位于所有声明参数之后；省略 MoonBit 可选参数但传入 options 时，用 `undefined` 占位。
实例方法和静态方法支持 async，构造器、getter/setter 必须同步。

参数转换、业务执行、返回值转换失败都会拒绝 Promise。业务错误使用 `ERR_NAPI_CALL`；
JS callback 抛出的值会原样保留，包括基本类型和挂起后重新抛出的异常。
`NapiReference` 用于跨 handle scope 持有 JS 值，提供幂等 `dispose()`；
原始 `NapiValue` 只能在当前 scope 内使用。

```js
const controller = new AbortController()
const result = addon.delay(100, 'ready', { signal: controller.signal })
controller.abort(new Error('cancelled'))
await result // 拒绝值就是上面同一个 Error
```

已取消的 signal 阻止业务执行；执行期间取消以 `signal.reason` 拒绝一次，
缺少 reason 时使用带 `ABORT_ERR` 的 `AbortError`，随后排空任务组和原生 I/O。
完成、失败、取消共用一次性状态，所有路径都会释放监听器和持久引用。
取消是协作式的：同步 MoonBit 运算必须返回或到达挂起点，Node 才能分发其他事件。

跨异步边界使用拥有数据的 `Bytes`；异步签名中的借用 `NapiBufferView` 会被拒绝。
参数在调度前完成转换。MoonBit 执行和引用计数均在所属 Node 环境线程及 addon 锁内完成，
后台线程只做 C I/O 和等待。Node callback scope 保证 Promise 微任务无需等待其他 JS 定时器。
标准流句柄、输入缓冲和调度器按环境隔离。

worker 关闭时取消任务并等待 I/O 清理，不在关闭中的环境调用 JS 或 settle Promise。
参见 [适配实现](async-adapter.md) 和 [实际验证记录](../validation.md)。
`moon run scripts/async-exports-test.mbtx` 运行真实 addon 用例，
`moon run scripts/sanitizer-test.mbtx` 统一执行 parser 和原生内存检查。

异步导出在当前 JS realm 构造 Promise，并将 resolve/reject 函数作为环境所属的
callback 引用持有；完成或关闭时释放。这样避免 worker 强制终止后留下无法通过
Node-API 释放的未完成 `napi_deferred`。替换全局 Promise 构造器时，必须同步调用
executor 并传入两个函数；非法构造器及延迟调用 executor 报 `ERR_NAPI_PROMISE_EXECUTOR`。
