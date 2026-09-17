import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'lsp_protocol.dart';

/// 全局代码错误诊断管理器（按文件 URI / 绝对路径存储报错区间与等级）
class LspDiagnosticsStore extends ChangeNotifier {
  static final LspDiagnosticsStore instance = LspDiagnosticsStore._();
  LspDiagnosticsStore._();

  /// filePath -> `List<LspDiagnostic>`
  final Map<String, List<LspDiagnostic>> _diagnosticsByFile = {};

  /// 更新某个文件的诊断列表
  void updateDiagnostics(String uriOrPath, List<LspDiagnostic> diagnostics) {
    final normalized = _normalizePath(uriOrPath);
    if (diagnostics.isEmpty) {
      _diagnosticsByFile.remove(normalized);
    } else {
      // 按错误起始行号和字符列号升序排序
      final sorted = List<LspDiagnostic>.from(diagnostics)
        ..sort((a, b) {
          final lineComp = a.range.start.line.compareTo(b.range.start.line);
          if (lineComp != 0) return lineComp;
          return a.range.start.character.compareTo(b.range.start.character);
        });
      _diagnosticsByFile[normalized] = sorted;
    }
    notifyListeners();
  }

  /// 获取指定文件的全部诊断
  List<LspDiagnostic> getDiagnosticsForFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) return const [];
    return _diagnosticsByFile[_normalizePath(filePath)] ?? const [];
  }

  /// 获取指定文件在第 [line] 行（0-indexed）上的所有诊断
  List<LspDiagnostic> getDiagnosticsForLine(String? filePath, int line) {
    if (filePath == null || filePath.isEmpty) return const [];
    final all = _diagnosticsByFile[_normalizePath(filePath)];
    if (all == null || all.isEmpty) return const [];
    return all.where((d) => d.range.overlapsLine(line)).toList();
  }

  /// 获取指定文件在第 [line] 行、第 [character] 列上的精确诊断项
  LspDiagnostic? getDiagnosticAt(String? filePath, int line, int character) {
    final list = getDiagnosticsForLine(filePath, line);
    for (final d in list) {
      if (d.range.contains(line, character)) {
        return d;
      }
    }
    // 若光标在该行但未精确在区间内，返回该行的第一个报错
    return list.isNotEmpty ? list.first : null;
  }

  /// 清空所有诊断
  void clear() {
    _diagnosticsByFile.clear();
    notifyListeners();
  }

  /// 移除指定文件的诊断
  void removeForFile(String? filePath) {
    if (filePath == null) return;
    if (_diagnosticsByFile.remove(_normalizePath(filePath)) != null) {
      notifyListeners();
    }
  }

  String _normalizePath(String input) {
    String path = input;
    if (path.startsWith('file://')) {
      final uri = Uri.tryParse(path);
      if (uri != null && uri.hasAbsolutePath) {
        path = uri.toFilePath();
      } else {
        path = path.substring(7);
      }
    }
    path = p.normalize(path).replaceAll('\\', '/');
    if (path.length >= 2 && path[1] == ':') {
      path = path[0].toLowerCase() + path.substring(1);
    }
    return path;
  }
}
