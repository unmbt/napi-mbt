# 原生线程与 TSFN

在 MoonBit 所属线程使用 typed 队列包装时，参考[高级示例](../../examples/advanced-api/README.md)
和[typed API 指南](advanced-api.md#高层-typed-tsfn)。编码器是 `call` 同步执行的
MoonBit 闭包，不能在任意原生线程运行；下方 C fixture 才是原生线程生产者示例。

底层 Threadsafe Function API 继续使用 N-API 4。后台线程只传递 C 拥有的数据，
不访问 MoonBit 对象、引用计数或 JS 句柄；JS 转换和回调只能在所属 Node 线程执行。
关闭时 Node 可能以 `env == NULL` 调用清理回调，此时仍须释放队列中的 C payload。

在另一个线程开始使用 TSFN 前 acquire，正常结束时 release。收到 `napi_closing`
后不得再次调用或 release 此句柄。队列满时，未入队的数据仍由发送方释放。
不要在 Node 线程等待一个正在阻塞等待 Node 消费队列的生产者。

`moon run scripts/tsfn-test.mbtx` 使用真实 Windows/pthread 线程，测试投递、队列满、
acquire/release、abort、12 次强制 worker 退出及 finalizer 一次性执行。
原子计数器验证 payload 全部回收，并检查回调所属线程。强制退出时也覆盖
V8 已终止、Node 尚未进入空环境清理路径的竞态。

使用 `moon run scripts/sanitizer-test.mbtx <cli-path> --fixture tsfn` 执行对应 ASan 测试。
平台实际执行情况见[实施记录](../implementation-progress.md)。
