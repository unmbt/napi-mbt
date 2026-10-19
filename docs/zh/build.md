# 构建与监听

`napi-mbt-cli doctor [directory] --json` 报告并探测原生工具链。
`build` 在生成文件前运行相同的编译、链接预检查。原生 CLI 不依赖 Node/npm。

```sh
napi-mbt-cli build . --release --verbose
napi-mbt-cli build . --watch --output-dir "native output"
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
安装前检测 package.json 是否被并发修改，避免覆盖用户的新内容。Ctrl+C 停止监听。

原工程的 module/package 配置、编译参数、stub、依赖和链接输入是构建依据。
补充配置仅应用于隔离副本，由 Moon 解析完整的原生依赖图。
