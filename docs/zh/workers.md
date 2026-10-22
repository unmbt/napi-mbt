# 隔离 MoonBit 后台计算

设置 `"workerTasks": ["compute"]` 与 `"napiVersion": 8`，即可将同步 `pub fn`
在生成的 CJS/ESM 包入口中包装成带 `{ signal? }` 的 Promise API。每个子 Node 进程
直接加载相同 `.node`，MoonBit 运行时和全局状态独立，不需要额外的 MoonBit 可执行文件。
直接加载 `.node` 仍是同步调用；公共接口应使用生成的包入口。

输入输出只允许拥有型值；不支持 class、callback、借用视图、原始 JS 句柄或流。
输入在提交时用同一类型 IR 验证并复制，bigint、UTF-16、Buffer 和 TypedArray 通过
Node 二进制 IPC 保留。排队后修改输入不会影响计算。

`workerPool` 默认 `size: 2`、`maxQueue: 64`、`idleTimeoutMs: 30000`，懒启动且每个
进程同时执行一个任务。取消排队项会移除它；取消运行项会终止对应进程，按需补建。
崩溃任务不重放。错误跨进程保留名称、消息、stack 和错误码，父进程取消原因保留身份。

原生环境清理 hook 补足 JS 退出事件，覆盖 worker_threads 强制终止；空闲子进程
不会阻止父进程退出。worker 入口随用户 npm 主包一起发布。
参见[完整行为契约](../workers.md)和[独立样例](../../examples/worker-tasks/README.md)。
