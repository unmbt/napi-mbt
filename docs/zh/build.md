# 构建与监听

`napi-mbt-cli doctor [directory] --json` 报告并探测原生工具链。
`build` 只在工具选择、可执行文件、SDK 和环境设置仍匹配时复用成功的预检查。
`doctor` 始终重新执行编译、链接检查。原生 CLI 不依赖 Node/npm。

```sh
napi-mbt-cli build . --release --verbose
napi-mbt-cli build . --watch --output-dir "native output"
napi-mbt-cli build . --release --no-cache
napi-mbt-cli clean . --cache
```

`--verbose` 输出实际可执行文件、参数、工作目录、编译器输出，以及工具链、生成、
准备、编译链接、产物安装各阶段耗时。普通构建输出最终路径，失败时始终保留编译器诊断。

`--output-dir` 支持绝对路径或相对工程目录的路径，产物位于
`<output-dir>/<target>/napi_mbt.node`。CJS 和 ESM loader 读取本地
`.napi-mbt/build-output.json`，因此自定义目录构建可以直接加载；该记录不进入发布包。
`generate --check` 只检查源码派生文件，不写入文件。

watch 先构建一次，合并 150 ms 内的变更，最多延迟一秒。构建串行执行，
编译期间的新变更安排下一次构建。排除生成文件、构建目录、node_modules 和所选产物目录，
监听原生依赖及头文件。package 的名称、版本变更触发重新生成，自动生成的入口字段不会造成循环。
`--watch --dry-run` 会报错。

生成和编译都在隔离工作区完成。只有成功构建才替换 addon、声明、loader 和生成元数据；
失败时上次成功的文件继续可用，修改源码后 watch 自动重试。
安装前检测构建输入是否被并发修改，避免覆盖上次成功的产物。Ctrl+C 停止监听。

`.napi-mbt/cache` 持久工作区按目标、模式、CLI、运行时/异步补丁、工具链/SDK 和配置
分区；源码摘要不参与分区，单个 MoonBit 文件变更可以继续复用依赖对象。
完整生成和补丁先在临时目录完成，再按最终内容同步进缓存，仅写入变化文件并删除
失效输入，保留其他文件的时间戳。头文件变化使原生对象失效，缓存元数据损坏时重建。
内核文件锁使跨进程 build 和 clean 互斥，进程退出时自动释放。

`--no-cache` 使用全新工作区和工具链探测。自定义构建 hook、未解析变量和外部
include/library 路径无法可靠追踪时自动回退，并说明原因。
`clean --cache` 只删除当前项目缓存，保留成功构件。

成功构建在 `.napi-mbt/receipt-<target>.json` 记录输入、工具链及输出摘要。
用户 addon 的 `prepublish` 要求匹配的构建记录，拒绝过期源码、声明、loader、
二进制及当前宿主工具链；缺失记录时需重新构建。汇总不同宿主的平台产物时，需同时
收集对应记录，且都来自同一源码树。摘要用于检测过期和损坏，不是数字签名。

原工程的 module/package 配置、编译参数、stub、依赖和链接输入是构建依据。
补充配置仅应用于隔离副本，由 Moon 解析完整的原生依赖图。

POSIX 下，依赖包 stub 和 MoonBit runtime 对象都需要 PIC。隔离副本补充 PIC 参数，
并使用小型原生编译器 driver 为 runtime 对象补充参数：固定版本 Moon 不会将包内
flags 传递给这些对象。Driver 委托给 probe 已验证的编译器，保留所有参数。
显式编译器配置和 MOON_CC 参与工具链选择；原 manifests 与已安装工具链不变。

显式配置的编译器冲突和 `-fno-PIC` 会报错。Linux 隐藏运行时及依赖的内部符号，
并将内部符号引用绑定到 addon 自身，避免与 Node 的 simdutf 冲突；Node-API 注册入口
和用户在包配置中声明的导出保持可见。
