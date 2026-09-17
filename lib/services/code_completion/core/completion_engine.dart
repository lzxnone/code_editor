import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:re_editor/re_editor.dart';
import '../fuzzy_matcher.dart';
import '../providers/completion_provider.dart';
import 'completion_types.dart';

/// 补全调度引擎 (Completion Engine)
///
/// 核心职责：
/// 1. 0ms 同步聚合本地所有同步 Provider（关键字、词法启发提取），保证首帧流畅弹出；
/// 2. 异步发起 LSP 或远程 Provider 请求；
/// 3. 基于 requestId 与版本号防抖校验，杜绝陈旧回包覆盖；
/// 4. 统一执行 Fuzzy 模糊匹配打分、sortText 权重排序与截断；
/// 5. 动态向绑定的 ValueNotifier 推流更新，实现平滑渐进增强。
class CompletionEngine {
  CompletionEngine({
    required this.providers,
    this.maxSuggestions = 40,
  });

  final List<CompletionProvider> providers;
  final int maxSuggestions;

  int _lastRequestId = 0;

  /// 异步直接请求补全（专为 LSP 异步语义流优化设计）
  Future<CodeAutocompleteEditingValue?> requestCompletionsAsync(
    CompletionContext context,
  ) async {
    final currentRequestId = ++_lastRequestId;
    final currentInput = context.input;

    try {
      final results = await Future.wait(
        providers.map((p) async {
          try {
            final res = await p.provideCompletions(context);
            return res;
          } catch (_) {
            return <SmartPrompt>[];
          }
        }),
      );

      // 请求过期（用户已键入新内容或已移动光标），直接废弃
      if (currentRequestId != _lastRequestId) return null;

      final allPrompts = <SmartPrompt>[];
      final seenWords = <String>{};
      for (final list in results) {
        for (final p in list) {
          if (seenWords.add(p.word)) {
            allPrompts.add(p);
          }
        }
      }

      if (allPrompts.isEmpty) return null;
      return scoreAndFilter(allPrompts, currentInput);
    } catch (_) {
      return null;
    }
  }

  /// 兼容推流式调用
  CodeAutocompleteEditingValue? requestCompletions(
    CompletionContext context, {
    ValueNotifier<CodeAutocompleteEditingValue>? notifier,
  }) {
    if (notifier != null) {
      requestCompletionsAsync(context).then((value) {
        if (value != null) {
          notifier.value = value;
        }
      });
    }
    return null;
  }

  /// 模糊匹配打分、权重排序与截取
  CodeAutocompleteEditingValue? scoreAndFilter(List<SmartPrompt> candidates, String input) {
    if (candidates.isEmpty) {
      return null;
    }

    final List<SmartPrompt> matchedPrompts = [];
    for (final candidate in candidates) {
      if (input.isEmpty) {
        matchedPrompts.add(candidate.copyWithScore(
          score: 100,
          matchedIndices: const [],
        ));
      } else {
        final result = FuzzyMatcher.match(input, candidate.word);
        if (result.isMatch) {
          matchedPrompts.add(candidate.copyWithScore(
            score: result.score,
            matchedIndices: result.matchedIndices,
          ));
        }
      }
    }

    if (matchedPrompts.isEmpty) {
      return null;
    }

    // 按照得分降序排序，相同得分若有 LSP sortText 则依据 sortText 升序，否则按字典序升序
    matchedPrompts.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      if (a.sortText != null && b.sortText != null) {
        final sortCompare = a.sortText!.compareTo(b.sortText!);
        if (sortCompare != 0) return sortCompare;
      }
      return a.word.compareTo(b.word);
    });

    // 截取前 maxSuggestions 条最佳结果，保证 60fps 流畅渲染
    final limitedPrompts = matchedPrompts.take(maxSuggestions).toList();

    return CodeAutocompleteEditingValue(
      input: input,
      prompts: limitedPrompts,
      index: 0,
    );
  }

  void dispose() {
    _lastRequestId++;
    for (final provider in providers) {
      provider.dispose();
    }
  }
}
