# 支持策略

| 层次 | 策略 |
| --- | --- |
| 原生 CLI | 不依赖 Node/npm |
| 新 addon | 默认 N-API 4，同时开启 CJS/ESM |
| 主 Node CI | 七种原生宿主上的 22、24、26 |
| 最低版本消费者 | Node 10.16：CJS/N-API 4；12.20：双入口/N-API 4；12.22：async/N-API 8 |
| 原生构建门禁 | Windows x64 MSVC、Linux x64/ARM64 glibc 与 musl、macOS x64/ARM64 |
| 新平台验证状态 | Linux ARM64、macOS x64 与 Alpine musl 已配置并由托管 CI 执行 |
| 交叉编译 | CLI 要求匹配宿主，拒绝不同目标 |
| libc | glibc 与 musl；工具链探测及 addon 的 ELF 动态依赖必须与宿主一致 |

生成的 `engines.node` 是 N-API 引入版本与 loader 要求的交集。默认双入口为
`>=12.20.0 <13 || >=14.13.1`。N-API 8 为
`>=12.22.0 <13 || >=14.17.0 <15 || >=15.12.0 <16 || >=16.0.0`。
其他配置会生成各自的精确范围。最低版本测试用于验证兼容范围，不建议部署 EOL Node。

| 功能 | 最低 N-API |
| --- | ---: |
| 数值、Bool、UTF-16 字符串、普通结构化值 | 1 |
| class/callback 生命周期 | 3 |
| Threadsafe Function | 4 |
| Int64/UInt64 bigint | 6 |
| Bytes、带检查的 BufferView | 7 |
| DataView、BigInt64Array/BigUint64Array、External/零拷贝 Buffer | 7（External 基础值为 1） |
| 内嵌 async 宿主、Promise 导出和异步 cleanup | 8 |
| freeze/seal、type tag | 8 |
| Symbol.for、SyntaxError、module filename | 9 |
| property key、external string、ArrayBuffer-backed Buffer | 10 |
| 高层 typed TSFN | 4 |

N-API 原始 Promise API 属于 v1；内嵌 async 宿主明确需要 N-API 8 cleanup API。
结构化值嵌入 bigint/Buffer 时继承更高版本要求。
`moonbitlang/async` 必须恰好为 0.22.4。

所检查 napi-rs CLI 声明 `^20.17.0 || ^22.13.0 || >= 23.5.0`，其核心默认开启
`napi4` 和 `dyn-symbols`，并非所有 addon 都要求 Node 22。
napi-mbt 对齐默认 N-API，并区分 CLI 与运行时要求。

CI 固定 Moon/core `0.10.17+093cb8f9c`、CMake 4.4.4、构建 Node 26.4.0。
CMake 包含当前 Windows runner 使用的 Visual Studio 18 2026 生成器。
项目检查先于模板校验执行，以下载依赖；`moon update` 只刷新注册表索引。
`moon run scripts/ci-bootstrap-test.mbtx` 在 Git 源码的无项目缓存临时副本中
重跑依赖和模板校验。
对应 moon/moonrun 为 `0.1.20261021 (a4f8933)`，启用 `rr_moon_mod,rr_moon_pkg`。
固定版本 CI 和 WSL 使用 `moon run scripts/toolchain-check.mbtx` 核验编译器、
构建器、runner 和 feature flags，与当前 Windows 工具链一致。
本机 Windows 使用 MSVC 19.44.35211、MSBuild 17.14.14、SDK 10.0.26100.0。
托管 runner 的编译器/SDK 仍可能更新；`doctor --json` 记录实际选择，构建以真实
compile/link probe 验收。新 MoonBit 兼容性另设 job。
2026-10-24 的 [PR #4](https://github.com/unmbt/napi-mbt/pull/4) 已在低层与高级 API
提交上通过 native gates、Node 22/24/26、最低 Node 版本消费者、最新 MoonBit
兼容性以及 Windows/Linux 内存检查。
仅 tag 触发的发布任务本次正常跳过；打包验收通过不代表已完成正式发布。
托管与本机验证证据、剩余平台限制见[验证记录](../validation.md#hosted-ci-confirmation)。
