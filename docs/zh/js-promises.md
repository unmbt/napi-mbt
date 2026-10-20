# JavaScript Promise 输入

导出函数可以接收 `NapiJsPromise[T]`，并在 MoonBit `async fn` 中调用 `value.wait()`。
对应的 TS 参数为 `Promise<T>`；需要 N-API 8 和 `moonbitlang/async@0.22.4`。
只接受实际 Promise，不接受普通 thenable；该包装是输入类型，输出 Promise 使用
`async fn`。禁止借用 BufferView 穿过 Promise 边界。

完成值由现有类型转换器验证一次，支持重复或并发等待。拒绝值（包括原始值）在同一
Node 环境内保留身份。等待会挂起协程，完成回调负责唤醒，不轮询或阻塞事件循环。

完成、显式 `dispose()`、最后一个等待者取消或环境关闭时释放订阅引用。取消只停止
等待，不取消原始 JS 操作；迟到的回调安全返回，不产生额外的未处理拒绝。包装绑定
所属环境，不能交给进程池任务。

参见[详细行为契约](../js-promises.md)。
