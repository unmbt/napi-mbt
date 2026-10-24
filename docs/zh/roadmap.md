# 后续推进顺序

当前基础已经包括错误短路、单一校验生成器、严格配置/loader、隔离构建、
拥有/借用值转换、Date/Set/Symbol/同步迭代器、class/callback 和固定版本的 Node 驱动 async 宿主。
Mooncakes 安装闭环、独立样例、隔离增量缓存、构建记录、拥有型二进制类型、
原生任务、进程池、JS Promise 输入和 Web 流已实现。

后续按以下顺序推进：

1. 正确性与诊断优先于扩展 API，持续保留原生消费者、worker、取消、内存和安装门禁。
2. 每个新 API 先确定表示、所有权、错误契约和 TypeScript 消费方式，再实现。
   泛型导出和额外容器类型在语义与测试完善前保持明确不支持。
3. 继续推进可复现的托管编译器镜像。build receipt 已检查输入、工具链、生成文件
   和二进制是否过期；它是本地一致性记录，不是签名的供应链证明。
4. 七个原生目标已配置门禁；本次低层与高级 API 已通过托管 CI 的 Linux ARM64、
   macOS 和 musl 任务。
5. 按实际工作负载优化：缓存失效、流吞吐和进程池启动是后续测量重点。
   已记录的转换性能是本机测量，不作“零开销”保证。

async 补丁固定 0.22.4 并核对源码校验值。升级必须审阅上游调度器/所有权变化，
重跑 I/O、取消、worker teardown 和 sanitizer；补丁只能应用到隔离构建工作区。

WASI、交叉编译、跨线程共享 MoonBit 闭包和 Node Readable 专用适配仍待后续推进。
当前已提供 External/零拷贝内存、DataView/BigInt TypedArray、通用低层 JS API、
N-API 8/9/10 扩展，以及编码型高层 typed TSFN；共享内存 TypedArray 仍明确拒绝，
避免把不可安全复制的 backing store 带入拥有型值。
