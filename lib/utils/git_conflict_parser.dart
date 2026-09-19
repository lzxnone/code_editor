/// 冲突块中的一段内容
class GitConflictSegment {
  /// 在 [GitConflictBlock] 内的起始行号（0-based，含）
  final int startLine;

  /// 结束行号（0-based，不含）
  final int endLine;

  const GitConflictSegment({required this.startLine, required this.endLine});

  /// 行数（可能为 0，表示这一段是空的）
  int get lineCount => endLine - startLine;
}

/// 文件中的一个冲突块
///
/// 只记录**位置**，内容由调用方按行号自行取用（避免重复持有全文副本）。
class GitConflictBlock {
  /// `<<<<<<<` 所在行号（0-based，含）
  final int startLine;

  /// `>>>>>>>` 所在行号（0-based，含）
  final int endLine;

  /// `<<<<<<<` 后标注的来源（rebase 下是**基线**侧，merge 下是当前分支）
  final String oursLabel;

  /// `>>>>>>>` 后标注的来源
  final String theirsLabel;

  final GitConflictSegment ours;
  final GitConflictSegment theirs;

  /// 共同祖先段；仅 `merge.conflictStyle=diff3` 时存在
  final GitConflictSegment? base;

  const GitConflictBlock({
    required this.startLine,
    required this.endLine,
    required this.oursLabel,
    required this.theirsLabel,
    required this.ours,
    required this.theirs,
    this.base,
  });

  /// 是否为 diff3 风格（带基线段）
  bool get hasBaseSegment => base != null;

  /// 该块跨越的总行数（含标记行），用于计算替换范围
  int get replacedLineCount => endLine - startLine + 1;
}

/// 冲突标记解析结果
class GitConflictParseResult {
  final List<GitConflictBlock> blocks;

  /// 格式是否可疑（标记不成对、嵌套、顺序错乱）
  ///
  /// 为真时**不要**对文件做任何自动替换：宁可退化成"手工编辑"，
  /// 也不能按错误的位置改写用户的代码。
  final bool isMalformed;

  /// 可疑原因，供 UI 提示
  final String? malformedReason;

  const GitConflictParseResult({
    this.blocks = const [],
    this.isMalformed = false,
    this.malformedReason,
  });

  bool get hasConflicts => blocks.isNotEmpty;

  static const GitConflictParseResult none = GitConflictParseResult();

  @override
  String toString() =>
      'GitConflictParseResult(blocks=${blocks.length}, malformed=$isMalformed)';
}

/// 解析文件中的 Git 冲突标记
///
/// 支持标准风格（`<<<<<<<` / `=======` / `>>>>>>>`）与 diff3 风格
/// （额外含 `|||||||` 基线段）。
///
/// 关键设计：**只信任成对且顺序正确的标记**。文件正文里本来就可能出现
/// 类似标记的文本（比如正在编辑这段解析代码本身），一旦结构可疑就整体
/// 标记为 malformed，由调用方退化为手工编辑。
class GitConflictParser {
  GitConflictParser._();

  static const String _oursMarker = '<<<<<<<';
  static const String _baseMarker = '|||||||';
  static const String _separator = '=======';
  static const String _theirsMarker = '>>>>>>>';

  static GitConflictParseResult parse(String content) {
    final lines = content.split('\n');
    final blocks = <GitConflictBlock>[];

    int? blockStart;
    String oursLabel = '';
    String theirsLabel = '';
    int? oursStart;
    int? baseStart;
    int? theirsStart;
    int? sepLine;
    bool sawBase = false;

    String? malformedReason;
    void markMalformed(String reason) {
      malformedReason ??= reason;
    }

    void reset() {
      blockStart = null;
      oursLabel = '';
      theirsLabel = '';
      oursStart = null;
      baseStart = null;
      theirsStart = null;
      sepLine = null;
      sawBase = false;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith(_oursMarker)) {
        if (blockStart != null) {
          // 上一个块还没结束就来了新的起始标记 → 嵌套，不可信任
          markMalformed('检测到嵌套的冲突标记，无法安全自动解析');
        }
        reset();
        blockStart = i;
        oursLabel = _labelOf(line, _oursMarker);
        oursStart = i + 1;
        continue;
      }

      if (blockStart == null) continue;

      if (line.startsWith(_baseMarker)) {
        sawBase = true;
        baseStart = i + 1;
        continue;
      }

      if (line.startsWith(_separator)) {
        if (sepLine != null) {
          markMalformed('同一个冲突块内出现多个分隔线');
        }
        sepLine = i;
        theirsStart = i + 1;
        continue;
      }

      if (line.startsWith(_theirsMarker)) {
        theirsLabel = _labelOf(line, _theirsMarker);
        final start = blockStart!;
        final sep = sepLine;
        final oursEnd = sawBase ? baseStart! - 1 : sep;

        if (sep == null || oursEnd == null) {
          // 缺少分隔线 → 结构不完整
          markMalformed('冲突块缺少 ======= 分隔线');
        } else {
          blocks.add(GitConflictBlock(
            startLine: start,
            endLine: i,
            oursLabel: oursLabel,
            theirsLabel: theirsLabel,
            ours: GitConflictSegment(startLine: oursStart!, endLine: oursEnd),
            theirs: GitConflictSegment(startLine: theirsStart!, endLine: i),
            base: sawBase
                ? GitConflictSegment(startLine: baseStart!, endLine: sep)
                : null,
          ));
        }
        reset();
      }
    }

    // 走到文件末尾仍在块内 → 标记不成对
    if (blockStart != null) {
      markMalformed('冲突标记未闭合');
    }

    if (malformedReason != null) {
      return GitConflictParseResult(
        blocks: const [],
        isMalformed: true,
        malformedReason: malformedReason,
      );
    }
    return GitConflictParseResult(blocks: List.unmodifiable(blocks));
  }

  /// 快速判断文件里是否含冲突标记（不做完整解析，用于列表标注）
  static bool containsMarkers(String content) {
    return content.contains(_oursMarker) && content.contains(_theirsMarker);
  }

  /// 取出标记行后面的来源标注（`<<<<<<< HEAD` → `HEAD`）
  static String _labelOf(String line, String marker) {
    return line.length > marker.length ? line.substring(marker.length).trim() : '';
  }

  /// 把第 [blockIndex] 个冲突块替换为 [replacement]，返回新内容
  ///
  /// 这是"逐块解决"的核心算法，独立成纯函数以便测试：
  /// - 只替换**该块的行范围**，前后内容原样保留（多块文件各块互不影响）
  /// - 传入旧的 [blocks] 与 [content] 必须来自同一次解析，否则行号会错位
  /// - [replacement] 为空表示"该块删掉"
  ///
  /// 调用方应在替换后**重新解析**再处理下一块：块的行号会随替换而整体移动，
  /// 维护偏移量容易出错，重解析代价可以忽略。
  static String? replaceBlock({
    required String content,
    required List<GitConflictBlock> blocks,
    required int blockIndex,
    required String replacement,
  }) {
    if (blockIndex < 0 || blockIndex >= blocks.length) return null;

    final lines = content.split('\n');
    final block = blocks[blockIndex];
    if (block.startLine < 0 || block.endLine >= lines.length) return null;

    final before = lines.sublist(0, block.startLine);
    final after = lines.sublist(block.endLine + 1);

    final replacementLines =
        replacement.isEmpty ? <String>[] : replacement.split('\n').toList();
    // split 在内容以换行结尾时会多出一个空串，去掉以免多插空行
    if (replacementLines.isNotEmpty && replacementLines.last.isEmpty) {
      replacementLines.removeLast();
    }

    return <String>[...before, ...replacementLines, ...after].join('\n');
  }

  /// 统计内容中未解决的冲突块数量（不做完整解析，用于快速校验）
  static int countMarkers(String content) => parse(content).blocks.length;
}
