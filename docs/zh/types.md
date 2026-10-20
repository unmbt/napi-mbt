# 导出值类型

导出函数使用 `pub fn` 和 `#export_name("jsName")`。生成前解析整个包内的类型；
未解析类型、不支持的泛型导出会带源码文件和行号报错，不会默认映射成 Buffer。

| MoonBit | JavaScript | 规则 |
| --- | --- | --- |
| Int / Int32 | number | 有限、无小数、32 位有符号范围内 |
| UInt / UInt32 | number | [0, 4294967295] 内的整数，禁止截断和回绕 |
| Float | number | IEEE float32 舍入，保留 NaN、Infinity 和负零 |
| Double | number | IEEE 语义，包括 NaN 和无穷 |
| Int64 / UInt64 | bigint | 需要 N-API 6；越界抛 RangeError，code 为 `ERR_NAPI_BIGINT_RANGE` |
| String | string | 精确保留 UTF-16 code units，包括 NUL 和孤立 surrogate |
| Bytes | Buffer | 拥有数据副本；backing store 检查需要 N-API 7 |
| NapiBufferView | Buffer | 同步调用的直接借用参数，调用结束后失效 |
| Option[T] / T? | T 或 null | missing、undefined、null 输入均为 None；None 输出 null |
| Array[T] | Array | 递归转换；稀疏位置按 undefined 处理 |
| Map[String, T] | Record<string, T> | 自有可枚举字符串键；输出使用安全的数据属性 |
| Json | $NapiJson | 有限 JSON 值，不隐式转换或调用 toJSON |
| (T, U, ...) | [T, U, ...] | 固定数组长度，按位置递归转换 |
| 普通 struct | object | 必填自有字段必须存在；忽略额外字段 |
| 无载荷 enum | string | 精确匹配构造器名称 |
| 有载荷 enum | `{ tag, args }` | 名称和元组长度必须匹配；无参数变体也需要 `args: []` |
| Unit 返回值 | undefined | 不支持 Unit 参数及嵌套 Unit |

```moonbit
pub(all) struct Person {
  name : String
  age : Int?
}

pub(all) enum Event {
  Ready
  Message(String)
}

#export_name("echo_person")
pub fn echo_person(value : Person) -> Person { value }
```

`echo_person({ name: "Moon" })` 返回 `{ name: "Moon", age: null }`。
Event 对应 `{ tag: "Ready", args: [] }` 或
`{ tag: "Message", args: ["hello"] }`。带标签的载荷按声明顺序放入 args。

Option、Array 可以嵌套，也可以引用同包其他文件中的 struct/enum。
递归类型接受有限树；转换字段中的循环抛 `ERR_NAPI_CYCLE`，过深嵌套抛
`ERR_NAPI_DEPTH`。不同分支复用同一个对象是允许的。嵌套 Option 共用 null：
None 和 Some(None) 都输出 null。借用的 BufferView 不能嵌入值类型。

Map 和 tuple 可以与其他拥有型数据嵌套。Map 键精确保留 UTF-16，忽略继承属性、
不可枚举属性及 symbol 键；`__proto__` 输出为普通数据属性。Json 拒绝 undefined、
函数、symbol、bigint、非有限数及循环，也会检查嵌套值和稀疏数组。
getter 抛出的异常保留原身份，数值转换不接受字符串或包装对象。

只有连续的尾部 Option 参数生成 TypeScript 可选参数。
对于 `(a: Int?, b: Int, c: Int?)`，JS 必须传前两个参数。
输入 interface 带 `$Input` 后缀，允许缺少可选字段；输出 interface 的字段均存在，
None 对应 null。两种声明均由同一 IR 生成。

任一参数或 getter 转换失败都会在业务执行前结束调用；已有 JS 异常保持原始对象。
返回对象使用数据属性，包括名为 `__proto__` 的字段。

运行 `moon run scripts/structured-types-test.mbtx`，再运行
`moon run scripts/test-runtime.mbtx --structured`，验证原生行为和 TypeScript 消费者。
第一条命令还检查完整生成物快照。
运行 `moon run scripts/collections-test.mbtx` 验证 UInt/Float、Map、tuple、Json
边界行为及 NodeNext/Bundler 类型声明。
