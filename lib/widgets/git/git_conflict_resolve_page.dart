import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_font.dart';
import '../../models/editor_theme.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tab_provider.dart';
import '../../services/file_service.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/git_conflict_parser.dart';
import '../../utils/syntax_highlight_helper.dart';
import 'conflict_view_model.dart';

/// 冲突解决页（VS Code 内联冲突风格）
///
/// 视觉与交互参照 VS Code 的内联冲突视图：
/// - 冲突标记行渲染成**整行色带标题**：`<<<<<<< HEAD (Current Change)` 绿、
///   `>>>>>>> theirs (Incoming Change)` 蓝、`|||||||` 基线段灰
/// - 每段内容带**整段底色**（当前侧绿、传入侧蓝）
/// - 标记行上叠加一行**内联操作**：Accept Current / Accept Incoming /
///   Accept Both / Compare
/// - 底部常驻「保存并标记为已解决」
///
/// 实现说明：这是**独立页面**，刻意不复用 `git_diff_page.dart` 的代码。
/// 只读行渲染器 + 固定行号栏 + 全向滚动 + 双指缩放均按该类页面的既有做法
/// 自行实现，保证缩放手感、行号对齐、横向滚动行为与本 App 其余部分一致。
///
/// **不使用 `CodeEditor`**：它来自 `re_editor`，只支持行级着色，
/// 无法表达"标记行变标题带 + 内容行整段底色"这种行级装饰。
class GitConflictResolvePage extends StatefulWidget {
  const GitConflictResolvePage({
    super.key,
    required this.file,
    required this.gitProvider,
  });

  final GitConflictedFile file;
  final GitProvider gitProvider;

  static Route<void> route({
    required GitConflictedFile file,
    required GitProvider gitProvider,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          GitConflictResolvePage(file: file, gitProvider: gitProvider),
    );
  }

  @override
  State<GitConflictResolvePage> createState() => _GitConflictResolvePageState();
}

class _GitConflictResolvePageState extends State<GitConflictResolvePage> {
  bool _isLoading = true;
  String? _errorMessage;

  /// 当前文件内容（\n 规范化，与解析行号一致）
  String _content = '';
  GitConflictParseResult _parsed = GitConflictParseResult.none;
  List<ConflictLine> _lines = const [];

  // 滚动分工照抄差异页：垂直 / 水平 / 行号各自独立控制器
  late final ScrollController _vController;
  late final ScrollController _hController;
  late final ScrollController _gutterController;
  bool _syncing = false;

  double? _committedFontSize;
  double? _activeZoomFontSize;

  final Map<int, Offset> _pointers = {};
  int? _pointer1;
  int? _pointer2;
  double? _initialDistance;
  double? _initialFontSize;
  bool _isPinching = false;
  Offset? _lastPanPos;
  bool _showZoomBadge = false;

  final Map<String, TextSpan> _highlightCache = {};

  @override
  void initState() {
    super.initState();
    _vController = ScrollController();
    _hController = ScrollController();
    _gutterController = ScrollController();
    _vController.addListener(_onVerticalScrolled);
    _load();
  }

  @override
  void dispose() {
    _vController.removeListener(_onVerticalScrolled);
    _vController.dispose();
    _hController.dispose();
    _gutterController.dispose();
    super.dispose();
  }

  void _onVerticalScrolled() {
    if (_syncing || !_gutterController.hasClients) return;
    _syncing = true;
    _gutterController.jumpTo(
      _vController.offset.clamp(
        _gutterController.position.minScrollExtent,
        _gutterController.position.maxScrollExtent,
      ),
    );
    _syncing = false;
  }

  double get _baseFontSize {
    try {
      return context.read<SettingsProvider>().fontSize;
    } catch (_) {
      return 13.0;
    }
  }

  double get _effectiveFontSize =>
      _activeZoomFontSize ?? _committedFontSize ?? _baseFontSize;

  double get _rowHeight => (_effectiveFontSize * 1.45 + 4.0).roundToDouble();

  EditorTheme get _editorTheme {
    try {
      return context.read<SettingsProvider>().editorTheme;
    } catch (_) {
      return EditorTheme.atomOneDark;
    }
  }

  AppFontItem get _editorFont {
    try {
      return context.read<SettingsProvider>().editorFont;
    } catch (_) {
      return AppFonts.editorJetBrainsMono;
    }
  }

  // ---------------------------- 数据 ----------------------------

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 必须读磁盘：冲突时 Git 已把标记写进文件，内存标签页内容可能已过期
      final raw = await FileService.instance.readFileContent(
        widget.file.absolutePath,
      );
      final normalized = raw.replaceAll('\r\n', '\n');
      final parsed = GitConflictParser.parse(normalized);

      if (!mounted) return;
      setState(() {
        _content = normalized;
        _parsed = parsed;
        _lines = ConflictLineBuilder.build(normalized, parsed);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 取某块某一段的文本（按该段在**本文件中的绝对行号**切分）
  String _segmentText(int blockIndex, ConflictLineRole side) {
    final lines = _content.split('\n');
    final block = _parsed.blocks[blockIndex];
    final seg = switch (side) {
      ConflictLineRole.oursContent => block.ours,
      ConflictLineRole.baseContent => block.base,
      ConflictLineRole.theirsContent => block.theirs,
      _ => null,
    };
    if (seg == null) return '';
    final start = seg.startLine.clamp(0, lines.length);
    final end = seg.endLine.clamp(start, lines.length);
    return lines.sublist(start, end).join('\n');
  }

  /// 用 [replacement] 替换某块并立即写回磁盘
  Future<void> _applyBlock(int blockIndex, String replacement) async {
    final newContent = GitConflictParser.replaceBlock(
      content: _content,
      blocks: _parsed.blocks,
      blockIndex: blockIndex,
      replacement: replacement,
    );
    if (newContent == null) return;

    try {
      await FileService.instance.saveFile(widget.file.absolutePath, newContent);
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, e.toString(), type: ToastType.error);
      return;
    }
    if (!mounted) return;

    // 替换后行号整体移动：重新解析比维护偏移量可靠得多
    final parsed = GitConflictParser.parse(newContent);
    setState(() {
      _content = newContent;
      _parsed = parsed;
      _lines = ConflictLineBuilder.build(newContent, parsed);
    });
  }

  Future<void> _acceptCurrent(int blockIndex) async {
    await _applyBlock(
      blockIndex,
      _segmentText(blockIndex, ConflictLineRole.oursContent),
    );
  }

  Future<void> _acceptIncoming(int blockIndex) async {
    await _applyBlock(
      blockIndex,
      _segmentText(blockIndex, ConflictLineRole.theirsContent),
    );
  }

  Future<void> _acceptBoth(int blockIndex) async {
    final current = _segmentText(blockIndex, ConflictLineRole.oursContent);
    final incoming = _segmentText(blockIndex, ConflictLineRole.theirsContent);
    final combined = [current, incoming].where((s) => s.isNotEmpty).join('\n');
    await _applyBlock(blockIndex, combined);
  }

  Future<void> _scrollToBlock(int blockIndex) async {
    if (blockIndex < 0 || blockIndex >= _parsed.blocks.length) return;
    if (!_vController.hasClients) return;
    final target = (_parsed.blocks[blockIndex].startLine * _rowHeight - 60)
        .clamp(0.0, _vController.position.maxScrollExtent);
    await _vController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  int _nearestBlock(int direction) {
    if (!_vController.hasClients || _parsed.blocks.isEmpty) return 0;
    final currentLine = (_vController.offset / _rowHeight).floor();
    if (direction > 0) {
      for (var i = 0; i < _parsed.blocks.length; i++) {
        if (_parsed.blocks[i].startLine > currentLine) return i;
      }
      return _parsed.blocks.length - 1;
    }
    for (var i = _parsed.blocks.length - 1; i >= 0; i--) {
      if (_parsed.blocks[i].startLine < currentLine) return i;
    }
    return 0;
  }

  /// Compare / 手动编辑：交给完整编辑器（带语法高亮、折叠、LSP）
  Future<void> _openInEditor() async {
    final tabProvider = context.read<TabProvider>();
    await tabProvider.reloadTabFromDisk(widget.file.absolutePath);
    await tabProvider.openFile(widget.file.absolutePath);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveAndMark() async {
    final l10n = AppLocalizations.of(context)!;

    // 防线：仍有标记时不允许静默标记 —— 那会把标记当作正常内容提交
    final remaining = _parsed.blocks.length;
    if (remaining > 0) {
      final stillMark = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(dialogCtx).colorScheme.error,
          ),
          title: Text(l10n.gitConflictMarkWithMarkers(remaining)),
          content: Text(l10n.gitConflictMarkWithMarkersHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.gitConflictGoResolve),
            ),
            FilledButton(
              key: const ValueKey('git_conflict_mark_anyway'),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.gitConflictMarkAnyway),
            ),
          ],
        ),
      );
      if (stillMark != true || !mounted) return;
    }

    try {
      await FileService.instance.saveFile(widget.file.absolutePath, _content);
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, e.toString(), type: ToastType.error);
      return;
    }

    final res = await widget.gitProvider.markConflictResolved(widget.file);
    if (!mounted) return;

    if (res.success) {
      DialogUtils.showToast(
        context,
        l10n.gitConflictSaveAndMarkDone,
        type: ToastType.success,
      );
      Navigator.of(context).pop();
    } else {
      DialogUtils.showToast(
        context,
        res.stderr.isNotEmpty ? res.stderr : l10n.gitConflictLoadFailed,
        type: ToastType.error,
      );
    }
  }

  // ---------------------------- 渲染 ----------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final editorTheme = _editorTheme;
    final remaining = _parsed.blocks.length;

    return Scaffold(
      backgroundColor: editorTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: editorTheme.backgroundColor,
        foregroundColor: editorTheme.textColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.basename(widget.file.relativePath),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: editorTheme.textColor,
              ),
            ),
            Text(
              widget.file.relativePath,
              style: TextStyle(
                fontSize: 10.5,
                color: editorTheme.gutterTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (!_isLoading && remaining > 0) ...[
            IconButton(
              tooltip: l10n.gitConflictPrev,
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              onPressed: () => _scrollToBlock(_nearestBlock(-1)),
            ),
            IconButton(
              tooltip: l10n.gitConflictNext,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              onPressed: () => _scrollToBlock(_nearestBlock(1)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  l10n.gitConflictUnresolvedRemain(remaining),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: _buildBody(theme, l10n, editorTheme),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    AppLocalizations l10n,
    EditorTheme editorTheme,
  ) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.gitConflictLoadFailed,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: editorTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: editorTheme.gutterTextColor,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                child: Text(l10n.gitRepairCheckRerun),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildEditorArea(theme, l10n, editorTheme)),
        _buildBottomBar(l10n, editorTheme),
      ],
    );
  }

  /// 只读行渲染区：行号栏固定 + 代码区全向滚动 + 双指缩放
  Widget _buildEditorArea(
    ThemeData theme,
    AppLocalizations l10n,
    EditorTheme editorTheme,
  ) {
    final fontSize = _effectiveFontSize;
    final rowHeight = _rowHeight;
    final charW = fontSize * 0.62;
    final gutterBg =
        editorTheme.gutterBackgroundColor ?? editorTheme.backgroundColor;
    final dividerColor = editorTheme.gutterTextColor.withValues(alpha: 0.25);

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth;
              final digits = '${_lines.length}'.length;
              final signW = (charW + 4.0).clamp(14.0, 36.0);
              final gutterWidth = math.max(46.0, digits * charW + signW + 14.0);
              final hasCodeArea = viewportWidth > gutterWidth + 1;
              final actualGutter = hasCodeArea
                  ? gutterWidth
                  : math.max(0.0, viewportWidth - 1.0);

              int maxChars = 0;
              for (final l in _lines) {
                if (l.text.length > maxChars) maxChars = l.text.length;
              }
              final codeAvailable = math.max(
                10.0,
                viewportWidth - gutterWidth - 1,
              );
              final maxCodeWidth = math.max(
                codeAvailable,
                maxChars * charW + 240.0,
              );

              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _handlePointerDown(e, fontSize),
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (actualGutter > 0)
                      SizedBox(
                        width: actualGutter,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: 0,
                            maxWidth: gutterWidth,
                            child: SizedBox(
                              width: gutterWidth,
                              child: Container(
                                color: gutterBg,
                                child: ListView.builder(
                                  controller: _gutterController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _lines.length,
                                  itemExtent: rowHeight,
                                  padding: const EdgeInsets.only(bottom: 240),
                                  itemBuilder: (ctx, i) => _buildGutterRow(
                                    _lines[i],
                                    rowHeight,
                                    fontSize,
                                    editorTheme,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (viewportWidth >= 1)
                      Container(width: 1.0, color: dividerColor),
                    if (hasCodeArea)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _hController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: maxCodeWidth,
                            child: ListView.builder(
                              controller: _vController,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _lines.length,
                              itemExtent: rowHeight,
                              padding: const EdgeInsets.only(bottom: 240),
                              itemBuilder: (ctx, i) => _buildCodeRow(
                                _lines[i],
                                rowHeight,
                                fontSize,
                                editorTheme,
                                l10n,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_showZoomBadge) _buildZoomBadge(editorTheme, fontSize),
      ],
    );
  }

  /// 行号栏单行：行号 + 冲突段符号（当前侧 `+` 绿、传入侧 `~` 蓝）
  Widget _buildGutterRow(
    ConflictLine line,
    double rowHeight,
    double fontSize,
    EditorTheme editorTheme,
  ) {
    final sign = switch (line.role) {
      ConflictLineRole.oursContent => '+',
      ConflictLineRole.theirsContent => '~',
      _ => '',
    };
    final signColor = switch (line.role) {
      ConflictLineRole.oursContent => const Color(0xFF3FB950),
      ConflictLineRole.theirsContent => const Color(0xFF58A6FF),
      _ => editorTheme.gutterTextColor,
    };
    final charW = fontSize * 0.62;
    final signW = (charW + 4.0).clamp(14.0, 36.0);

    return Container(
      height: rowHeight,
      color: _rowBackground(line.role, editorTheme.isDark),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${line.lineNumber}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: (fontSize - 1).clamp(
                  SettingsProvider.minFontSize - 1.0,
                  SettingsProvider.maxFontSize + 8.0,
                ),
                fontFamily: 'JetBrains Mono',
                height: 1.4,
                color: sign.isEmpty ? editorTheme.gutterTextColor : signColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: signW,
            child: Center(
              child: Text(
                sign,
                style: TextStyle(
                  fontSize: (fontSize - 1).clamp(
                    SettingsProvider.minFontSize - 1.0,
                    SettingsProvider.maxFontSize + 8.0,
                  ),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono',
                  height: 1.4,
                  color: signColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 代码区单行：按角色渲染
  Widget _buildCodeRow(
    ConflictLine line,
    double rowHeight,
    double fontSize,
    EditorTheme editorTheme,
    AppLocalizations l10n,
  ) {
    if (line.isHeader) {
      return _buildHeaderBand(line, rowHeight, fontSize, editorTheme, l10n);
    }
    if (line.role == ConflictLineRole.separator) {
      return Container(
        height: rowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 6, right: 160),
        child: Container(
          height: 3,
          color: editorTheme.gutterTextColor.withValues(alpha: 0.55),
        ),
      );
    }

    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: _editorFont.fontFamily,
      fontFamilyFallback: _editorFont.fallback,
      height: 1.4,
      color: editorTheme.textColor,
    );

    return Container(
      height: rowHeight,
      color: _rowBackground(line.role, editorTheme.isDark),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 6.0, right: 160.0),
      child: Text.rich(
        _highlight(line.text, baseStyle, editorTheme, fontSize),
        overflow: TextOverflow.visible,
        softWrap: false,
      ),
    );
  }

  /// 冲突标记行 → 色带标题（含内联操作）
  Widget _buildHeaderBand(
    ConflictLine line,
    double rowHeight,
    double fontSize,
    EditorTheme editorTheme,
    AppLocalizations l10n,
  ) {
    final isCurrent = line.role == ConflictLineRole.oursHeader;
    final isIncoming = line.role == ConflictLineRole.theirsHeader;

    final bandColor = isCurrent
        ? const Color(0xFF3FB950)
        : (isIncoming ? const Color(0xFF58A6FF) : const Color(0xFF8B949E));

    // 保留 git 原始标记文本，并补上"哪一侧"的说明
    final suffix = isCurrent
        ? '  (${l10n.gitConflictSectionOurs})'
        : (isIncoming ? '  (${l10n.gitConflictSectionTheirs})' : '');
    final blockIndex = line.blockIndex ?? 0;

    return Container(
      constraints: BoxConstraints(minHeight: rowHeight),
      color: bandColor.withValues(alpha: editorTheme.isDark ? 0.30 : 0.22),
      padding: const EdgeInsets.only(left: 6, right: 8, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${line.text}$suffix',
            style: TextStyle(
              fontSize: fontSize - 0.5,
              fontFamily: _editorFont.fontFamily,
              fontFamilyFallback: _editorFont.fallback,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: bandColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 基线段仅作参考，不提供操作
          if (isCurrent || isIncoming)
            _buildInlineActions(blockIndex, fontSize, editorTheme, l10n),
        ],
      ),
    );
  }

  /// 内联操作行（VS Code 命名固定，不随所在侧变化）
  Widget _buildInlineActions(
    int blockIndex,
    double fontSize,
    EditorTheme editorTheme,
    AppLocalizations l10n,
  ) {
    const actionColor = Color(0xFF58A6FF);
    final s = (fontSize - 1.5).clamp(9.0, 16.0);

    Widget action(String label, VoidCallback onTap, String keySuffix) {
      return InkWell(
        key: ValueKey('git_conflict_${keySuffix}_$blockIndex'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            label,
            style: TextStyle(
              fontSize: s,
              color: actionColor,
              fontFamily: _editorFont.fontFamily,
              decoration: TextDecoration.underline,
              decorationColor: actionColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    Widget sep() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: s,
          color: editorTheme.gutterTextColor.withValues(alpha: 0.7),
        ),
      ),
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        action(
          l10n.gitConflictAcceptCurrent,
          () => _acceptCurrent(blockIndex),
          'accept_current',
        ),
        sep(),
        action(
          l10n.gitConflictAcceptIncoming,
          () => _acceptIncoming(blockIndex),
          'accept_incoming',
        ),
        sep(),
        action(
          l10n.gitConflictAcceptBoth,
          () => _acceptBoth(blockIndex),
          'accept_both',
        ),
        sep(),
        action(l10n.gitConflictCompare, _openInEditor, 'compare'),
      ],
    );
  }

  TextSpan _highlight(
    String code,
    TextStyle baseStyle,
    EditorTheme editorTheme,
    double fontSize,
  ) {
    if (code.isEmpty) return TextSpan(text: '', style: baseStyle);
    final key = '$fontSize-${editorTheme.id}-$code';
    final cached = _highlightCache[key];
    if (cached != null) return cached;
    final span = SyntaxHighlightHelper.highlightLine(
      code: code,
      filePath: widget.file.relativePath,
      baseStyle: baseStyle,
      highlightTheme: editorTheme.highlightTheme,
    );
    _highlightCache[key] = span;
    return span;
  }

  /// 整段底色：当前侧绿、传入侧蓝、基线灰（与 VS Code 一致）
  Color? _rowBackground(ConflictLineRole role, bool isDark) {
    return switch (role) {
      ConflictLineRole.oursContent => const Color(
        0xFF3FB950,
      ).withValues(alpha: isDark ? 0.18 : 0.13),
      ConflictLineRole.theirsContent => const Color(
        0xFF58A6FF,
      ).withValues(alpha: isDark ? 0.18 : 0.13),
      ConflictLineRole.baseContent => const Color(
        0xFF8B949E,
      ).withValues(alpha: isDark ? 0.10 : 0.08),
      _ => null,
    };
  }

  Widget _buildZoomBadge(EditorTheme editorTheme, double fontSize) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: editorTheme.backgroundColor.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: editorTheme.gutterTextColor.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '${fontSize.toStringAsFixed(1)}pt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: editorTheme.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, EditorTheme editorTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: editorTheme.gutterBackgroundColor ?? editorTheme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: editorTheme.gutterTextColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('git_conflict_edit_manually'),
                onPressed: _openInEditor,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(
                  l10n.gitConflictEditManually,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey('git_conflict_save_and_mark'),
                onPressed: _saveAndMark,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  l10n.gitConflictSaveAndMark,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------- 手势（Listener 原生指针跟踪） ----------------------------

  void _handlePointerDown(PointerDownEvent event, double fontSize) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2 && !_isPinching) {
      final keys = _pointers.keys.toList();
      _pointer1 = keys[0];
      _pointer2 = keys[1];
      final p1 = _pointers[_pointer1]!;
      final p2 = _pointers[_pointer2]!;
      _initialDistance = (p1 - p2).distance;
      _initialFontSize = fontSize;
      _isPinching = true;
      _lastPanPos = null;
      setState(() => _showZoomBadge = true);
    } else if (_pointers.length == 1) {
      _lastPanPos = event.position;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_isPinching && _pointer1 != null && _pointer2 != null) {
      final p1 = _pointers[_pointer1];
      final p2 = _pointers[_pointer2];
      if (p1 == null || p2 == null || _initialDistance == null) return;
      if (_initialDistance! <= 0) return;

      final ratio = (p1 - p2).distance / _initialDistance!;
      final base = _initialFontSize ?? _baseFontSize;
      final target = (base * ratio).clamp(
        SettingsProvider.minFontSize.toDouble(),
        SettingsProvider.maxFontSize.toDouble(),
      );

      final oldRowHeight = _rowHeight;
      setState(() => _activeZoomFontSize = target);
      final newRowHeight = _rowHeight;

      // 以双指中心为锚点，避免缩放时内容跳动
      if (_vController.hasClients && oldRowHeight > 0) {
        final focalDy = ((p1 + p2) / 2).dy;
        final lineUnderFocal = (focalDy + _vController.offset) / oldRowHeight;
        final desired = lineUnderFocal * newRowHeight - focalDy;
        _vController.jumpTo(
          desired.clamp(
            _vController.position.minScrollExtent,
            _vController.position.maxScrollExtent,
          ),
        );
      }
      return;
    }

    // 单指平移：垂直 + 水平
    if (_lastPanPos != null && !_isPinching) {
      final delta = event.position - _lastPanPos!;
      _lastPanPos = event.position;
      if (_vController.hasClients) {
        _vController.jumpTo(
          (_vController.offset - delta.dy).clamp(
            _vController.position.minScrollExtent,
            _vController.position.maxScrollExtent,
          ),
        );
      }
      if (_hController.hasClients) {
        _hController.jumpTo(
          (_hController.offset - delta.dx).clamp(
            _hController.position.minScrollExtent,
            _hController.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _isPinching) _finishPinch();
    if (_pointers.isEmpty) _lastPanPos = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _isPinching) _finishPinch();
    if (_pointers.isEmpty) _lastPanPos = null;
  }

  void _finishPinch() {
    _isPinching = false;
    _pointer1 = null;
    _pointer2 = null;
    _initialDistance = null;
    final zoomed = _activeZoomFontSize;
    setState(() {
      if (zoomed != null) _committedFontSize = zoomed;
      _activeZoomFontSize = null;
      _showZoomBadge = false;
    });
  }
}
