# 使用指南 (Usage Guide)

本文档是 `@unmbt/napi-mbt` 的完整使用指南，详细讲解如何安装 CLI 工具、初始化新项目、编写 MoonBit 逻辑代码、构建 Native 模块并在 Node.js / TypeScript 中调用。

---

## 目录

- [1. 环境依赖与安装](#1-环境依赖与安装)
  - [1.1 系统依赖要求](#11-系统依赖要求)
  - [1.2 安装 CLI 工具](#12-安装-cli-工具)
- [2. 快速起步：从 init 到运行](#2-快速起步从-init-到运行)
  - [2.1 初始化新项目 (`init`)](#21-初始化新项目-init)
  - [2.2 项目工程结构详解](#22-项目工程结构详解)
  - [2.3 一键构建 (`build`)](#23-一键构建-build)
  - [2.4 运行与测试](#24-运行与测试)
- [3. 编写 MoonBit 扩展代码](#3-编写-moonbit-扩展代码)
  - [3.1 代码组织规范](#31-代码组织规范)
  - [3.2 导出宏 `#export_name("...")`](#32-导出宏-export_name)
  - [3.3 支持的数据类型与映射表](#33-支持的数据类型与映射表)
  - [3.4 数据类型代码示例](#34-数据类型代码示例)
    - [数值与布尔计算 (Int / Double / Bool)](#数值与布尔计算-int--double--bool)
    - [字符串交互 (String)](#字符串交互-string)
    - [二进制数据拷贝 (Bytes)](#二进制数据拷贝-bytes)
    - [高性能零拷贝 Buffer (NapiBufferView)](#高性能零拷贝-buffer-napibufferview)
  - [3.5 错误处理与异常抛出 (raise -> JS Error)](#35-错误处理与异常抛出-raise---js-error)
  - [3.6 高级特性 (Promise, BigInt, Threadsafe Function)](#36-高级特性-promise-bigint-threadsafe-function)
- [4. CLI 核心命令指南](#4-cli-核心命令指南)
  - [`napi-mbt-cli init`](#napi-mbt-cli-init)
  - [`napi-mbt-cli generate`](#napi-mbt-cli-generate)
  - [`napi-mbt-cli build`](#napi-mbt-cli-build)
  - [`napi-mbt-cli prepublish`](#napi-mbt-cli-prepublish)
  - [`napi-mbt-cli targets`](#napi-mbt-cli-targets)
- [5. 在 Node.js & TypeScript 中调用](#5-在-nodejs--typescript-中调用)
  - [5.1 CommonJS (CJS)](#51-commonjs-cjs)
  - [5.2 ES Modules (ESM)](#52-es-modules-esm)
  - [5.3 TypeScript 类型支持](#53-typescript-类型支持)
- [6. 跨平台打包与 npm 发布](#6-跨平台打包与-npm-发布)
- [7. 项目配置详解 (`napi-mbt.json`)](#7-项目配置详解-napi-mbtjson)
- [8. 常见问题与排查 (Troubleshooting)](#8-常见问题与排查-troubleshooting)

---

## 1. 环境依赖与安装

### 1.1 系统依赖要求

在开始使用前，请确保系统已安装以下工具：

1. **MoonBit 工具链**：
   - 需确保 `moon` 命令位于系统 `PATH` 环境变量中。
   - 安装请参考 [MoonBit 官方文档](https://www.moonbitlang.com/)。
2. **C 编译器与 CMake**：
   - **CMake**: >= 3.20。
   - **Windows**: 必须安装带有“使用 C++ 的桌面开发”组件的 Microsoft Visual Studio（提供 MSVC、`vswhere` 及 `lib.exe`）。
   - **Linux**: GCC 或 Clang，以及 `make` 或 `ninja`。
   - **macOS**: Xcode Command Line Tools (`clang`)。
3. **Node.js**:
   - 运行环境需 Node.js 18 或更高版本。
   - *注：CLI 自身为静态编译的原生独立可执行文件，代码生成和构建过程不调用 Node.js。Node.js 仅用于运行、测试和消费生成的 `.node` 扩展。*

### 1.2 安装 CLI 工具

首选推荐通过 `moon install` 安装：

```bash
moon install unmbt/napi-mbt/cmd/napi-mbt-cli
```

也可以通过官方安装脚本一键安装到本地环境：

- **Unix (Linux / macOS)**：
  ```bash
  curl -fsSL https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.sh | bash
  ```
- **Windows (PowerShell)**：
  ```powershell
  irm https://raw.githubusercontent.com/unmbt/napi-mbt/master/scripts/install.ps1 | iex
  ```

验证安装是否成功：

```bash
napi-mbt-cli --help
```

---

## 2. 快速起步：从 init 到运行

### 2.1 初始化新项目 (`init`)

通过 `napi-mbt-cli init` 可以快速创建一个符合规范的 MoonBit Node-API 扩展项目：

```bash
napi-mbt-cli init my-addon
cd my-addon
```

若要在当前已有空目录中初始化，也可直接执行：

```bash
napi-mbt-cli init . --name my-addon
```

### 2.2 项目工程结构详解

初始化完成后，目录结构如下：

```text
my-addon/
├── .github/
│   └── workflows/
│       └── build.yml       # 预设的 GitHub Actions 多平台 CI 构建配置
├── test/
│   ├── smoke.cjs           # CommonJS 格式的冒烟测试脚本
│   └── smoke.mjs           # ES Module 格式的冒烟测试脚本
├── lib.mbt                 # 【核心】编写业务逻辑与导出的 MoonBit 源代码
├── moon.mod                # MoonBit 模块描述文件（native 目标）
├── moon.pkg                # MoonBit 包描述文件（配置 foreign_library、stub、编译选项）
├── napi-mbt.json           # napi-mbt 专属配置文件（目标平台、N-API 版本等）
├── package.json            # Node.js npm 项目配置
├── bump.config.json        # 版本自动化管理配置
├── stub.c                  # 底层 C 跳板入口代码
├── napi_types.mbt          # Node-API 不透明指针与基础类型定义
├── napi_bindings.mbt       # Node-API 底层 C FFI 接口映射
├── napi_features.mbt       # 高级功能辅助函数（Promise、BigInt 等）
├── napi_runtime.mbt        # 运行时类型转换桥梁（数值、字符串、Buffer 转换）
├── napi_exports.mbt        # 【自动生成】每个导出函数的 MoonBit 适配层
├── napi_glue.c             # 【自动生成】模块注册入口及 C 语言导出回调
├── napi_manifest.json      # 【自动生成】导出的元信息清单
├── index.d.ts              # 【自动生成】匹配原函数的 TypeScript 声明文件
├── index.cjs               # 【自动生成】动态匹配加载正确平台 .node 的 CJS 入口
├── index.mjs               # 【自动生成】ESM 导出入口
└── .gitignore              # 忽略编译缓存与构建产物
```

> [!IMPORTANT]
> **文件修改原则**：
> - 业务代码写在 `lib.mbt`（或你新建的 `.mbt` 文件中）。
> - `napi_exports.mbt`、`napi_glue.c`、`index.d.ts`、`index.cjs`、`index.mjs` 以及 `napi_manifest.json` 为**自动生成文件**，每次运行 `generate` 或 `build` 均会被覆盖，**切勿手动编辑**。

### 2.3 一键构建 (`build`)

在项目根目录下执行：

```bash
napi-mbt-cli build
```

或者编译经过极速优化的生产版本：

```bash
napi-mbt-cli build --release
```

**该命令会全自动完成以下步骤**：
1. **AST 静态扫描**：通过内置 Tree-sitter 分析当前项目中所有 `.mbt` 文件，抓取带有 `#export_name("...")` 标记的导出函数。
2. **代码生成**：自动生成 MoonBit 适配层 (`napi_exports.mbt`)、C 回调桥接层 (`napi_glue.c`)、TypeScript 类型定义 (`index.d.ts`) 和 JS 加载器。
3. **配置更新**：自动向 `moon.pkg` 中同步追加 native-stub 选项及导出符号。
4. **原生编译**：触发 `moon build --target native` 生成原生静态库。
5. **CMake 动态链接**：调用 C 编译器和系统链接器，产出最终的原生扩展二进制文件：
   - Windows: `artifacts/win32-x64-msvc/napi_mbt.node`
   - Linux: `artifacts/linux-x64-gnu/napi_mbt.node`
   - macOS: `artifacts/darwin-arm64/napi_mbt.node`

### 2.4 运行与测试

构建完成后，无需任何额外配置，即可运行项目自带的冒烟测试验证：

```bash
# 执行预置的测试脚本
node test/smoke.cjs
node test/smoke.mjs
```

或者直接通过 Node.js 运行单行脚本测试调用：

```bash
node -e "const addon = require('./index.cjs'); console.log('2 + 3 =', addon.mbt_add(2, 3));"
```

控制台将输出：
```text
2 + 3 = 5
```

---

## 3. 编写 MoonBit 扩展代码

### 3.1 代码组织规范

在 `init` 之后，如何添加自己的函数？

1. **单文件组织**：你可以直接编辑 `lib.mbt`，添加你的函数。
2. **多文件组织**：你可以在项目根目录下创建任意数量的 `.mbt` 文件（例如 `math.mbt`、`crypto.mbt`、`image.mbt`）。
   - 构建系统会自动遍历目录下所有 `.mbt` 源码。
   - 文件名以 `_test.mbt`、`_wbtest.mbt` 结尾的文件为测试文件，会被自动忽略。
   - 内部系统文件（如 `napi_bindings.mbt` 等）不会被二次扫描。
3. **代码块风格**：遵循 MoonBit 规范，顶级定义之间建议使用 `///|` 分隔。

### 3.2 导出宏 `#export_name("...")`

要将一个普通的 MoonBit 函数暴露给 JavaScript/Node.js 调用，只需在该函数上方添加 `#export_name("导出名称")` 标注。

```moonbit
///|
#export_name("add")
pub fn my_add(a : Int, b : Int) -> Int {
  a + b
}
```

- **参数导出名**：`#export_name("add")` 中的字符串 `"add"` 将成为：
  - Node.js 中调用该方法的名字：`addon.add(1, 2)`。
  - TypeScript 定义中的函数名：`export function add(a: number, b: number): number;`。
- **命名规范**：导出名必须是合法的 C 与 JavaScript 标识符（不能包含特殊符号或为两者的保留关键字）。
- **函数签名限制**：
  - 导出函数必须显式声明所有参数类型与返回类型。
  - 目前不支持直接导出带有泛型类型参数（Generic Parameters）或 `async fn` 的函数。如需导出通用逻辑，请编写具体的单态化包装函数。

### 3.3 支持的数据类型与映射表

为了保证跨语言调用时的极致性能与 GC 内存安全，`napi-mbt` 目前对边界数据类型实施静态强类型校验。支持的类型映射如下：

| MoonBit 语法类型 | JavaScript / TypeScript 类型 | 边界处理机制与说明 |
| :--- | :--- | :--- |
| `Int` | `number` | 32 位有符号整型，直接通过 CPU 寄存器无损传递。 |
| `Double` | `number` | 64 位双精度浮点数，直接传递，GC 零开销。 |
| `Bool` | `boolean` | 映射为 JavaScript 标准布尔值。 |
| `String` | `string` | 自动在 V8 的 UTF-8 内存流与 MoonBit 原生 String 之间安全转换。 |
| `Bytes` | `Buffer` | **完整内存拷贝**。在 Node.js Buffer 与 MoonBit 堆内独立分配的 Bytes 间双向深拷贝。安全性 100%，适合独立持有或返回全新二进制数据。 |
| `NapiBufferView` | `Buffer` | **零拷贝（Zero-Copy）裸指针**。直接操作 Node.js 内存堆，无任何拷贝开销。仅能作为参数使用。 |
| `Unit` | `void` | 表示无返回值。 |

### 3.4 数据类型代码示例

下面通过具体的实际代码展示每种类型的用法。你可以将以下代码直接写入 `lib.mbt`：

#### 数值与布尔计算 (Int / Double / Bool)

```moonbit
///| 整数加法
#export_name("calc_add")
pub fn calc_add(a : Int, b : Int) -> Int {
  a + b
}

///| 浮点数面积计算
#export_name("circle_area")
pub fn circle_area(radius : Double) -> Double {
  3.141592653589793 * radius * radius
}

///| 布尔逻辑取反
#export_name("invert_flag")
pub fn invert_flag(flag : Bool) -> Bool {
  !flag
}
```

#### 字符串交互 (String)

```moonbit
///| 字符串拼接与转换
#export_name("greet")
pub fn greet(name : String) -> String {
  "Hello, " + name + "! Welcome to MoonBit Native Addon."
}
```

#### 二进制数据拷贝 (Bytes)

当需要接收或返回一段独立的二进制字节序列时，使用 `Bytes`：

```moonbit
///| 接收 Buffer 并返回一个新的倒序 Buffer
#export_name("reverse_buffer")
pub fn reverse_buffer(data : Bytes) -> Bytes {
  let len = data.length()
  let arr = Array::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    arr[i] = data[len - 1 - i]
  }
  Bytes::from_array(arr)
}
```

在 JS 中调用：
```javascript
const buf = Buffer.from([1, 2, 3, 4, 5]);
const reversed = addon.reverse_buffer(buf);
console.log(reversed); // <Buffer 05 04 03 02 01>
```

#### 高性能零拷贝 Buffer (NapiBufferView)

在图像处理、加解密、压缩或大规模数据流处理中，如果 Buffer 达到数十或数百兆，`Bytes` 的内存拷贝会带来极大的 CPU 和 GC 负担。

`NapiBufferView` 允许你**直接读写 Node.js 分配在 V8 外的裸内存**：

```moonbit
///| 原地修改传入的 Buffer（将所有字节加 1）
#export_name("increment_buffer_inplace")
pub fn increment_buffer_inplace(view : NapiBufferView) -> Unit {
  let len = view.length()
  for i = 0; i < len; i = i + 1 {
    let current = view.load8(i)
    view.store8(i, (current + 1) & 0xFF)
  }
}
```

`NapiBufferView` 提供的方法：
- `view.length() -> Int`：获取 Buffer 的实际字节长度。
- `view.load8(offset : Int) -> Int`：读取指定偏移处的 1 个字节（范围 0..255）。
- `view.store8(offset : Int, val : Int) -> Unit`：向指定偏移处写入 1 个字节。

> [!WARNING]
> **NapiBufferView 内存安全守则**：
> 1. `NapiBufferView` 是一个**非托管视图引用**，其生命周期严格绑定在当前同步调用上下文中。
> 2. 生成的代码会在函数执行结束退出前自动执行 `invalidate()`，使其立即失效。
> 3. **绝对不要将 `NapiBufferView` 实例保存到全局变量、全局缓存或异步逃逸结构中**，否则后续访问将导致主动终止或野指针崩溃。

### 3.5 错误处理与异常抛出 (raise -> JS Error)

在 MoonBit 中，你可以使用标准的错误抛出机制。生成器会自动识别标注有 `raise` 或 `!` 的函数，并在遇到异常时将其无缝转换为 JavaScript 的异常。

```moonbit
///|
suberror MathError {
  DivisionByZero
} derive(Show)

///| 当除数为 0 时抛出异常
#export_name("safe_divide")
pub fn safe_divide(a : Int, b : Int) -> Int!MathError {
  if b == 0 {
    raise MathError::DivisionByZero
  }
  a / b
}
```

当 JavaScript 调用 `addon.safe_divide(10, 0)` 时：
1. MoonBit 逻辑触发 `raise`；
2. 自动生成的胶水代码捕获该错误，并调用底层 `napi_throw_error`；
3. JavaScript 端抛出一个合法的 `Error: MathError::DivisionByZero`，你可以通过常规的 `try { ... } catch (err)` 捕获：

```javascript
try {
  addon.safe_divide(10, 0);
} catch (err) {
  console.error("捕获到来自 MoonBit 的异常:", err.message);
}
```

此外，如果 JavaScript 传入的参数类型不匹配（例如期望 `Int` 却传入了字符串），底层的 C 校验层会直接拦截并抛出 JavaScript 标准 `TypeError`，不会导致进程 Segfault 崩溃。

### 3.6 高级特性 (Promise, BigInt, Threadsafe Function)

初始化的模板中包含了 `napi_features.mbt`，提供了更高维度的能力封装：

- **Promise**：通过 `napi_promise_new(env)` 创建，配合 `napi_promise_resolve` 和 `napi_promise_reject` 完成异步通知。
- **BigInt**：通过 `napi_bigint_from_int64` / `napi_bigint_to_int64` 等处理 64 位大整数（需在 `napi-mbt.json` 中配置 `"napiVersion": 6`）。
- **线程安全函数 (Threadsafe Function)**：允许在非 Node.js 主线程安全回调主事件循环（需 `"napiVersion": 4`）。

---

## 4. CLI 核心命令指南

`napi-mbt-cli` 提供了完整的工程生命周期命令：

### `napi-mbt-cli init`

创建标准的 Node-API 项目模板：

```bash
# 在指定目录初始化
napi-mbt-cli init my-project

# 指定自定义包名
napi-mbt-cli init my-project --name "@my-scope/my-project"

# 强制覆盖已有文件
napi-mbt-cli init . --force
```

### `napi-mbt-cli generate`

只执行 AST 分析和胶水代码生成，不启动底层编译器。通常用于查看代码变化或在 CI 中做一致性校验：

```bash
# 生成胶水文件 (napi_exports.mbt, napi_glue.c, index.d.ts 等)
napi-mbt-cli generate

# CI 检查模式：若生成代码与当前文件不一致则退出报错
napi-mbt-cli generate --check
```

### `napi-mbt-cli build`

完整的全自动化构建流程（生成代码 -> 编译 MoonBit Native -> C/CMake 链接 -> 输出 `.node` 二进制）：

```bash
# Debug 模式构建（默认）
napi-mbt-cli build

# Release 极速优化模式（发布生产环境必备）
napi-mbt-cli build --release

# 演练模式（仅打印构建计划与底层命令，不实际执行）
napi-mbt-cli build --dry-run
```

### `napi-mbt-cli prepublish`

为发布到 npm 准备多架构分发包结构。

```bash
napi-mbt-cli prepublish
```

执行后将在 `npm/` 目录下生成各平台子包（如 `npm/win32-x64-msvc/package.json` 等），并自动配置根目录 `package.json` 中的 `optionalDependencies`。

### `napi-mbt-cli targets`

输出当前支持的目标平台列表：

```bash
napi-mbt-cli targets
# 输出：
# win32-x64-msvc
# darwin-x64
# darwin-arm64
# linux-x64-gnu
# linux-arm64-gnu
```

---

## 5. 在 Node.js & TypeScript 中调用

构建成功后，`napi-mbt` 已经为你自动生成了完善的模块加载入口与 TypeScript 类型声明。

### 5.1 CommonJS (CJS)

在 Node.js 中通过 `require` 引用：

```javascript
// index.cjs 会根据当前操作系统的平台与架构，自动定位并加载对应的 .node 二进制
const addon = require('./index.cjs');

console.log(addon.calc_add(10, 20)); // 30
console.log(addon.greet('World'));    // Hello, World! Welcome to MoonBit Native Addon.
```

### 5.2 ES Modules (ESM)

在现代 ESM 项目中直接通过 `import` 引用（支持命名导出和默认导出）：

```javascript
import addon, { calc_add, greet } from './index.mjs';

console.log(calc_add(100, 200));
console.log(greet('Developer'));
console.log(addon.calc_add === calc_add); // true
```

### 5.3 TypeScript 类型支持

每次构建时，`index.d.ts` 均会被自动同步更新。例如上述代码对应的 `index.d.ts` 如下：

```typescript
// Auto-generated by napi-mbt. DO NOT EDIT.

export function calc_add(a: number, b: number): number;
export function circle_area(radius: number): number;
export function invert_flag(flag: boolean): boolean;
export function greet(name: string): string;
export function reverse_buffer(data: Buffer): Buffer;
export function increment_buffer_inplace(view: Buffer): void;
export function safe_divide(a: number, b: number): number;
```

在 TypeScript 项目中引入时，将享有 100% 精确的参数类型提示、自动补全与编译期类型检查。

---

## 6. 跨平台打包与 npm 发布

`napi-mbt` 采用与主流原生扩展（如 esbuild、swc、@swc/core、napi-rs）完全一致的 **Optional Dependencies** 模式实现无感跨平台分发。

### 分发原理

1. 根包本身不包含体积庞大的二进制，仅包含 `index.cjs`、`index.mjs`、`index.d.ts` 以及指向各个平台包的 `optionalDependencies`。
2. 每个目标平台拥有一个独立的 npm 包（例如 `@my-scope/my-addon-win32-x64-msvc`），只包含该平台专属的 `napi_mbt.node` 二进制。
3. 用户在 `npm install` 你的根包时，npm 会根据用户机器的当前架构，仅下载匹配的子平台包。
4. `index.cjs` 在运行时会自动先尝试 `require("@my-scope/my-addon-" + target)`，找不到时回退加载本地 `artifacts/` 目录。

### 发布流程步骤

1. 在 GitHub Actions 或各自机器上完成各平台的构建：
   ```bash
   napi-mbt-cli build --release
   ```
2. 生成发布包配置：
   ```bash
   napi-mbt-cli prepublish
   ```
3. 检查 npm 包结构无误后发包：
   ```bash
   # 发布各子平台二进制包，最后发布根包
   npm run publish:all
   ```

---

## 7. 项目配置详解 (`napi-mbt.json`)

根目录下的 `napi-mbt.json` 用于控制代码生成与编译行为：

```json
{
  "napiVersion": 1,
  "generator": "auto",
  "builder": "auto",
  "targets": [
    "win32-x64-msvc",
    "darwin-arm64",
    "linux-x64-gnu"
  ],
  "features": [],
  "cjs": true,
  "esm": true
}
```

- **`napiVersion`** *(number, 默认 `1`)*: 指定项目依赖的最低 Node-API 版本。
  - v1 支持绝大部分基础功能与 Promise；
  - 若使用线程安全函数，需设为 `>= 4`；
  - 若使用 BigInt，需设为 `>= 6`。
- **`generator`** *(string, 默认 `"auto"`)*: 代码生成器类型。可选 `"auto"` 或 `"moonbit"`。
- **`builder`** *(string, 默认 `"auto"`)*: 编译器驱动。可选 `"auto"`、`"cmake"`、`"clang"`、`"gcc"`、`"msvc"`。
- **`targets`** *(array)*: 支持编译的目标平台矩阵列表。
- **`features`** *(array)*: 特性标签（例如 `["bigint", "promise"]`）。
- **`cjs` / `esm`** *(boolean)*: 是否生成 CommonJS 和 ES Module 加载代码。

---

## 8. 常见问题与排查 (Troubleshooting)

### Q1: Windows 构建报错 `MSVC lib.exe is required` 或找不到 Visual Studio
- **原因**：构建需要 MSVC 提供的静态库工具 (`lib.exe`) 和 CMake。
- **解决**：打开 Visual Studio Installer，确保已勾选“使用 C++ 的桌面开发”工作负载。如果在命令行中执行，请确保可以通过 `vswhere.exe` 探测到安装路径。

### Q2: 提示 `Target ... is not listed in napi-mbt.json`
- **原因**：当前主机的平台架构不在 `napi-mbt.json` 的 `targets` 列表中。
- **解决**：运行 `napi-mbt-cli targets` 查看系统架构名，将其补充进 `napi-mbt.json` 的 `"targets"` 字段中。

### Q3: 修改了 MoonBit 函数签名，但生成的 TypeScript 或导出未更新？
- **解决**：只需重新执行一次 `napi-mbt-cli build`（或单独执行 `napi-mbt-cli generate`），工具会自动重新扫描 AST 并刷新所有胶水代码和类型定义。

### Q4: 能否在导出函数中使用复杂的 MoonBit 自定义 Struct 或 Enum？
- **说明**：当前版本的自动生成器优先保证跨语言 GC 边界的安全，因此直接导出的函数签名仅支持基础标量类型、`String`、`Bytes` 和 `NapiBufferView`。
- **建议**：如需传递复杂对象，推荐先在 JS 端将对象序列化为 JSON 字符串或二进制 Buffer 传入 MoonBit，或在 MoonBit 中使用 `@json` 库进行解析。
