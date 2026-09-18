import 'dart:convert';
import 'dart:math' as math;

/// 差异行类型
enum DiffLineType {
  /// 未更改
  unchanged,

  /// 新增
  added,

  /// 删除
  deleted,

  /// 空占位行 (在双屏对齐模式下用于填充高度保持两侧对齐)
  empty,
}

/// 单侧差异行模型
class DiffLine {
  final DiffLineType type;
  final String text;
  final int? lineNumber;

  const DiffLine({
    required this.type,
    required this.text,
    this.lineNumber,
  });

  bool get isEmptyPlaceholder => type == DiffLineType.empty;
}

/// 单屏内联差异行模型
class UnifiedDiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;

  const UnifiedDiffLine({
    required this.type,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

/// 双屏差异对比计算结果
class SplitDiffResult {
  final List<DiffLine> leftLines;
  final List<DiffLine> rightLines;
  final List<int> changeRowIndices;
  final int additionsCount;
  final int deletionsCount;

  const SplitDiffResult({
    required this.leftLines,
    required this.rightLines,
    required this.changeRowIndices,
    required this.additionsCount,
    required this.deletionsCount,
  });
}

/// Git Diff 算法与行对齐计算工具类
class GitDiffHelper {
  /// 计算双屏并排对齐结果
  static SplitDiffResult computeSplitDiff(String originalText, String modifiedText) {
    final originalLines = _splitLines(originalText);
    final modifiedLines = _splitLines(modifiedText);

    // 1. 公共前后缀快速收缩剪枝 (大幅提升常见文件差异计算性能)
    int prefixCount = 0;
    while (prefixCount < originalLines.length &&
        prefixCount < modifiedLines.length &&
        originalLines[prefixCount] == modifiedLines[prefixCount]) {
      prefixCount++;
    }

    int suffixCount = 0;
    while (suffixCount < (originalLines.length - prefixCount) &&
        suffixCount < (modifiedLines.length - prefixCount) &&
        originalLines[originalLines.length - 1 - suffixCount] ==
            modifiedLines[modifiedLines.length - 1 - suffixCount]) {
      suffixCount++;
    }

    final leftResult = <DiffLine>[];
    final rightResult = <DiffLine>[];
    final changeRowIndices = <int>[];
    int additions = 0;
    int deletions = 0;

    // 前缀相同部分
    for (int i = 0; i < prefixCount; i++) {
      final line = originalLines[i];
      leftResult.add(DiffLine(
        type: DiffLineType.unchanged,
        text: line,
        lineNumber: i + 1,
      ));
      rightResult.add(DiffLine(
        type: DiffLineType.unchanged,
        text: line,
        lineNumber: i + 1,
      ));
    }

    // 中间变化部分
    final middleOrig = originalLines.sublist(
      prefixCount,
      originalLines.length - suffixCount,
    );
    final middleMod = modifiedLines.sublist(
      prefixCount,
      modifiedLines.length - suffixCount,
    );

    int origLineNo = prefixCount + 1;
    int modLineNo = prefixCount + 1;

    final diffOps = _computeDiffOperations(middleOrig, middleMod);

    // 将 diff 操作块分组合并以构建双屏对齐
    int opIndex = 0;
    while (opIndex < diffOps.length) {
      final op = diffOps[opIndex];

      if (op.type == _DiffOpType.equal) {
        leftResult.add(DiffLine(
          type: DiffLineType.unchanged,
          text: op.text,
          lineNumber: origLineNo++,
        ));
        rightResult.add(DiffLine(
          type: DiffLineType.unchanged,
          text: op.text,
          lineNumber: modLineNo++,
        ));
        opIndex++;
      } else {
        // 遇到变更块 (连续的 delete 与 insert)
        final delBlock = <String>[];
        final addBlock = <String>[];

        while (opIndex < diffOps.length && diffOps[opIndex].type != _DiffOpType.equal) {
          if (diffOps[opIndex].type == _DiffOpType.delete) {
            delBlock.add(diffOps[opIndex].text);
            deletions++;
          } else if (diffOps[opIndex].type == _DiffOpType.insert) {
            addBlock.add(diffOps[opIndex].text);
            additions++;
          }
          opIndex++;
        }

        // 记录差异起点行索引
        changeRowIndices.add(leftResult.length);

        final maxLen = math.max(delBlock.length, addBlock.length);
        for (int i = 0; i < maxLen; i++) {
          if (i < delBlock.length) {
            leftResult.add(DiffLine(
              type: DiffLineType.deleted,
              text: delBlock[i],
              lineNumber: origLineNo++,
            ));
          } else {
            leftResult.add(const DiffLine(
              type: DiffLineType.empty,
              text: '',
              lineNumber: null,
            ));
          }

          if (i < addBlock.length) {
            rightResult.add(DiffLine(
              type: DiffLineType.added,
              text: addBlock[i],
              lineNumber: modLineNo++,
            ));
          } else {
            rightResult.add(const DiffLine(
              type: DiffLineType.empty,
              text: '',
              lineNumber: null,
            ));
          }
        }
      }
    }

    // 后缀相同部分
    final origSuffixStart = originalLines.length - suffixCount;
    final modSuffixStart = modifiedLines.length - suffixCount;
    for (int i = 0; i < suffixCount; i++) {
      final line = originalLines[origSuffixStart + i];
      leftResult.add(DiffLine(
        type: DiffLineType.unchanged,
        text: line,
        lineNumber: origSuffixStart + i + 1,
      ));
      rightResult.add(DiffLine(
        type: DiffLineType.unchanged,
        text: line,
        lineNumber: modSuffixStart + i + 1,
      ));
    }

    return SplitDiffResult(
      leftLines: leftResult,
      rightLines: rightResult,
      changeRowIndices: changeRowIndices,
      additionsCount: additions,
      deletionsCount: deletions,
    );
  }

  /// 将双屏结果或文本转换为单屏内联 (Unified) 差异行列表
  static List<UnifiedDiffLine> toUnifiedDiff(String originalText, String modifiedText) {
    final originalLines = _splitLines(originalText);
    final modifiedLines = _splitLines(modifiedText);

    final diffOps = _computeDiffOperations(originalLines, modifiedLines);
    final result = <UnifiedDiffLine>[];

    int origLineNo = 1;
    int modLineNo = 1;

    for (final op in diffOps) {
      switch (op.type) {
        case _DiffOpType.equal:
          result.add(UnifiedDiffLine(
            type: DiffLineType.unchanged,
            text: op.text,
            oldLineNumber: origLineNo++,
            newLineNumber: modLineNo++,
          ));
          break;
        case _DiffOpType.delete:
          result.add(UnifiedDiffLine(
            type: DiffLineType.deleted,
            text: op.text,
            oldLineNumber: origLineNo++,
            newLineNumber: null,
          ));
          break;
        case _DiffOpType.insert:
          result.add(UnifiedDiffLine(
            type: DiffLineType.added,
            text: op.text,
            oldLineNumber: null,
            newLineNumber: modLineNo++,
          ));
          break;
      }
    }

    return result;
  }

  static List<String> _splitLines(String text) {
    if (text.isEmpty) return [];
    return const LineSplitter().convert(text);
  }

  /// 计算差异编辑脚本 (基于标准动态规划 LCS 矩阵，针对超长文本具备平滑防御)
  static List<_DiffOp> _computeDiffOperations(List<String> a, List<String> b) {
    final n = a.length;
    final m = b.length;

    if (n == 0) {
      return b.map((text) => _DiffOp(_DiffOpType.insert, text)).toList();
    }
    if (m == 0) {
      return a.map((text) => _DiffOp(_DiffOpType.delete, text)).toList();
    }

    // 防御过大矩阵导致的 OOM (单次差异超过 200,000 元素积时快速回退)
    if (n * m > 250000) {
      return [
        ...a.map((text) => _DiffOp(_DiffOpType.delete, text)),
        ...b.map((text) => _DiffOp(_DiffOpType.insert, text)),
      ];
    }

    // LCS 动态规划
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        if (a[i] == b[j]) {
          dp[i + 1][j + 1] = dp[i][j] + 1;
        } else {
          dp[i + 1][j + 1] = math.max(dp[i + 1][j], dp[i][j + 1]);
        }
      }
    }

    // 回溯生成操作队列
    final ops = <_DiffOp>[];
    int i = n;
    int j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
        ops.add(_DiffOp(_DiffOpType.equal, a[i - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        ops.add(_DiffOp(_DiffOpType.insert, b[j - 1]));
        j--;
      } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
        ops.add(_DiffOp(_DiffOpType.delete, a[i - 1]));
        i--;
      }
    }

    return ops.reversed.toList();
  }
}

enum _DiffOpType { equal, delete, insert }

class _DiffOp {
  final _DiffOpType type;
  final String text;

  _DiffOp(this.type, this.text);
}
