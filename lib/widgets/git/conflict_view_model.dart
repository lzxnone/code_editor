/// 冲突页的行模型与内容组装（纯逻辑，便于单测）
///
/// 与 `git_conflict_parser.dart` 的分工：
/// - 解析器负责"标记块在文件中的位置"
/// - 这里负责"把解析结果摊平成一条条带语义的行"，供 UI 直接渲染
///
/// 独立成文件的原因：VS Code 风格的内联冲突视图**完全由行渲染**组成
/// （标记行变标题带、内容行带整段底色），把"哪些行属于哪一段"算清楚
/// 是正确性的核心，而它必须可测 —— 上一版页面的内容错乱正是栽在
/// 行号映射上。
library;

import '../../utils/git_conflict_parser.dart';

/// 一行在冲突视图中的角色
enum ConflictLineRole {
  /// 普通上下文行（不属于任何冲突块）
  context,

  /// 冲突块开头标记行（渲染为标题带 + 内联操作）
  oursHeader,

  /// 当前侧内容行
  oursContent,

  /// 基线段标题（diff3 风格；不显示操作）
  baseHeader,

  /// 基线段内容行
  baseContent,

  /// 分隔线（`=======`），渲染为极窄分隔
  separator,

  /// 传入侧标题带
  theirsHeader,

  /// 传入侧内容行
  theirsContent,
}

/// 一行渲染数据
class ConflictLine {
  /// 文件中的绝对行号（1-based，供行号栏显示）
  final int lineNumber;

  /// 该行的原始文本
  final String text;

  final ConflictLineRole role;

  /// 若该行是一处分段的标题，这里给出它所属的冲突块序号（0-based）
  final int? blockIndex;

  const ConflictLine({
    required this.lineNumber,
    required this.text,
    required this.role,
    this.blockIndex,
  });

  bool get isHeader =>
      role == ConflictLineRole.oursHeader ||
      role == ConflictLineRole.baseHeader ||
      role == ConflictLineRole.theirsHeader;

  bool get isContent =>
      role == ConflictLineRole.oursContent ||
      role == ConflictLineRole.baseContent ||
      role == ConflictLineRole.theirsContent;
}

/// 把冲突文件内容摊平成可渲染的行序列
class ConflictLineBuilder {
  ConflictLineBuilder._();

  /// 解析 [content] 并生成行序列
  ///
  /// [parseResult] 必须与 [content] 来自同一次解析，否则行号会错位。
  static List<ConflictLine> build(
    String content,
    GitConflictParseResult parseResult,
  ) {
    final lines = content.split('\n');
    final result = <ConflictLine>[];

    // 行号 → 该行承担的段角色
    final roles = List<ConflictLineRole?>.filled(lines.length, null);
    final blockOfLine = List<int?>.filled(lines.length, null);

    for (var b = 0; b < parseResult.blocks.length; b++) {
      final block = parseResult.blocks[b];

      void mark(int from, int toExclusive, ConflictLineRole role) {
        for (var i = from; i < toExclusive; i++) {
          if (i >= 0 && i < roles.length) {
            roles[i] = role;
            blockOfLine[i] = b;
          }
        }
      }

      // 起始标记行
      mark(block.startLine, block.startLine + 1, ConflictLineRole.oursHeader);
      // 当前侧内容
      mark(
        block.ours.startLine,
        block.ours.endLine,
        ConflictLineRole.oursContent,
      );

      if (block.base != null) {
        // diff3：基线段（其上一行是 ||||||| 标记）
        mark(
          block.base!.startLine - 1,
          block.base!.startLine,
          ConflictLineRole.baseHeader,
        );
        mark(
          block.base!.startLine,
          block.base!.endLine,
          ConflictLineRole.baseContent,
        );
      }

      // 分隔线位于基线段结束处（有基线时）或 ours 结束处
      final separatorLine = block.base != null
          ? block.base!.endLine
          : block.ours.endLine;
      mark(separatorLine, separatorLine + 1, ConflictLineRole.separator);

      // 传入侧内容
      mark(
        block.theirs.startLine,
        block.theirs.endLine,
        ConflictLineRole.theirsContent,
      );
      // 结束标记行
      mark(block.endLine, block.endLine + 1, ConflictLineRole.theirsHeader);
    }

    for (var i = 0; i < lines.length; i++) {
      result.add(
        ConflictLine(
          lineNumber: i + 1,
          text: lines[i],
          role: roles[i] ?? ConflictLineRole.context,
          blockIndex: blockOfLine[i],
        ),
      );
    }
    return result;
  }

  /// 统计各块是否已解决（视图中没有标记块时即为完全解决）
  static bool isFullyResolved(GitConflictParseResult parseResult) =>
      parseResult.blocks.isEmpty;
}
