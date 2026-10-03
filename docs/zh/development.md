# 架构开发与贡献指南

本文档深入剖析了 `napi-mbt` 的内部架构设计。它旨在帮助那些想要了解项目底层运作原理、进行系统级调试、或希望为本项目贡献代码的开发者。

## 1. 系统架构总览

`napi-mbt` 被设计为 V8 JavaScript 引擎与 MoonBit 语言之间的高性能、自动化桥梁。其底层直接依赖于标准的 Node-API (N-API)。

我们的架构由三个边界清晰的层次组成：
1. **工具链核心 (`@unmbt/napi-mbt-cli`)**: 基于 Node.js 的 CLI 脚本，统筹所有的 AST 语法分析、依赖挂载、及目标编译。
2. **MoonBit N-API 运行时引擎**: 包含与 N-API 对接的基础内存通信结构和类型转换 helper。
3. **C 蹦床 (`stub.c`)**: 极简的 C 层实现，提供标准 Node-API 注册入口，充当 C ABI 和 MoonBit 运行时之间的缓冲垫。


Node-API 是纯 C 的接口协议。当 Node.js 试图调用一个原生扩展时，它要求目标必须是签名类似于 `napi_value cb(napi_env env, napi_callback_info info)` 的标准 C 函数指针。

然而，当前的 MoonBit 尚不能直接将其内部的动态闭包作为原生 C 函数指针导出给宿主。
为了解决这一语言层面的阻隔，生成器为每个导出函数生成独立的 adapter 和 C wrapper。

## 2. 逐导出 C wrapper 架构

CLI 为每个 `#export_name("...")` 函数生成一个 MoonBit adapter 和独立的 N-API callback。调用时直接进入对应 adapter，不使用全局 dispatcher 或函数 ID。

2. **加载初始化**: 当 Node.js 加载编译好的 `.node` 扩展时，底层的 `stub.c` 会触发 `napi_register_module_v1`。该函数会调用 MoonBit 的初始化区块 `moonbit_napi_init()`。
3. **函数挂载**: 模块初始化时，生成的 C glue 为每个导出创建独立的 N-API callback，并把同名属性挂载到 exports。

```mermaid
sequenceDiagram
```

## 3. 双重 GC 灾难与内存安全

MoonBit 和 V8 分别拥有完全独立的垃圾收集器 (Garbage Collectors)。在这两者之间随意传递内存非常危险。

- `Int`, `Double`, `Bool` 属于基础数据类型，直接通过寄存器传递，GC 风险为零。
- `String` 涉及到内存申请，Node-API 会自动帮你将 V8 字符串提取成 MoonBit 独立管理的 String 对象。
- `Bytes` 使用了 `napi_create_buffer_copy`。数据被完全克隆进了 MoonBit 的 GC 堆内，由于两边拥有各自独立的内存副本，因此安全性达到 100%。
- `NapiBufferView` 极其危险。我们在此处刺穿了 GC 边界，直接抽取出 V8 数组的底层物理内存地址指针 (`napi_get_buffer_info`)。需要极其注意的是：V8 的“移动式垃圾回收机制 (Moving GC)”可能在任何非同步周期内把内存搬家，导致指针变成野指针。所以，`NapiBufferView` 在结构上被严格限制在同步的 Call Stack 中使用，杜绝持久化引用。

## 4. 参与 `napi-mbt` 的贡献

### 在本地进行测试
我们的测试用例无需执行任何外围发布。
你只需运行 `npm test`，内部的 `node --test scripts/test.js` 脚本便会接管一切，在本地快速验证 AST 抓取、编译、C 绑定与逻辑映射的全链路状态。

### 验证 Npm 分发逻辑
为了调试 `napi-mbt prepublish` 所输出的多平台分发架构，请运行：
```bash
node cli/bin/napi-mbt.js prepublish
```
该指令会在工作区根目录的 `npm/` 文件夹中输出对应架构的 `.json` 布局文件。确保你在根目录自动生成的 `index.js` 智能分发器能够正确适配。

### 如何添加对新数据类型 (如 Object/Array) 的支持
1. 在 `cli/src/generate.js` 中: 扩展 TypeScript AST 分析器，从而在 `index.d.ts` 中正确抛出新的类型签名。
2. 在 `cli/src/generate.js` 中: 扩展 `mbt` 胶水代码生成模板，编写该类型的装箱和拆箱拦截逻辑。
3. 在 `lib.mbt` 内: 调用底层的 Node-API（如 `napi_get_named_property` 等等），编写底层的内存提取和安全检验逻辑。

### 常见问题排查 (Troubleshooting)

构建由 MoonBit、CMake 和平台 C 编译器完成。检查 `napi-mbt.json` 的 builder/target 配置，并确认对应的 CMake、clang/GCC 或 MSVC 工具链已安装。
