# 异步迭代器与 Web 流

使用 `NapiAsyncIterator[T]`，配置 N-API 8 并依赖 `moonbitlang/async@0.22.4`。
CLI 自动推导 async/streams 和 Node >=18（更高 N-API 要求仍有效）。
完整用法见 [独立样例](../../examples/streams) 和 [行为契约](../streams.md)。

`NapiAsyncIterator::new(produce, close)` 接收两个异步函数；生产函数返回
`Some(value)` 或 `None`。MoonBit 中调用异步 `next()` 和幂等 `close()`。
消费输入时用 `defer input.close()` 覆盖提前返回和取消。关闭函数应有界，
环境退出时不得访问 JS；无限等待的清理也会阻碍环境退出。

JS 输入接受 AsyncIterable 或 Web ReadableStream；输出支持 `for await`、
`next/return/throw` 和 `toReadableStream({ signal })`。并发读取串行执行，
只按需求生产；关闭取消生产并完成 pending 读取。一个实例只允许一条消费链。
AbortSignal 原因和同环境 JS 异常保留身份。输入 Web 流关闭时取消 reader
并释放锁；普通 JS 迭代器的 `return` 需要自身协作结束。

元素使用统一类型转换，不允许借用 BufferView。流不能传入进程池 workerTasks。
Web 适配使用 Node 标准实现，不附带 polyfill。
