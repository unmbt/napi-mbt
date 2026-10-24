# 工程化与分发

生成链路为 AST → 类型 IR → 整包校验 → MoonBit/C/TypeScript/loader。
`generator/` 是唯一公开生成器；`internal/syntax/` 包含内嵌 parser，
[来源记录](../../internal/syntax/VENDOR.md)说明固定版本和许可证。

根目录 runtime 源码是唯一来源。修改后运行 `moon run scripts/sync-runtime.mbtx`，
资源构建规则再生成内嵌文本。async 0.22.4 适配有独立源码、校验值和许可证，使用
`moon run scripts/sync-async-adapter.mbtx` 同步。两者都支持 `--check`，并进入 CI。
不要手工修改 `resources.json` 中的 runtime 副本。

每次 addon 调用进入可重入的 addon 锁。MoonBit 代码和引用计数在所属 JS 环境线程执行；
C 回调在重入期间保留借用 payload，持久 JS 引用有明确释放路径。
Class finalizer、dispose 和环境关闭使用统一资源管理。Node 驱动有限轮次的异步调度；
后台线程仅负责 C 层等待/I/O。详见[异步架构](async-adapter.md)。

## 验证

```sh
moon info --target native
moon fmt
moon check --target native --warn-list +73 --deny-warn
moon build --target native --release cmd/napi-mbt-cli
moon test --target native cmd/napi-mbt-cli generator internal/syntax internal/assets
moon run --target native --release cmd/napi-mbt-cli -- build --release
pnpm install --frozen-lockfile --ignore-scripts
moon run scripts/ci-regression-test.mbtx
moon run scripts/ci-consumers.mbtx
moon run scripts/sanitizer-test.mbtx
```

核对 `.mbti` 的公开接口变化。快照更新必须审阅完整输出，再运行实际编译和 Node
消费者测试。测试覆盖 NodeNext/Bundler 正反例、worker 关闭、取消竞态、资源计数、
Unicode、分离 Buffer、用户配置和原生依赖；子进程测试带超时。
ASan 覆盖 parser 与 addon；Linux 额外启用 leak detection。
[验证记录](../validation.md)区分本机结果与仅配置的 CI job。

单元测试明确选择 CLI、生成器、parser 和 assets 包。根目录 foreign library 依赖 Node
宿主，运行时由真实 addon 消费者测试，不作为独立的 MoonBit 测试程序链接，也不依赖
此前本机构建残留的头文件或 import library。ASan 使用 VS 默认 C++ 工具集对应
的运行库。Linux 仅抑制 Node 26.4.0 的两个宿主分配点：OpenSSL 启动时的
`ossl_load_builtin_compressions`，以及 eval worker 脚本的 `ContextifyScript` cppgc
包装对象。两者均可在不加载 addon 时复现。空 Node worker 和故意泄漏的独立探针
验证泄漏检测仍然有效；不使用整库抑制规则。

## 打包门禁

`moon.mod` 中的 Mooncakes 版本独立于根目录 private npm 清单；package.json 与
lockfile 必须一致，release tag 会根据 `moon.mod` 核对。
`prepublish` 拒绝缺失、架构错误、非动态库构件和过期声明/生成物，保留用户包元数据，
并附带第三方许可证。生成的 `npm/`、`artifacts/`、`licenses/` 不入库。

在仓库根目录使用 `moon-bump` 发版。配置中的 `prepare-release.mbtx` 会先根据
`moon.mod` 规范化开发锁文件，再严格检查项目（同时重新生成 CLI 版本），并在
提交、打 tag 前执行发布检查。它不会把 private npm 版本同步到 `moon.mod`。
`all: true` 会将这些生成的改动一起提交。可运行
`moon run scripts/prepare-release.mbtx` 修复并验证当前 checkout。
CI 仍执行不带 `--write` 的 `release-check.mbtx`，版本不一致时会失败。

源码清单包含开发依赖，不包含尚未发布的平台包。`prepublish` 为分发添加平台依赖，
根目录分发测试结束后恢复源码清单。`source-install-test.mbtx` 在仅含清单的全新临时
目录中执行 `pnpm install --frozen-lockfile`，并验证缺少条目的 lockfile 会被门禁拒绝。

```sh
moon run scripts/release-check.mbtx
moon run scripts/distribution-test.mbtx
moon run scripts/mooncake-package-test.mbtx
```

分发测试执行 pnpm pack/dry-run，在干净目录离线安装真实 tarball，再加载 CJS/ESM 并
检查已安装的 TypeScript 声明。也验证损坏二进制、过期声明和版本不一致会失败。
只打包临时生成的用户 addon；napi-mbt 自身仅通过 Mooncakes 发布。
目前构件没有绑定源码摘要的 build receipt，打包前应构建当前 checkout。

Mooncake 门禁使用 `moon package` 检查 ZIP 清单、解包并严格检查。在没有 Node/npm
的 PATH 下安装 CLI，删除解包源码后，使用安装所得 CLI 在仓库外初始化和构建工程，
再验证 CJS/ESM 和 TypeScript 消费者。不依赖 registry 登录或版本是否已发布。
`moon publish --dry-run` 还会访问 registry
检查版本可用性；已存在的版本可能返回 409，不代表解包后的源码检查失败。

CI 固定 Moon/core 和 CMake，覆盖当前可用的原生目标，测试 Node 22/24/26 与最低版本，
通过后才生成 release 归档；新 MoonBit 兼容性独立测试。
自动化使用 `.mbtx`；`.cjs/.mts/.cts` 是真实消费者。下载的 `napi-rs/` 仅供本地参考。
本次托管运行已通过 macOS x64、Linux ARM64 与两个 musl profile 的 native 门禁；
托管工具链变化时应同步更新平台表和 CI 记录。
[性能](performance.md)和[路线图](roadmap.md)记录后续优化与平台工作。
