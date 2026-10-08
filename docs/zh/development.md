# 架构开发与贡献指南

本文档深入剖析了 `napi-mbt` 的内部架构设计。它旨在帮助那些想要了解项目底层运作原理、进行系统级调试、或希望为本项目贡献代码的开发者。

## 1. 系统架构总览

`napi-mbt` 被设计为 V8 JavaScript 引擎与 MoonBit 语言之间的高性能、自动化桥梁。其底层直接依赖于标准的 Node-API (N-API)。

我们的架构由三个边界清晰的层次组成：
1. **工具链核心 (`napi-mbt-cli`)**：独立 MoonBit 原生程序，静态链接 Tree-sitter，完成 AST 分析、生成与原生构建，无需 Node/npm。
2. **MoonBit N-API 运行时引擎**: 包含与 N-API 对接的基础内存通信结构和类型转换 helper。
3. **C glue (`napi_glue.c`)**：提供 Node-API 注册入口和逐导出的回调。


Node-API 是纯 C 的接口协议。当 Node.js 试图调用一个原生扩展时，它要求目标必须是签名类似于 `napi_value cb(napi_env env, napi_callback_info info)` 的标准 C 函数指针。

然而，当前的 MoonBit 尚不能直接将其内部的动态闭包作为原生 C 函数指针导出给宿主。
为了解决这一语言层面的阻隔，生成器为每个导出函数生成独立的 adapter 和 C wrapper。

## 2. 逐导出 C wrapper 架构

CLI 为每个 `#export_name("...")` 函数生成一个 MoonBit adapter 和独立的 N-API callback。调用时直接进入对应 adapter，不使用全局 dispatcher 或函数 ID。

1. **加载初始化**：Node.js 调用 `napi_glue.c` 的 `napi_register_module_v1`，该函数调用 `moonbit_init()`。
2. **函数挂载**：生成的 C glue 为每个导出创建独立的 N-API callback，并把同名属性挂载到 exports。

## 3. 双重 GC 灾难与内存安全

MoonBit 和 V8 分别拥有完全独立的垃圾收集器 (Garbage Collectors)。在这两者之间随意传递内存非常危险。

- `Int`, `Double`, `Bool` 属于基础数据类型，直接通过寄存器传递，GC 风险为零。
- `String` 涉及到内存申请，Node-API 会自动帮你将 V8 字符串提取成 MoonBit 独立管理的 String 对象。
- `Bytes` 使用了 `napi_create_buffer_copy`。数据被完全克隆进了 MoonBit 的 GC 堆内，由于两边拥有各自独立的内存副本，因此安全性达到 100%。
- `NapiBufferView` 极其危险。我们在此处刺穿了 GC 边界，直接抽取出 V8 数组的底层物理内存地址指针 (`napi_get_buffer_info`)。需要极其注意的是：V8 的“移动式垃圾回收机制 (Moving GC)”可能在任何非同步周期内把内存搬家，导致指针变成野指针。所以，`NapiBufferView` 在结构上被严格限制在同步的 Call Stack 中使用，杜绝持久化引用。

## 4. 参与 `napi-mbt` 的贡献

### 在本地进行测试
我们的测试用例无需执行任何外围发布。
先执行 `moon build --target native --release cmd/napi-mbt-cli` 构建 CLI，再用 `moon run --target native --release cmd/napi-mbt-cli -- build --release` 构建根项目扩展。`moon run scripts/ci-regression-test.mbtx` 在隔离 Node/npm 的环境测试原生命令，`moon test --target native` 执行单元测试。最后用 `node --test scripts/test.js` 加载已生成的根项目及测试项目扩展。

### 验证 Npm 分发逻辑
为了调试 `napi-mbt prepublish` 所输出的多平台分发架构，请运行：
```bash
napi-mbt-cli prepublish
```
该指令会在 `npm/` 文件夹中输出各平台包的元数据。生成的 `index.cjs` 和 `index.mjs` 负责加载这些平台包。

### 如何添加对新数据类型 (如 Object/Array) 的支持
1. 在 `generator/strict.mbt` 中扩展导出签名校验与类型模型。
2. 在 `generator/outputs.mbt` 中扩展适配代码和 TypeScript 声明；运行时模板变化时同步更新 `internal/assets/data/resources.json`。
3. 在 `lib.mbt` 内: 调用底层的 Node-API（如 `napi_get_named_property` 等等），编写底层的内存提取和安全检验逻辑。

### 常见问题排查 (Troubleshooting)

构建由 MoonBit、CMake 和平台 C 编译器完成。检查 `napi-mbt.json` 的 builder/target 配置，并确认对应的 CMake、clang/GCC 或 MSVC 工具链已安装。
