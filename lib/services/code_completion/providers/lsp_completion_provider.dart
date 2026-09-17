import 'dart:async';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import '../../lsp/lsp_manager.dart';
import '../../lsp/lsp_protocol.dart';
import '../core/completion_types.dart';
import 'completion_provider.dart';

/// 远程 LSP 语言服务补全数据源提供者
class LspCompletionProvider implements CompletionProvider {
  const LspCompletionProvider();

  @override
  String get id => 'lsp';

  @override
  bool get isAsync => true;

  @override
  Future<List<SmartPrompt>> provideCompletions(CompletionContext context) async {
    final filePath = context.filePath;
    if (filePath == null || filePath.isEmpty) {
      return const [];
    }

    final session = LspManager.instance.getExistingSession(filePath);
    if (session == null || !session.isInitialized) {
      return const [];
    }

    final lspItems = await session.getCompletions(
      filePath,
      context.lineIndex,
      context.characterOffset,
    );

    return lspItems.map(fromLspItem).toList();
  }

  /// 将 LSP 原始协议的 LspCompletionItem 转换为统一领域模型 SmartPrompt
  static SmartPrompt fromLspItem(LspCompletionItem item) {
    SmartPromptKind kind;
    switch (item.kind) {
      case 2: // Method
      case 3: // Function
      case 4: // Constructor
        kind = SmartPromptKind.function;
        break;
      case 5: // Field
      case 6: // Variable
      case 10: // Property
        kind = SmartPromptKind.field;
        break;
      case 7: // Class
      case 8: // Interface
      case 13: // Enum
      case 22: // Struct
      case 25: // TypeParameter
        kind = SmartPromptKind.type;
        break;
      case 14: // Keyword
        kind = SmartPromptKind.keyword;
        break;
      case 21: // Constant
        kind = SmartPromptKind.constant;
        break;
      default:
        kind = SmartPromptKind.word;
    }

    final insert = item.effectiveInsertText;
    final word = item.label.isNotEmpty ? item.label : insert;

    CodeAutocompleteResult? customAuto;
    if (insert != word) {
      customAuto = CodeAutocompleteResult(
        input: '',
        word: insert,
        selection: TextSelection.collapsed(offset: insert.length),
      );
    }

    return SmartPrompt(
      word: word,
      kind: kind,
      type: item.detail,
      detail: item.detail,
      documentation: item.documentation,
      sortText: item.sortText,
      customAutocomplete: customAuto,
    );
  }

  @override
  void dispose() {}
}
