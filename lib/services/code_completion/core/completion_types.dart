import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import '../fuzzy_matcher.dart';

/// 补全候选词类别
enum SmartPromptKind {
  keyword,
  function,
  field,
  type,
  constant,
  word,
}

/// 具有模糊匹配打分与高亮索引的工业级智能补全 Prompt
class SmartPrompt extends CodePrompt {
  SmartPrompt({
    required super.word,
    this.type,
    this.kind = SmartPromptKind.word,
    this.customAutocomplete,
    this.parameters = const {},
    this.score = 0,
    this.matchedIndices = const [],
    this.detail,
    this.documentation,
    this.sortText,
  });

  final String? type;
  final SmartPromptKind kind;
  final CodeAutocompleteResult? customAutocomplete;
  final Map<String, String> parameters;
  final String? detail;
  final String? documentation;
  final String? sortText;
  int score;
  List<int> matchedIndices;

  @override
  CodeAutocompleteResult get autocomplete {
    if (customAutocomplete != null) {
      return customAutocomplete!;
    }
    if (kind == SmartPromptKind.function && parameters.isNotEmpty) {
      final paramStr = parameters.keys.join(', ');
      return CodeAutocompleteResult(
        input: '',
        word: '$word($paramStr)',
        selection: TextSelection.collapsed(offset: word.length + 1),
      );
    }
    return CodeAutocompleteResult.fromWord(word);
  }

  @override
  bool match(String input) {
    if (input.isEmpty) return true;
    final res = FuzzyMatcher.match(input, word);
    if (res.isMatch) {
      score = res.score;
      matchedIndices = res.matchedIndices;
      return true;
    }
    return false;
  }

  SmartPrompt copyWithScore({
    required int score,
    required List<int> matchedIndices,
  }) {
    return SmartPrompt(
      word: word,
      type: type,
      kind: kind,
      customAutocomplete: customAutocomplete,
      parameters: parameters,
      score: score,
      matchedIndices: matchedIndices,
      detail: detail,
      documentation: documentation,
      sortText: sortText,
    );
  }
}

/// 代码补全上下文请求参数
class CompletionContext {
  final String input;
  final String? triggerCharacter;
  final String? target;
  final String? filePath;
  final int lineIndex;
  final int characterOffset;
  final CodeLine codeLine;
  final CodeLines? codeLines;
  final CodeLineSelection selection;

  const CompletionContext({
    required this.input,
    this.triggerCharacter,
    this.target,
    this.filePath,
    required this.lineIndex,
    required this.characterOffset,
    required this.codeLine,
    this.codeLines,
    required this.selection,
  });

  bool get isDotTrigger => triggerCharacter == '.';
}
