# 使用指南 (Usage Guide)

本文档提供有关如何引入及使用 `@unmbt/napi-mbt-cli` 工具，来辅助你通过 MoonBit 快速开发 Node.js 原生 C++ 扩展 (Addons) 的详细教程。

## 1. 环境依赖要求

在开始之前，请确保你的机器环境满足以下依赖条件：

- **Node.js**: 最低版本 18。
- **MoonBit 工具链**: 确保 `moon` 命令位于系统环境变量中。你可前往 [MoonBit 官网](https://www.moonbitlang.com/) 获取。
- **C 编译器**: CLI 需要利用 C 编译器去连接底层生成的 C 跳板代码 (`stub.c`)。
  - **Windows**: 必须安装带有“C++ 桌面开发”组件的 Microsoft Visual Studio (用于获取 MSBuild 及 lib.exe)。
  - **macOS / Linux**: GCC 或 Clang。

## 2. CLI 核心命令

`@unmbt/napi-mbt-cli` 提供了主入口命令 `napi-mbt`。

### `napi-mbt build [--release]`
一键全自动打包流程。它内部依次执行以下事务：
1. 调用 AST 语法分析器扫描当前项目中的所有 `.mbt` 文件，抓取被 `/// @napi` 标记修饰的导出函数。
2. 自动生成处理参数解析、内存安全校验与数据结构映射转换的胶水代码 (`_napi_bindings.mbt`)。
3. 自动生成 100% 精确匹配原函数的 TypeScript 声明文件 (`index.d.ts`)。
4. 调用 `moon build --target native` 进行静态编译。
5. 通过 C 编译器桥接 V8 与 MoonBit 的 Native 构件。
6. 输出结果 `.node` 到标准化的 `artifacts/[platform]-[arch]/napi_mbt.node` 路径中。

**可选参数:** 追加 `--release` 可使用 Release 模式构建极速优化的版本。

### `napi-mbt prepublish`
处理跨平台 Npm 发布的包结构构建。
它会读取项目的 `package.json`，并根据配置生成利用 `optionalDependencies` 模式分发的子包体系（放置于 `npm/` 目录下，如 `npm/win32-x64/package.json`）。
同时在根目录下自动创建智能加载入口 `index.js`，保证使用者在 `require` 时，能够自动根据宿主的真实操作系统，实时加载正确架构的 `.node` 二进制产物。

## 3. 伪宏 `/// @napi` 与类型支持

为了将某个普通的 MoonBit 业务函数暴露给 JS 使用，你只需要给它添加一个 `/// @napi` 的注释段即可。目前，为了避免跨语言 GC 灾难，转换器执行非常严格的类型限制，只有安全的数据类型才会被接纳。

### 当前稳定支持的类型映射表：

| MoonBit 语法     | TypeScript 类型        | 内部行为说明 |
| ---------------- | ---------------------- | ------------------- |
| `Int`            | `number`               | 无损双向映射 32位整型。 |
| `Double`         | `number`               | 无损双向映射 64位浮点。 |
| `Bool`           | `boolean`              | JavaScript 的基础布尔值。 |
| `String`         | `string`               | 将 V8 引擎内的 UTF-8 底层字节流直接无损转码进 MoonBit 的原生字符串内存。 |
| `Bytes`          | `Buffer`               | 二进制字节数组，在 JS 与 N-API 的边界发生**完整的数据拷贝（Copy）**。极端安全，但大量数据操作时可能触发 GC 压力。 |
| `NapiBufferView` | `Buffer`               | 表示一段对 Node.js 原始 Buffer 内存堆的**零拷贝（Zero-Copy）裸指针**。极度适合对二进制内容做性能敏感的原位修改。 |
| `Unit`           | `void`                 | 无返回值场景。 |

### 复杂类型说明 (Roadmap)
当前的 Phase 4 暂不支持对象（Object）、数组（Array）以及 Promise。这是因为我们还在设计安全的、抵御 V8 GC 移动 (Moving GC) 的统一句柄转换算法，该能力将在后续迭代 (Phase 5) 提供原生支持。

## 4. 健壮的错误阻断机制

如果 JS 调用方传入了类型不符的参数，系统不会像常规 C 代码一样导致进程崩溃 (Segfault)。
自动生成的转换代码含有前置防御边界：假设你需要一个 `Int` 却接收到了 `"hello"` 字符串，代码会立刻执行失败，调用 `napi_throw_error()` 直接中止当前方法调用，并优雅地抛出一个合法的 JavaScript `TypeError`。

## 5. NapiBufferView 高级用法（零拷贝特性）

如果你的扩展业务涉及到如图像矩阵运算、加解密算法或流式处理等性能瓶颈场景，将所有数据深度 Copy 成 MoonBit 的 `Bytes` 会产生不可忍受的延时。

`NapiBufferView` 允许你彻底屏蔽这层拷贝开销！它将一段未经处理的裸内存交予你读写。
请注意：由于此段内存被 Node.js V8 的垃圾回收器监控，**绝对不能**在方法执行结束后，依然将 `NapiBufferView` 保留或缓存到全局静态变量中（一旦被 JS 回收即变成悬空指针）。

使用范例:
```moonbit
/// @napi
pub fn mutate_image_colors(view : NapiBufferView) -> Unit {
  let length = view.length()
  for i = 0; i < length; i = i + 1 {
    let pixel = view.load8(i)
    // 直接原位将像素值减 10 
    view.store8(i, if pixel > 10 { pixel - 10 } else { 0 })
  }
}
```
