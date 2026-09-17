# LSP 服务启用与全链路 Debug 打点排查手册

为了彻底排查后台 `clangd` 等语言服务器为何未启用、未响应或未触发补全，我们在整个 LSP 的**生命周期、配置匹配、进程拉起、通信协议与补全调度推流**各个核心节点注入了全套 `[LSP-DEBUG]` 追踪日志。

---

## 1. Debug 打点分布位置一览表

| 序号 | 链路阶段 | 文件路径 | 方法 / 代码行位置 | 关键调试内容 |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **编辑区生命周期** | [`lib/widgets/code_editor_widget.dart`](file:///d:/Flutter/Projects/code_editor/lib/widgets/code_editor_widget.dart) | `_loadFileContent`<br>`_onTextChanged` | 打印当前打开文件绝对路径、工程根目录、文件内容长度，及文件修改事件 |
| **2** | **协调器分发** | [`lib/widgets/editor/editor_lsp_coordinator.dart`](file:///d:/Flutter/Projects/code_editor/lib/widgets/editor/editor_lsp_coordinator.dart) | `onFileOpened`<br>`onFileChanged` | 打印协调器分发状态、查询是否存在存活会话、是否进入本地词法诊断兜底 |
| **3** | **配置匹配与进程拉起** | [`lib/services/lsp/lsp_manager.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/lsp/lsp_manager.dart) | `getOrCreateSession`<br>`_startSession`<br>`getExistingSession`<br>`onFileOpened` | 1. 打印扩展名与配置匹配结果<br>2. 打印 Ubuntu 引擎安装检测结果<br>3. 打印命令（clangd）安装检测结果<br>4. 打印拼装的 PRoot 容器完整命令行<br>5. 打印子进程 PID 或拉起异常<br>6. 打印 `session.initialize()` 握手结果 |
| **4** | **会话与协议层** | [`lib/services/lsp/lsp_session.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/lsp/lsp_session.dart) | `initialize`<br>`didOpen`<br>`didChange`<br>`getCompletions` | 1. 打印 `initialize` 请求入参与回包类型<br>2. 打印 `textDocument/didOpen` 映射的容器内部 guestUri<br>3. 打印 `textDocument/didChange` 防抖触发与版本号<br>4. 打印 `textDocument/completion` 耗时与回包条数 |
| **5** | **Stdio 底层通讯** | [`lib/services/lsp/lsp_client.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/lsp/lsp_client.dart) | `sendRequest`<br>`sendNotification`<br>`_dispatchMessage`<br>`_handleStderrData` | 1. 打印发往 clangd 的 Request/Notification 方法名与 ID<br>2. 打印收到的 Response 结果或 JSON-RPC 错误码<br>3. **打印 clangd 进程输出的所有 stderr 原始日志** |
| **6** | **补全提供者** | [`lib/services/code_completion/providers/lsp_completion_provider.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/code_completion/providers/lsp_completion_provider.dart) | `provideCompletions` | 打印收到的补全触发字符、光标行列号、当前 session 存活与初始化状态、后端返回的语义补全条数 |
| **7** | **补全调度流水线** | [`lib/services/code_completion/core/completion_engine.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/code_completion/core/completion_engine.dart) | `requestCompletions` | 打印当前激活的 Providers 列表、同步候选数、异步 Provider 调用耗时、聚合条数与向 UI 推流事件 |

---

## 2. 日志前缀说明与标准排查轨迹

所有调试日志均统一带有 `[LSP-DEBUG]` 前缀，方便通过关键字高亮或过滤：

```bash
# 在终端中仅查看 LSP 调试信息（Windows PowerShell）
flutter run | Select-String "\[LSP-DEBUG\]"

# 或在 Android 设备上使用 adb logcat 过滤
adb logcat | grep -E "\[LSP-DEBUG\]|flutter"
```

### 正常工作时的完整日志时序：
```text
[LSP-DEBUG][Editor] 磁盘冷加载读取文件成功，通知 LSP 打开: path=/sdcard/.../main.c, rootPath=/sdcard/...
[LSP-DEBUG][Coordinator] onFileOpened 被触发: filePath=/sdcard/.../main.c
[LSP-DEBUG][Manager] onFileOpened 被触发: filePath=/sdcard/.../main.c
[LSP-DEBUG][Manager] getOrCreateSession 触发: filePath=/sdcard/.../main.c, ext=.c
[LSP-DEBUG][Manager] 匹配配置结果: config=c_cpp, name=C / C++, enabled=true, serverCommand=clangd
[LSP-DEBUG][Manager] 开始创建并拉起新会话: configId=c_cpp
[LSP-DEBUG][Manager] 检查 Ubuntu 引擎安装状态: isEngineInstalled=true
[LSP-DEBUG][Manager] 检查命令安装状态 (clangd): isCommandInstalled=true
[LSP-DEBUG][Manager] 准备执行拉起命令: /data/user/0/.../libproot.so ... clangd --background-index
[LSP-DEBUG][Manager] 语言服务子进程已启动, PID: 12345
[LSP-DEBUG][Manager] 正在进行 session.initialize() 握手...
[LSP-DEBUG][Client] 发送 Request: id=1, method=initialize, timeout=10s
[LSP-DEBUG][Client] 收到 Request 响应: id=1, hasError=false
[LSP-DEBUG][Session] 语言服务初始化成功并发送 initialized 通知: C / C++ (clangd)
[LSP-DEBUG][Manager] session.initialize() 结果: success=true
[LSP-DEBUG][Manager] 会话拉起成功并缓存: configId=c_cpp
[LSP-DEBUG][Manager] onFileOpened 正在调用 session.didOpen
[LSP-DEBUG][Session] 发送 textDocument/didOpen: filePath=/sdcard/.../main.c -> uri=file:///...
[LSP-DEBUG][Client] 发送 Notification: method=textDocument/didOpen

# 当你在编辑器中键入字符（如 pri）时：
[LSP-DEBUG][Engine] requestCompletions 触发: input="pri", providers=[lsp(async=true)]
[LSP-DEBUG][Engine] 启动异步请求: requestId=1, asyncProviders=[lsp]
[LSP-DEBUG][Engine] 正在调用异步 Provider: lsp
[LSP-DEBUG][Provider] 收到 LSP 补全请求: input="pri", line=3, col=4
[LSP-DEBUG][Provider] 查询会话结果: session=true, isInitialized=true, isClosed=false
[LSP-DEBUG][Session] getCompletions: ... line=3, col=4
[LSP-DEBUG][Client] 发送 Request: id=2, method=textDocument/completion
[LSP-DEBUG][Client] 收到 Request 响应: id=2, hasError=false
[LSP-DEBUG][Session] 解析 CompletionList items 成功, 条数: 15
[LSP-DEBUG][Provider] session.getCompletions 耗时: 38ms, 返回条数: 15
[LSP-DEBUG][Engine] 聚合所有异步结果数: 15
[LSP-DEBUG][Engine] 合并后过滤展示条数: 15, 准备推流至 ValueNotifier
[LSP-DEBUG][Engine] ValueNotifier 推流成功！
```

---

## 3. 常见断点排查指南

| 现象 / 日志断点 | 发生点 | 真正原因与对策 |
| :--- | :--- | :--- |
| **`[Manager] 未找到匹配配置或配置已被禁用`** | `LspManager.getOrCreateSession` | 检查配置管理中该语言扩展名（如 `.c`）是否已配置并处于启用状态。 |
| **`[Manager] 阻断: Ubuntu 引擎未安装`** | `LspManager._startSession` | `InternalEngineService.isEngineInstalled()` 为 false。说明 App 尚未解压容器运行环境。 |
| **`[Manager] 阻断: 服务命令未在引擎中检测到: clangd`** | `LspManager._startSession` | `isCommandInstalled('clangd')` 判定失败。说明容器环境中 `command -v clangd` 未输出 CE_OK，需确认容器中 clangd 是否已配置在 PATH 路径下。 |
| **`[Manager] 语言服务子进程已启动, PID: xxx` 紧接着进程退出** | `LspClient 进程退出: xxx` | 关注 `[LSP-DEBUG][Stderr]` 打印的原始错误（如缺失共享库 `libc++.so`、权限被拒、参数不支持等）。 |
| **`[Client] Request 超时失败: method=initialize`** | `LspClient.sendRequest` | clangd 启动后挂起，未能在 10 秒内应答 initialize 请求。通常是 PRoot 路径映射或 stdin 管道堵塞。 |
| **`[Provider] 会话不存在或未完成初始化`** | `LspCompletionProvider.provideCompletions` | 说明输入时，前面的文件打开握手尚未完成，或拉起失败导致 session 为 null。 |
