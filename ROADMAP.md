### 🗺️ `napi-mbt` 开发路径规划 (分为四个阶段)

#### Phase 1: 拓荒期 —— 徒手打通 C ABI 链路 (PoC)

**目标：不借助任何自动化工具，全盘手写，证明 MoonBit Native 可以与 Node.js 完美通信。**

1. **映射核心基础类型：** 在 MoonBit 中定义 N-API 的不透明指针类型。

    ```moonbit
    // napi_types.mbt
    pub type NapiEnv Int // 或者用更安全的原生指针表示
    pub type NapiValue Int
    pub type NapiCallbackInfo Int
    ```

2. **绑定基础 N-API 函数：** 使用 `extern "C"` 导入 `node_api.h` 中的基础函数。你需要先挑最简单的导入，比如获取参数、创建数值、抛出错误。
3. **手写模块入口：** 手写一个 `napi_register_module_v1`，使用 `napi_define_properties` 把一个写死的 C 包装函数挂载到 `exports` 上。
4. **跑通构建流程：** 使用 `moon build --target native` 生成动态链接库，手动将后缀改为 `.node`，在 Node.js 中 `require` 运行成功。

#### Phase 2: 核心攻坚期 —— 跨语言类型系统与内存管理

**目标：解决所有复杂类型的转换，并彻底解决内存泄漏问题。**

1. **基础类型映射 (Primitives)：** 实现 `MoonBit Int/Double/Bool` 与 JS `Number/Boolean` 的双向转换。
2. **字符串与编码 (Strings)：** Node.js 字符串内部是 UTF-16/WTF-8，N-API 提供了 `napi_get_value_string_utf8`。你需要实现从 N-API 提取 UTF-8 字节流并无损转换为 MoonBit 的 `String` 类型。
3. **双重 GC 处理 (Dual GC & Objects)：**
    * 实现我们之前讨论的**全局句柄表 (Global Handle Registry)**。
    * 封装 `napi_wrap` 和 `napi_add_finalizer`，确保当 Node.js 侧对象被垃圾回收时，自动调用 C 回调清理 MoonBit 的全局句柄表。
4. **Buffer 零拷贝机制：** 实现 N-API 的 `napi_create_external_buffer`。让 MoonBit 直接操作 Node.js 传递过来的内存指针，这是图像处理、密码学等高性能场景的核心！

#### Phase 3: 体验飞跃期 —— 打造预处理器 (伪宏系统)

**目标：屏蔽底层的 N-API 恶心逻辑，让用户用纯正的 MoonBit 写业务代码。**

1. **设计你的伪宏语法：** 约定一套注释语法（或参考社区的 MoonMacro），例如 `// @napi` 或 `#[napi]`。
2. **开发代码生成器 (CLI 核心)：**
    * 写一个解析器（用 Rust, TS 或 MoonBit 自己写都可以），扫描用户的 `.mbt` 源码。
    * 遇到 `#[napi]` 标记的函数，自动分析它的参数类型和返回值。
    * **自动生成**同目录下的 `_napi_bindings.mbt`。里面包含了繁琐的 `napi_get_cb_info` 解析、类型检查和转换逻辑。
3. **自动生成 TypeScript 类型：** 既然你都解析了 MoonBit 源码的 AST，顺手根据函数签名自动生成一个 `.d.ts` 文件。这是 `napi-rs` 备受好评的杀手级功能。

#### Phase 4: 工程化与生态建设 —— 类似 `@napi-rs/cli`

**目标：提供一键构建、一键发布的工程化工具。**

1. **构建脚本封装：** 提供一个 `napi-mbt build` 命令，内部自动执行：源码预处理 -> 调用 `moon build` -> 拷贝/重命名产物为 `.node`。
2. **跨平台编译支持：** 借助 MoonBit 的交叉编译能力，支持打包出 `darwin-arm64`, `linux-x64`, `win32-x64` 等各个平台的 `.node` 文件。
3. **Npm 发布架构：** 参考 `napi-rs` 的 optional dependencies 模式，把不同平台的二进制包发布到 npm，并在安装时由 Node.js 自动下载对应架构的包。

---

### ⚠️ 需要特别注意的核心难点 (Gotchas)

在上述路径中，有几个坑你需要特别小心：

#### 1. 错误边界 (Error Handling Boundary)

* **问题：** 如果 MoonBit 内部发生了 `panic`（比如数组越界），而这个 `panic` 没有被捕获直接传回给了 Node.js，整个 Node.js 进程会直接崩溃退出（Segfault/Abort）。
* **应对：** 你的 FFI 包装层必须极其强壮。你需要查阅 MoonBit Native 的最新规范，看看如何捕获异常。如果无法捕获，必须在预处理器生成的代码中做严格的参数校验；如果业务代码出错，必须包装成 `Result` 类型，并在 C 层面上调用 `napi_throw_error` 抛出 JS 异常，而不是直接让程序死掉。

#### 2. N-API 状态码检查 (napi_status)

* **问题：** 每一个 N-API 调用都会返回一个 `napi_status`。很多新手写 C 扩展时忽略检查这个状态码，导致后续解引用空指针。
* **应对：** 在你生成的胶水代码里，必须像 Rust 那样，每次 N-API 调用后都强制检查状态码，如果非 `napi_ok`，立刻提前 return 并抛出 JS 异常。

#### 3. MoonBit Native 后端的成熟度

* **问题：** 截至 2026 年，MoonBit 的 Native 后端虽然发展迅速，但其 GC 机制和 ABI 稳定性可能随时在迭代。如果你传给 C 的指针后来被 MoonBit 的 GC 移动了位置（Moving GC），就会导致灾难。
* **应对：** 高度依赖 **全局句柄表**。坚决不把裸指针传给 V8，所有的复杂对象交互必须通过唯一的 `Int ID` 间接寻址，这是隔离底层 GC 差异的唯一防线。

#### 4. 异步与多线程 (Async & Threadsafe)

* **问题：** Node.js 的 V8 引擎是单线程的。你绝对**不能**在另一个后台线程中调用哪怕一个 N-API 函数。
* **应对：** 早期版本建议只做**同步（Sync）函数**的支持。等基础跑通后，如果 MoonBit 提供了多线程能力，你需要研究 N-API 的 `napi_threadsafe_function`。这是一个能在后台线程安全地把数据推回给主线程 JS 宏任务队列的高级特性。

#### 5. 闭包与回调函数 (Callbacks)

* **问题：** 如果用户想把一个 JS 函数传给 MoonBit，并且在 MoonBit 里调用它怎么办？
* **应对：** JS 函数在 MoonBit 里只能表示为一个 `NapiValue`。你需要在 MoonBit 侧封装一个方法，调用 N-API 的 `napi_call_function` 去执行这个 JS 函数。注意作用域和 `this` 指针的传递。

### 总结

开发 `napi-mbt` 实际上是在做一个**“翻译编译器”**和**“内存协调者”**。

* **脏活累活**交给“预处理器（Phase 3）”去解决。
* **安全问题**交给“双重 GC 句柄表（Phase 2）”去防范。

我建议你直接从 **Phase 1** 起手，花一个周末的时间，写一个纯手工的 `add(a, b)`，只要你在 Node.js 的终端里看到 `console.log(addon.add(1, 2))` 成功打印出 `3`，属于你的 `napi-mbt` 宇宙就正式大爆炸了！
