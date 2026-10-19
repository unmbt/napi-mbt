# MoonBit async 嵌入适配

原生构建器提供由 Node 驱动的 `moonbitlang/async` **0.22.4** 适配。
启用 `async` feature 时要求 N-API **8** 起，使用异步 cleanup hook
在 worker 终止时等待任务取消和未完成的 OS I/O 清理。

适配补丁内嵌于原生 CLI，`scripts/sync-async-adapter.mbtx` 从固定版本依赖和
`internal/async-adapter/` 中的源码派生补丁。manifest 记录依赖版本、补丁版本、
Apache-2.0 许可证，以及规范化 UTF-8 源码修改前后的 FNV-1a 64 位校验值。
校验值用于发现版本或源码不匹配，不是密码学签名。libuv 声明单独保留 MIT 许可证。

构建器先校验全部源文件，再仅在隔离工作区应用修改。缺少依赖、版本不符、
上游源码改变、已有适配文件或包导入冲突均明确报错。用户源码、工程配置、
编译参数、原生输入和依赖缓存保持原样；新 addon 链接成功后才替换产物。

各环境拥有独立 scheduler、事件循环、计时器和 C worker pool。隔离依赖内的
公开适配包提供 `Loop::new`、`submit`、`step`、`next_wake`、`cancel_all`、
`close` 和 `Task::cancel`。操作临时激活所属上下文，结束后恢复此前上下文；
在该上下文中嵌套运行主事件循环会报错。

Node 的 libuv timer 每次驱动一个有界调度轮次，连续就绪任务在轮次间让出执行。
待处理的 OS I/O 最迟两毫秒后再次检查，计时任务按下一截止时间唤醒。
空闲环境不保持活跃 timer，允许 Node 正常退出。这是便于验证的初始调度实现，
后续基准需衡量调度延迟和轮询开销。执行计算密集型 MoonBit 代码时，仍占用其 JS 线程。

MoonBit 代码、finalizer 和引用计数均在所属 JS 线程、addon 的可重入锁内执行；
后台线程只执行 C I/O。Windows 使用 `CancelSynchronousIo`；POSIX 仅在可取消
系统调用区域启用 deferred pthread cancellation，并在线程复用前 join。
适配器不安装进程信号处理器，也不修改 Node 线程的信号屏蔽。

环境关闭时取消任务，持续驱动取消清理并等待 I/O，随后关闭事件循环、释放
MoonBit 状态，最后完成 N-API 异步 cleanup hook。取消不会提前丢弃 OS 仍可能
访问的缓冲区。

`scripts/async-adapter-test.mbtx` 验证独立上下文和取消；
`scripts/async-runtime-test.mbtx` 构建真实 addon，验证计时器、文件、TCP、任务组、
JS 心跳、worker 终止、依赖源码不变，以及版本和校验失败诊断。
Windows 的 sanitizer 入口为
`scripts/lifecycle-sanitizer.mbtx <asan-runtime-directory> --async`。
