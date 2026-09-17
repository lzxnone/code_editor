import 'package:re_editor/re_editor.dart';
import '../../services/lsp/lsp_diagnostics_store.dart';
import '../../services/lsp/lsp_manager.dart';

/// 编辑器 LSP 生命周期协调器
///
/// 负责：
/// 1. 统一管理文档打开、变更、关闭与 LSP 语言服务器进程的同步；
/// 2. 文档关闭时及时清理诊断缓存；
/// 3. 所有语法纠错与诊断均严格来自真实 LSP 进程的 push 通知，不进行任何本地模糊伪检查。
class EditorLspCoordinator {
  const EditorLspCoordinator();

  /// 文档打开时同步至 LSP
  void onFileOpened(
    String filePath,
    String content,
    CodeLines codeLines, {
    String? workspaceRoot,
  }) {
    LspManager.instance.onFileOpened(
      filePath,
      content,
      workspaceRoot: workspaceRoot,
    );
  }

  /// 文档文本内容变更时同步至 LSP 进程
  void onFileChanged(
    String filePath,
    String content,
    CodeLines codeLines,
  ) {
    final session = LspManager.instance.getExistingSession(filePath);
    if (session != null && session.isInitialized) {
      LspManager.instance.onFileChanged(filePath, content);
    }
  }

  /// 文档关闭时清理会话与诊断
  void onFileClosed(String filePath) {
    LspManager.instance.onFileClosed(filePath);
    LspDiagnosticsStore.instance.removeForFile(filePath);
  }
}
