# Class 与 callback

Class 和 callback 要求 N-API 3 起；新项目仍默认 N-API 4。运行时转换、
TypeScript 声明和 manifest 使用同一份类型 IR。

## 显式声明 class

使用普通、非泛型 MoonBit struct，在 `napi-mbt.json` 中列出每个公开成员。
对应的 MoonBit 函数可以是私有函数，未列出的成员不会自动暴露。

```json
{
  "classes": [{
    "name": "Counter",
    "type": "Counter",
    "constructor": "Counter::new",
    "methods": { "increment": "Counter::increment" },
    "staticMethods": { "twice": "Counter::twice" },
    "properties": {
      "value": { "get": "Counter::value", "set": "Counter::set_value" }
    }
  }]
}
```

构造函数返回配置的 struct；实例方法、getter/setter 的第一个参数是该 struct。
getter 不接受其他参数且返回值；setter 接受一个值并返回 Unit。
静态函数没有隐式 receiver，TypeScript 只声明配置中的成员。

class 实例可以用于参数、返回值及结构化值。工厂函数返回的对象满足对应
JavaScript class 的 `instanceof`，包装已有 MoonBit 值不会再次调用业务构造器。
TypeScript 使用私有字段区分不同原生 class，拒绝普通对象冒充实例。

每个实例都有幂等的 `dispose()`，之后访问报 `ERR_NAPI_DISPOSED`。
普通对象、伪造原型、其他 class 或其他 addon 的对象报带有
`ERR_NAPI_RECEIVER` 的 TypeError。读取 payload 前检查环境、类型和已登记句柄。
dispose 释放原生 payload，GC 回收包装容器；环境退出使用同一条释放路径。

## callback 参数和闭包返回值

```moonbit
#export_name("invoke")
pub fn invoke(callback : (Int) -> Int raise, value : Int) -> Int raise {
  callback(value)
}

#export_name("make_adder")
pub fn make_adder(delta : Int) -> ((Int) -> Int) {
  value => value + delta
}
```

JS callback 输入类型必须声明 `raise`，使转换失败和 JS 异常经 MoonBit 传播到
外层 adapter；已有 pending exception 保留原对象。返回 Unit 时忽略 JS 返回值。
callback 签名支持普通导出的拥有型数据，禁止 `NapiBufferView` 跨 callback 边界。

传入 callback 会转换为持有 JS 引用的 MoonBit 闭包，可以在本次调用结束后保存使用。
清除或替换保存的闭包会释放引用。底层运行时 `NapiCallback` 提供 `dispose()`；
跨环境或释放后的调用明确报错，不使用失效 N-API 句柄。

返回的 MoonBit 闭包是带 `dispose()` 的 JS 函数，重复释放安全；释放后调用报
`ERR_NAPI_DISPOSED`，GC 作为兜底。允许重入及执行中 dispose，正在执行的调用
会持有自己的 payload 引用，直到返回。

同一 addon 的 MoonBit 执行和引用计数使用可重入锁串行保护，JS 操作只在所属环境
线程执行。worker 关闭释放本环境资源，不重置其他环境的 MoonBit 状态。
加载同一 addon 的环境共享 MoonBit 全局变量，不得借此跨环境传递 JS callback。

真实原生用例和完整生成物快照位于 `scripts/class-test.mbtx`、
`scripts/callback-test.mbtx`；`scripts/lifecycle-test.mbtx` 验证并发 worker。
`moon run scripts/sanitizer-test.mbtx` 统一运行 parser 与原生 ASan 用例，
自动发现当前平台的 ASan 运行时。
