/// LSP (Language Server Protocol) 核心协议数据模型
class LspPosition {
  final int line;
  final int character;

  const LspPosition({required this.line, required this.character});
  const LspPosition.pos(this.line, this.character);

  factory LspPosition.fromJson(Map<String, dynamic> json) {
    return LspPosition(
      line: json['line'] as int? ?? 0,
      character: json['character'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'line': line,
        'character': character,
      };

  @override
  String toString() => '$line:$character';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LspPosition && line == other.line && character == other.character;

  @override
  int get hashCode => Object.hash(line, character);
}

class LspRange {
  final LspPosition start;
  final LspPosition end;

  const LspRange({required this.start, required this.end});

  factory LspRange.fromJson(Map<String, dynamic> json) {
    return LspRange(
      start: LspPosition.fromJson(json['start'] as Map<String, dynamic>? ?? const {}),
      end: LspPosition.fromJson(json['end'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toJson(),
        'end': end.toJson(),
      };

  /// 检查给定行列号是否处于当前区间内部（闭区间）
  bool contains(int l, int c) {
    if (l < start.line || l > end.line) return false;
    if (l == start.line && c < start.character) return false;
    if (l == end.line && c > end.character) return false;
    return true;
  }

  /// 检查区间是否与某一行有交集
  bool overlapsLine(int l) {
    return l >= start.line && l <= end.line;
  }

  @override
  String toString() => '$start-$end';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LspRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// 诊断等级常量定义（对齐 LSP 规范）
abstract class LspDiagnosticSeverity {
  static const int error = 1;
  static const int warning = 2;
  static const int information = 3;
  static const int hint = 4;
}

/// 编译器诊断错误与告警
class LspDiagnostic {
  final LspRange range;
  final int severity; // 1: Error, 2: Warning, 3: Information, 4: Hint
  final dynamic code;
  final String? source;
  final String message;
  final dynamic data;

  const LspDiagnostic({
    required this.range,
    this.severity = 1,
    this.code,
    this.source,
    required this.message,
    this.data,
  });

  bool get isError => severity == 1;
  bool get isWarning => severity == 2;

  factory LspDiagnostic.fromJson(Map<String, dynamic> json) {
    return LspDiagnostic(
      range: LspRange.fromJson(json['range'] as Map<String, dynamic>? ?? const {}),
      severity: json['severity'] as int? ?? 1,
      code: json['code'],
      source: json['source'] as String?,
      message: json['message'] as String? ?? '',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'severity': severity,
        if (code != null) 'code': code,
        if (source != null) 'source': source,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// 语义补全项
class LspCompletionItem {
  final String label;
  final int? kind;
  final String? detail;
  final String? documentation;
  final String? sortText;
  final String? filterText;
  final String? insertText;
  final int? insertTextFormat; // 1: PlainText, 2: Snippet
  final dynamic textEdit;

  const LspCompletionItem({
    required this.label,
    this.kind,
    this.detail,
    this.documentation,
    this.sortText,
    this.filterText,
    this.insertText,
    this.insertTextFormat,
    this.textEdit,
  });

  factory LspCompletionItem.fromJson(Map<String, dynamic> json) {
    String? doc;
    final rawDoc = json['documentation'];
    if (rawDoc is String) {
      doc = rawDoc;
    } else if (rawDoc is Map && rawDoc['value'] is String) {
      doc = rawDoc['value'] as String;
    }

    return LspCompletionItem(
      label: json['label'] as String? ?? '',
      kind: json['kind'] as int?,
      detail: json['detail'] as String?,
      documentation: doc,
      sortText: json['sortText'] as String?,
      filterText: json['filterText'] as String?,
      insertText: json['insertText'] as String?,
      insertTextFormat: json['insertTextFormat'] as int?,
      textEdit: json['textEdit'],
    );
  }

  /// 补全文本内容
  String get effectiveInsertText {
    if (textEdit is Map && textEdit['newText'] is String) {
      return textEdit['newText'] as String;
    }
    return insertText ?? label;
  }
}

/// 快速修复与代码动作
class LspCodeAction {
  final String title;
  final String? kind;
  final List<LspDiagnostic> diagnostics;
  final bool isPreferred;
  final LspWorkspaceEdit? edit;

  const LspCodeAction({
    required this.title,
    this.kind,
    this.diagnostics = const [],
    this.isPreferred = false,
    this.edit,
  });

  factory LspCodeAction.fromJson(Map<String, dynamic> json) {
    final diagsRaw = json['diagnostics'] as List? ?? const [];
    final diags = diagsRaw
        .whereType<Map<String, dynamic>>()
        .map((d) => LspDiagnostic.fromJson(d))
        .toList();

    LspWorkspaceEdit? wsEdit;
    if (json['edit'] is Map) {
      wsEdit = LspWorkspaceEdit.fromJson(json['edit'] as Map<String, dynamic>);
    }

    return LspCodeAction(
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String?,
      diagnostics: diags,
      isPreferred: json['isPreferred'] as bool? ?? false,
      edit: wsEdit,
    );
  }
}

class LspWorkspaceEdit {
  final Map<String, List<LspTextEdit>> changes;

  const LspWorkspaceEdit({this.changes = const {}});

  factory LspWorkspaceEdit.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    final Map<String, List<LspTextEdit>> result = {};
    if (rawChanges is Map) {
      rawChanges.forEach((uri, edits) {
        if (edits is List) {
          result[uri.toString()] = edits
              .whereType<Map<String, dynamic>>()
              .map((e) => LspTextEdit.fromJson(e))
              .toList();
        }
      });
    }
    return LspWorkspaceEdit(changes: result);
  }
}

class LspTextEdit {
  final LspRange range;
  final String newText;

  const LspTextEdit({required this.range, required this.newText});

  factory LspTextEdit.fromJson(Map<String, dynamic> json) {
    return LspTextEdit(
      range: LspRange.fromJson(json['range'] as Map<String, dynamic>? ?? const {}),
      newText: json['newText'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'newText': newText,
      };
}
