# 转换性能

String 直接复制 UTF-16 code units，保留 NUL 和孤立 surrogate。输入只分配一次，
Node 写入尚未对外暴露的新 MoonBit 字符串；输出字符串在 Node 复制期间保持借用。
Bytes 输入使用一次分配和 `memcpy`，输出仍是 Node 拥有的副本；不再构造中间 Array。
空 Buffer 不把空指针传给 `memcpy`。

2026-10-19 在 Windows x64、Ryzen 7 8845HS、Node 26.4.0、
moonc v0.10.15+943464bfa、MSVC 19.44.35211 上比较 runtime 6 与 7。
预热后采样五次，保留全部原始数据；代表性的中位数如下（微秒/次往返）：

| 场景 | 优化前 | 优化后 |
| --- | ---: | ---: |
| 两数调用 | 0.552 | 0.544 |
| ASCII，1,024 code units | 28.384 | 1.897 |
| Unicode/NUL，1,280 code units | 71.080 | 1.802 |
| 4 KiB Buffer | 46.787 | 4.126 |
| 1 MiB Buffer | 10,479.528 | 1,167.172 |
| 100 个一组的零延时异步计时器 | 45.918 | 110.334 |

这是本机微基准，不代表所有平台。异步计时器受 Windows 计时分辨率和负载影响，
本次结果更慢，不能据此声称异步性能提升；本阶段没有修改调度器。
[完整结果与复现步骤](../performance.md)记录了空、64 字节、64 KiB Buffer、
全部样本和机器信息。

新工程首次构建 29.884 秒，重复构建分别 29.573、30.526、30.087 秒。
这里的“冷”指新工程，工具链已经安装；“热”指重复构建同一工程。
每次仍使用新的隔离工作区，目前没有增量对象缓存。

```sh
moon run scripts/benchmark.mbtx before --capture
moon run scripts/benchmark.mbtx before
# 重建修改后的根 addon 和 async-exports fixture 后：
moon run scripts/benchmark.mbtx after --capture
moon run scripts/benchmark.mbtx after --build
```

报告位于 `.napi-mbt/benchmarks/<label>/results.json`，`--record` 将已有报告复制到
`docs/benchmarks/`。基准使用普通构建；独立的 Windows ASan 测试覆盖全部 UTF-16
code unit、非法输入、空/切片/分离 Buffer、最大 1 MiB 的独立副本，以及 class、
callback 和异步调用。
