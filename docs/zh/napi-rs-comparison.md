# 与 napi-rs 的对齐情况

以本地下载的 napi-rs 源码为参考；参考 checkout 不属于 napi-mbt 的发布内容。
这份文档描述当前实现，不保留已删除接口的迁移路径。

| 方面 | napi-mbt 当前实现 |
| --- | --- |
| 生成器 | 单一 AST/类型 IR；整体校验后生成 adapter、C、TS、loader 和元数据 |
| 错误 | 可传播 NapiError；转换失败短路；保留原 JS 异常身份 |
| 类型 | 严格 Int/UInt、IEEE Float/Double、bigint、UTF-16、Buffer、Option/Array、Map、Json、tuple、struct/enum |
| 生命周期 | 显式 class、receiver 验证、dispose、callback 引用、重入和 worker 清理 |
| 异步 | 固定 async 0.22.4 的隔离补丁，Node 驱动调度，Promise 和 AbortSignal |
| 开发体验 | doctor、严格 schema、独立 CJS/ESM、watch、计时和明确加载错误 |
| 工程 | 保留用户配置和依赖输入，隔离构建，完整输出快照和真实消费者 |
| 分发 | 二进制/版本/入口校验，pack、干净安装、TS、ASan、平台矩阵 |

napi-rs 并非统一 Node 22 起。所检查源码的 `cli/package.json` 声明
`^20.17.0 || ^22.13.0 || >= 23.5.0`；`crates/napi/Cargo.toml` 默认
`["napi4", "dyn-symbols"]`。CLI 的 Node 需求和 addon 的 N-API 需求是两层。
napi-mbt 原生 CLI 无 Node 依赖，新工程默认 N-API 4，addon 最低 Node 版本按
功能和 loader 推导，主 CI 为 Node 22/24/26，另测最低版本。

测试参考 napi-rs 的消费者验收方式：实际加载和执行、类型正反例、worker、错误恢复、
生命周期、异步和安装包。没有复制其完整 API 或全部平台矩阵。
异步实现基于 MoonBit 的调度器，与 Rust 的实现不同；N-API cleanup 要求和运行线程
约束仍需明确满足。当前发布平台为 Windows x64、Linux x64 glibc、macOS ARM64。

详见[支持矩阵](support.md)、[实际验证](../validation.md)、[性能结果](performance.md)
和[路线图](roadmap.md)。
