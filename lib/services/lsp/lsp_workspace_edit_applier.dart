import 'package:re_editor/re_editor.dart';
import 'lsp_protocol.dart';

/// 负责将 LSP 服务端返回的 WorkspaceEdit / TextEdit 序列安全、有序地应用到当前编辑器控制器中
class LspWorkspaceEditApplier {
  /// 将 [edit] 应用至 [controller]
  static void applyWorkspaceEdit(
    CodeLineEditingController controller,
    LspWorkspaceEdit edit, {
    required String currentFilePath,
  }) {
    final normalizedTarget = _normalize(currentFilePath);
    List<LspTextEdit>? targetEdits;

    for (final entry in edit.changes.entries) {
      final normalizedUri = _normalize(entry.key);
      if (normalizedTarget.endsWith(normalizedUri) ||
          normalizedUri.endsWith(normalizedTarget) ||
          normalizedTarget.toLowerCase() == normalizedUri.toLowerCase()) {
        targetEdits = entry.value;
        break;
      }
    }

    if (targetEdits == null || targetEdits.isEmpty) return;

    applyTextEdits(controller, targetEdits);
  }

  /// 依据 LSP 规范，对逆向排序后的编辑操作逐一应用，防止前序编辑破坏后续行列偏移
  static void applyTextEdits(
    CodeLineEditingController controller,
    List<LspTextEdit> edits,
  ) {
    if (edits.isEmpty) return;

    // 逆序排序：先按行号降序，同行按列号降序
    final sortedEdits = List<LspTextEdit>.from(edits)
      ..sort((a, b) {
        final lineComp = b.range.start.line.compareTo(a.range.start.line);
        if (lineComp != 0) return lineComp;
        return b.range.start.character.compareTo(a.range.start.character);
      });

    final totalLines = controller.lineCount;

    for (final te in sortedEdits) {
      final startLine = te.range.start.line.clamp(0, totalLines - 1);
      final endLine = te.range.end.line.clamp(0, totalLines - 1);

      final startLineLen = controller.codeLines[startLine].text.length;
      final endLineLen = controller.codeLines[endLine].text.length;

      final startCol = te.range.start.character.clamp(0, startLineLen);
      final endCol = te.range.end.character.clamp(0, endLineLen);

      final selection = CodeLineSelection(
        baseIndex: startLine,
        baseOffset: startCol,
        extentIndex: endLine,
        extentOffset: endCol,
      );

      controller.replaceSelection(te.newText, selection);
    }
  }

  static String _normalize(String input) {
    String path = input;
    if (path.startsWith('file://')) {
      final uri = Uri.tryParse(path);
      if (uri != null && uri.hasAbsolutePath) {
        path = uri.toFilePath();
      } else {
        path = path.substring(7);
      }
    }
    path = path.replaceAll('\\', '/');
    if (path.length >= 2 && path[1] == ':') {
      path = path[0].toLowerCase() + path.substring(1);
    }
    return path;
  }
}
