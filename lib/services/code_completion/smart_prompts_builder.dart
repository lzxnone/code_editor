import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'core/completion_engine.dart';
import 'core/completion_types.dart';
import 'providers/completion_provider.dart';
import 'providers/lsp_completion_provider.dart';

export 'core/completion_engine.dart';
export 'core/completion_types.dart';
export 'providers/completion_provider.dart';
export 'providers/lsp_completion_provider.dart';

/// 工业级智能代码补全构建器适配器
///
/// 实现 re_editor 的 CodeAutocompletePromptsBuilder 协议，
/// 将编辑器的输入上下文规范化后，转派给 LSP CompletionEngine 异步调度处理。
class SmartCodeAutocompletePromptsBuilder implements CodeAutocompletePromptsBuilder {
  SmartCodeAutocompletePromptsBuilder({
    this.controller,
    this.filePath,
    this.enableLspCompletion = true,
    @Deprecated('本地补全已完全移除，此参数无效') bool enableLocalCompletion = false,
    @Deprecated('本地补全已完全移除，此参数无效') dynamic language,
    @Deprecated('本地补全已完全移除，此参数无效') List<CodePrompt> keywordPrompts = const [],
    @Deprecated('本地补全已完全移除，此参数无效') List<CodePrompt> directPrompts = const [],
    @Deprecated('本地补全已完全移除，此参数无效') Map<String, List<CodePrompt>> relatedPrompts = const {},
    List<CompletionProvider>? customProviders,
  }) {
    final providers = <CompletionProvider>[
      if (customProviders != null)
        ...customProviders
      else if (enableLspCompletion)
        const LspCompletionProvider(),
    ];

    engine = CompletionEngine(providers: providers);
  }

  final CodeLineEditingController? controller;
  final String? filePath;
  final bool enableLspCompletion;

  late final CompletionEngine engine;

  /// 当前活跃的悬浮面板 ValueNotifier（由 CodeAutocompleteView 动态注入绑定）
  ValueNotifier<CodeAutocompleteEditingValue>? activeNotifier;

  @override
  FutureOr<CodeAutocompleteEditingValue?> build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    if (!enableLspCompletion || engine.providers.isEmpty) {
      return null;
    }

    final String text = codeLine.text;
    if (selection.extentOffset > text.length) {
      return null;
    }

    final Characters charactersBefore = text.substring(0, selection.extentOffset).characters;
    if (charactersBefore.isEmpty) {
      return null;
    }

    // 检查是否在普通闭合双引号或单引号字符串中（简易校验）
    final String linePrefix = text.substring(0, selection.extentOffset);
    final int singleQuoteCount = "'".allMatches(linePrefix).length;
    final int doubleQuoteCount = '"'.allMatches(linePrefix).length;
    if (singleQuoteCount % 2 == 1 || doubleQuoteCount % 2 == 1) {
      // 位于字符串字面量内部，不触发代码智能补全
      return null;
    }

    final String input;
    String? triggerCharacter;
    String? target;

    if (charactersBefore.takeLast(1).string == '.') {
      triggerCharacter = '.';
      input = '';
      int start = charactersBefore.length - 2;
      for (; start >= 0; start--) {
        final char = charactersBefore.elementAt(start);
        if (!_isValidIdentifierChar(char)) {
          break;
        }
      }
      target = charactersBefore.getRange(start + 1, charactersBefore.length - 1).string;
    } else {
      int start = charactersBefore.length - 1;
      for (; start >= 0; start--) {
        final char = charactersBefore.elementAt(start);
        if (!_isValidIdentifierChar(char)) {
          break;
        }
      }
      input = charactersBefore.getRange(start + 1, charactersBefore.length).string;
      if (input.isEmpty) {
        return null;
      }

      if (start > 0 && charactersBefore.elementAt(start) == '.') {
        triggerCharacter = '.';
        final int mark = start;
        for (start = start - 1; start >= 0; start--) {
          final char = charactersBefore.elementAt(start);
          if (!_isValidIdentifierChar(char)) {
            break;
          }
        }
        target = charactersBefore.getRange(start + 1, mark).string;
      }
    }

    final completionContext = CompletionContext(
      input: input,
      triggerCharacter: triggerCharacter,
      target: target,
      filePath: filePath,
      lineIndex: selection.extentIndex,
      characterOffset: selection.extentOffset,
      codeLine: codeLine,
      codeLines: controller?.codeLines,
      selection: selection,
    );

    // 原生异步发起 LSP 智能语义补全请求
    return engine.requestCompletionsAsync(completionContext);
  }

  static bool _isValidIdentifierChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        (code >= 48 && code <= 57) || // 0-9
        code == 95 || // _
        code == 64 || // @ (for entity selectors e.g. @a, @e, @s, @p)
        code == 36; // $ (for macro variables and identifiers)
  }
}

