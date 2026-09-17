import 'dart:math';

/// 模糊匹配与打字纠错结果
class FuzzyMatchResult {
  const FuzzyMatchResult({
    required this.isMatch,
    required this.score,
    this.matchedIndices = const [],
  });

  static const notMatched = FuzzyMatchResult(isMatch: false, score: -1);

  final bool isMatch;
  final int score;
  final List<int> matchedIndices;
}

/// 工业级代码模糊匹配与容错纠错打分器
class FuzzyMatcher {
  const FuzzyMatcher();

  /// 对 [pattern]（用户输入）与 [target]（候选词）进行匹配打分
  ///
  /// 支持：
  /// 1. 精确匹配 / 精确前缀匹配 (Prefix Match)
  /// 2. 忽略大小写前缀匹配 (Case-insensitive Prefix)
  /// 3. 驼峰与下划线缩写匹配 (CamelCase / Snake_case)
  /// 4. 连续子序列匹配 (Subsequence Match with Consecutive Bonus)
  /// 5. 打字手误纠错 (Typo Tolerance / Levenshtein Distance)
  static FuzzyMatchResult match(String pattern, String target) {
    if (pattern.isEmpty) {
      return const FuzzyMatchResult(isMatch: true, score: 100);
    }
    if (target.isEmpty) {
      return FuzzyMatchResult.notMatched;
    }

    // 1. 完全相同
    if (pattern == target) {
      return FuzzyMatchResult(
        isMatch: true,
        score: 3000,
        matchedIndices: List.generate(pattern.length, (i) => i),
      );
    }

    // 2. 严格区分大小写的前缀匹配 (最高优先级)
    if (target.startsWith(pattern)) {
      final score = 2000 - (target.length - pattern.length);
      return FuzzyMatchResult(
        isMatch: true,
        score: score,
        matchedIndices: List.generate(pattern.length, (i) => i),
      );
    }

    final lowerPattern = pattern.toLowerCase();
    final lowerTarget = target.toLowerCase();

    // 3. 忽略大小写的前缀匹配
    if (lowerTarget.startsWith(lowerPattern)) {
      final score = 1500 - (target.length - pattern.length);
      return FuzzyMatchResult(
        isMatch: true,
        score: score,
        matchedIndices: List.generate(pattern.length, (i) => i),
      );
    }

    // 4. 驼峰与下划线缩写匹配 (例如 "fb" 匹配 "FloatingActionButton", "tv" 匹配 "text_view")
    final camelMatch = _matchCamelOrSeparator(lowerPattern, target);
    if (camelMatch.isMatch) {
      return camelMatch;
    }

    // 5. 字符子序列匹配 (Subsequence Match)
    final subseqMatch = _matchSubsequence(lowerPattern, lowerTarget, target);
    if (subseqMatch.isMatch) {
      return subseqMatch;
    }

    // 6. 拼写手误纠错 (Typo Tolerance / Levenshtein Distance)
    // 当输入字符长度 >= 3 时，允许前缀 1 处编辑距离错误（如 prnt -> print, lenght -> length）
    // 当输入字符长度 >= 6 时，允许前缀 2 处编辑距离错误
    if (pattern.length >= 3) {
      final typoMatch = _matchTypo(lowerPattern, lowerTarget, target);
      if (typoMatch.isMatch) {
        return typoMatch;
      }
    }

    return FuzzyMatchResult.notMatched;
  }

  /// 驼峰与分隔符匹配
  static FuzzyMatchResult _matchCamelOrSeparator(String lowerPattern, String target) {
    final List<int> wordStartIndices = [];

    for (int i = 0; i < target.length; i++) {
      final char = target[i];
      if (i == 0) {
        wordStartIndices.add(i);
      } else if (char == '_' || char == '-' || char == '.') {
        if (i + 1 < target.length) {
          wordStartIndices.add(i + 1);
        }
      } else {
        final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
        final prevChar = target[i - 1];
        final isPrevLower = prevChar.toLowerCase() == prevChar && prevChar.toUpperCase() != prevChar;
        if (isUpper && isPrevLower) {
          wordStartIndices.add(i);
        }
      }
    }

    if (lowerPattern.length <= wordStartIndices.length) {
      int pIdx = 0;
      final List<int> matched = [];
      for (final sIdx in wordStartIndices) {
        if (pIdx < lowerPattern.length &&
            target[sIdx].toLowerCase() == lowerPattern[pIdx]) {
          matched.add(sIdx);
          pIdx++;
        }
      }
      if (pIdx == lowerPattern.length) {
        final score = 1000 - (target.length - lowerPattern.length) * 2;
        return FuzzyMatchResult(
          isMatch: true,
          score: max(score, 600),
          matchedIndices: matched,
        );
      }
    }

    return FuzzyMatchResult.notMatched;
  }

  /// 子序列匹配（考虑连续命中加分）
  static FuzzyMatchResult _matchSubsequence(
    String lowerPattern,
    String lowerTarget,
    String target,
  ) {
    int pIdx = 0;
    int tIdx = 0;
    final List<int> matched = [];
    int consecutiveCount = 0;
    int score = 700;

    while (pIdx < lowerPattern.length && tIdx < lowerTarget.length) {
      if (lowerPattern[pIdx] == lowerTarget[tIdx]) {
        matched.add(tIdx);
        // 大小写一致加分
        if (pIdx < target.length && target[tIdx] == lowerPattern[pIdx]) {
          score += 10;
        }
        // 连续匹配加分
        if (matched.length > 1 && matched.last == matched[matched.length - 2] + 1) {
          consecutiveCount++;
          score += consecutiveCount * 25;
        } else {
          consecutiveCount = 0;
        }
        pIdx++;
      }
      tIdx++;
    }

    if (pIdx == lowerPattern.length) {
      score -= matched.first * 15;
      score -= (target.length - lowerPattern.length) * 2;
      return FuzzyMatchResult(
        isMatch: true,
        score: max(score, 450),
        matchedIndices: matched,
      );
    }

    return FuzzyMatchResult.notMatched;
  }

  /// 打字手误纠错（基于编辑距离对比前缀）
  static FuzzyMatchResult _matchTypo(
    String lowerPattern,
    String lowerTarget,
    String target,
  ) {
    final int pLen = lowerPattern.length;
    final int minLen = max(1, pLen - 1);
    final int maxLen = min(lowerTarget.length, pLen + 1);

    int bestDistance = 999;
    int bestPrefixLen = pLen;

    for (int len = minLen; len <= maxLen; len++) {
      final prefix = lowerTarget.substring(0, len);
      final dist = _levenshteinDistance(lowerPattern, prefix);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestPrefixLen = len;
      }
    }

    final int maxAllowedDist = pLen >= 6 ? 2 : 1;
    if (bestDistance <= maxAllowedDist) {
      final score = 380 - (bestDistance * 80) - (target.length - pLen);
      return FuzzyMatchResult(
        isMatch: true,
        score: max(score, 150),
        matchedIndices: List.generate(min(bestPrefixLen, target.length), (i) => i),
      );
    }

    return FuzzyMatchResult.notMatched;
  }

  /// 计算两个字符串的 Levenshtein 编辑距离
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(
            prev[j + 1] + 1,
            prev[j] + cost,
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[s2.length];
  }
}
