# 支持策略

| 层次 | 策略 |
| --- | --- |
| 原生 CLI | 不依赖 Node/npm |
| 新 addon | 默认 N-API 4，同时开启 CJS/ESM |
| 主 Node CI | 三个发布平台上的 22、24、26 |
| 最低版本消费者 | Node 10.16：CJS/N-API 4；12.20：双入口/N-API 4；12.22：async/N-API 8 |
| 发布平台 | Windows x64 MSVC、Linux x64 glibc、macOS ARM64 |
| 其他已识别宿主 | Linux ARM64 glibc、macOS x64；没有预编译发布门禁 |
| 交叉编译 | CLI 要求匹配宿主，拒绝不同目标 |
| libc | glibc；拒绝 musl |

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
| 内嵌 async 宿主、Promise 导出和异步 cleanup | 8 |

N-API 原始 Promise API 属于 v1；async 宿主需要 v8 cleanup。
结构化值嵌入 bigint/Buffer 时继承更高版本要求。
`moonbitlang/async` 必须恰好为 0.22.4。

所检查 napi-rs CLI 声明 `^20.17.0 || ^22.13.0 || >= 23.5.0`，其核心默认开启
`napi4` 和 `dyn-symbols`，并非所有 addon 都要求 Node 22。
napi-mbt 对齐默认 N-API，并区分 CLI 与运行时要求。

CI 固定 Moon/core `0.10.15+943464bfa`、CMake 4.0.3、构建 Node 26.4.0。
对应 moon/moonrun 为 `0.1.20261012 (748b63c)`，启用 `rr_moon_mod,rr_moon_pkg`。
固定版本 CI 和 WSL 使用 `moon run scripts/toolchain-check.mbtx` 核验编译器、
构建器、runner 和 feature flags，与当前 Windows 工具链一致。
本机 Windows 使用 MSVC 19.44.35211、MSBuild 17.14.14、SDK 10.0.26100.0。
托管 runner 的编译器/SDK 仍可能更新；`doctor --json` 记录实际选择，构建以真实
compile/link probe 验收。新 MoonBit 兼容性另设 job。
实际运行结果见[验证记录](../validation.md)。
