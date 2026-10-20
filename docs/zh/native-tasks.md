# 原生后台任务

在 `napi-mbt.json` 中设置 `"napiVersion": 8` 和
`"nativeTasks": { "compute": "compute_task" }`，将 C 文件加入 `native-stub`。
项目需添加并解析 `moonbitlang/async@0.22.4`；CLI 在隔离工作区加入适配器引用。
JS 接口为 `compute(Buffer, { signal? }): Promise<Buffer>`，MoonBit `async fn`
可以调用 `napi_native_task("compute", bytes)`。普通同步项目的最低版本不变。

C 入口使用 ABI 1 的 `napi_native_task.h`，签名为
`void compute_task(napi_mbt_task_context *)`。输入和 context 仅在入口返回前有效，
结果和错误由辅助函数立即复制。后台线程不持有 MoonBit 全局锁，也不得操作 MoonBit
引用计数或 JS 句柄。C++ 入口必须使用 `extern "C"` 并捕获所有异常。

排队任务可取消，运行中的任务检查 `napi_mbt_task_cancelled` 协作退出。Promise 保留
原始取消原因且只完成一次；调用方取消后，C 内存仍保留至任务实际退出。环境关闭同样
等待退出，且不调用 JS。忽略取消的任务会延长关闭过程，不会被强制终止线程。
输出由现有异步调度器观察，可能增加一个调度 tick 的延迟。

参见[完整契约](../native-tasks.md)和[独立样例](../../examples/native-tasks/README.md)。
