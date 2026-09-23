import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import '../../utils/file_icon_utils.dart';
import '../../utils/git_conflict_parser.dart';
import '../../utils/git_diff_helper.dart';
import '../../utils/syntax_highlight_helper.dart';
import '../../views/main_view.dart';
import 'conflict_view_model.dart';

/// Git 冲突解决页面（VS Code 风格重制版）
///
/// 视觉与交互完全对齐 VS Code 内联冲突（Inline Merge Conflict）规范，
/// 页面全局主题与代码区主题严格继承并遵循 `GitDiffPage` 规范：
/// - AppBar：遵循应用标准 Material 3 配色，展示文件图标、路径、冲突徽标与导航工具栏
/// - CodeLens 悬浮操作胶囊：在冲突块顶部提供「采用当前」、「采用传入」、「保留双方」、「对比查看」
/// - 视觉分块：当前侧（绿）、分隔线（居中）、传入侧（蓝）、基线侧（灰）带语义色带与软背景
/// - 高度与对齐：行号区与代码区高度严格同步，彻底根除行号错位与渲染截断 Bug
/// - 纯手势体验：支持基于原生指针跟踪的平滑单指平移、双指中心锚定缩放、浮动字号气泡与惯性滑动
/// - 高级功能：支持「对比查看 (Compare Changes)」差异弹窗、重置回初始冲突、批量采用
class GitConflictResolvePage extends StatefulWidget {
  const GitConflictResolvePage({
    super.key,
    required this.file,
    required this.gitProvider,
    this.initialContent,
  });

  final GitConflictedFile file;
  final GitProvider gitProvider;
  final String? initialContent;

  static Route<void> route({
    required GitConflictedFile file,
    required GitProvider gitProvider,
    String? initialContent,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => GitConflictResolvePage(
        file: file,
        gitProvider: gitProvider,
        initialContent: initialContent,
      ),
    );
  }

  @override
  State<GitConflictResolvePage> createState() => _GitConflictResolvePageState();
}

class _GitConflictResolvePageState extends State<GitConflictResolvePage> {
  bool _isLoading = true;
  String? _errorMessage;

  /// 进入页面时从磁盘读取的初始冲突内容（用于重置）
  String _initialContent = '';

  /// 当前工作内容（\n 规范化）
  String _content = '';
  GitConflictParseResult _parsed = GitConflictParseResult.none;
  List<ConflictLine> _lines = const [];

  // 当前定位冲突块索引
  int _currentBlockIndex = 0;

  // 垂直 / 水平 / 行号独立滚动控制器（分工与 GitDiffPage 一致）
  late final ScrollController _vController;
  late final ScrollController _hController;
  late final ScrollController _gutterController;
  bool _syncing = false;

  // 缩放字号状态
  double? _splitFontSize;
  double? _activeZoomFontSize;

  // 双指平滑缩放手势跟踪状态（对标 GitDiffPage）
  final Map<int, Offset> _pointers = {};
  int? _pointer1;
  int? _pointer2;
  double? _initialDistance;
  double? _initialFontSize;
  Offset? _initialLocalFocal;
  Offset? _currentLocalFocal;
  double _focalLineContinuous = 0.0;
  double _focalCharContinuous = 0.0;
  bool _isPinching = false;
  Offset? _lastPanPos;
  VelocityTracker? _velocityTracker;

  // 用户正在与 CodeLens 栏交互（左右拖动查看操作按钮，避免触发主代码区单指平移）
  bool _isInteractingWithCodeLens = false;

  // 语法高亮缓存 (key: '$fontSize-${editorTheme.id}-$code')
  final Map<String, TextSpan> _highlightSpanCache = {};

  static const double _codeLensBarHeight = 32.0;

  @override
  void initState() {
    super.initState();
    _vController = ScrollController();
    _hController = ScrollController();
    _gutterController = ScrollController();

    _vController.addListener(_onVerticalScrolled);
    _gutterController.addListener(_onGutterScrolled);

    if (widget.initialContent != null) {
      final normalized = widget.initialContent!.replaceAll('\r\n', '\n');
      _initialContent = normalized;
      _content = normalized;
      _parsed = GitConflictParser.parse(normalized);
      _lines = ConflictLineBuilder.build(normalized, _parsed);
      _isLoading = false;
    } else {
      _loadFromDisk(isInitial: true);
    }
  }

  @override
  void dispose() {
    _vController.removeListener(_onVerticalScrolled);
    _gutterController.removeListener(_onGutterScrolled);
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
        0.0,
        _gutterController.position.maxScrollExtent,
      ),
    );
    _syncing = false;
  }

  void _onGutterScrolled() {
    if (_syncing || !_vController.hasClients) return;
    _syncing = true;
    _vController.jumpTo(
      _gutterController.offset.clamp(
        0.0,
        _vController.position.maxScrollExtent,
      ),
    );
    _syncing = false;
  }

  // ---------------------------- 数据加载与冲突操作 ----------------------------

  Future<void> _loadFromDisk({bool isInitial = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final raw = await FileService.instance.readFileContent(
        widget.file.absolutePath,
      );
      final normalized = raw.replaceAll('\r\n', '\n');
      final parsed = GitConflictParser.parse(normalized);
      final lines = ConflictLineBuilder.build(normalized, parsed);

      if (!mounted) return;
      setState(() {
        if (isInitial || _initialContent.isEmpty) {
          _initialContent = normalized;
        }
        _content = normalized;
        _parsed = parsed;
        _lines = lines;
        _currentBlockIndex = parsed.blocks.isNotEmpty ? 0 : 0;
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

  /// 获取某冲突块某角色的文本
  String _segmentText(int blockIndex, ConflictLineRole side) {
    if (blockIndex < 0 || blockIndex >= _parsed.blocks.length) return '';
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

  /// 替换指定冲突块并同步到磁盘
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

    final parsed = GitConflictParser.parse(newContent);
    setState(() {
      _content = newContent;
      _parsed = parsed;
      _lines = ConflictLineBuilder.build(newContent, parsed);
      if (_currentBlockIndex >= parsed.blocks.length) {
        _currentBlockIndex = math.max(0, parsed.blocks.length - 1);
      }
    });
  }

  /// 采用当前侧更改
  Future<void> _acceptCurrent(int blockIndex) async {
    await _applyBlock(
      blockIndex,
      _segmentText(blockIndex, ConflictLineRole.oursContent),
    );
  }

  /// 采用传入侧更改
  Future<void> _acceptIncoming(int blockIndex) async {
    await _applyBlock(
      blockIndex,
      _segmentText(blockIndex, ConflictLineRole.theirsContent),
    );
  }

  /// 保留两段更改
  Future<void> _acceptBoth(int blockIndex) async {
    final current = _segmentText(blockIndex, ConflictLineRole.oursContent);
    final incoming = _segmentText(blockIndex, ConflictLineRole.theirsContent);
    final combined = [current, incoming].where((s) => s.isNotEmpty).join('\n');
    await _applyBlock(blockIndex, combined);
  }

  /// 全部采用当前更改
  Future<void> _acceptAllCurrent() async {
    if (_parsed.blocks.isEmpty) return;
    for (var i = _parsed.blocks.length - 1; i >= 0; i--) {
      await _acceptCurrent(i);
    }
  }

  /// 全部采用传入更改
  Future<void> _acceptAllIncoming() async {
    if (_parsed.blocks.isEmpty) return;
    for (var i = _parsed.blocks.length - 1; i >= 0; i--) {
      await _acceptIncoming(i);
    }
  }

  /// 重置为初始冲突状态
  Future<void> _resetToInitial() async {
    if (_initialContent.isEmpty) return;
    try {
      await FileService.instance.saveFile(
        widget.file.absolutePath,
        _initialContent,
      );
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, e.toString(), type: ToastType.error);
      return;
    }
    if (!mounted) return;

    final parsed = GitConflictParser.parse(_initialContent);
    setState(() {
      _content = _initialContent;
      _parsed = parsed;
      _lines = ConflictLineBuilder.build(_initialContent, parsed);
      _currentBlockIndex = 0;
    });
    DialogUtils.showToast(
      context,
      '已重置为初始冲突标记状态',
      type: ToastType.info,
    );
  }

  /// 计算指定冲突块或行的垂直像素位置（行号与代码行绝对像素级同步）
  double _calculateLineTopOffset(int lineIndex, double baseRowHeight) {
    double offset = 0.0;
    for (int i = 0; i < lineIndex && i < _lines.length; i++) {
      offset += _getLineHeight(_lines[i], baseRowHeight);
    }
    return offset;
  }

  /// 平滑滚动到指定冲突块
  Future<void> _scrollToBlock(
    int blockIndex,
    double baseRowHeight,
  ) async {
    if (blockIndex < 0 || blockIndex >= _parsed.blocks.length) return;
    if (!_vController.hasClients) return;

    setState(() => _currentBlockIndex = blockIndex);

    final targetLine = _parsed.blocks[blockIndex].startLine;
    final targetY = _calculateLineTopOffset(targetLine, baseRowHeight);
    final maxScroll = _vController.position.maxScrollExtent;
    final clamped = (targetY - 40.0).clamp(0.0, maxScroll);

    await _vController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateToNextBlock(double baseRowHeight) {
    if (_parsed.blocks.isEmpty) return;
    final nextIndex = (_currentBlockIndex + 1) % _parsed.blocks.length;
    _scrollToBlock(nextIndex, baseRowHeight);
  }

  void _navigateToPrevBlock(double baseRowHeight) {
    if (_parsed.blocks.isEmpty) return;
    final prevIndex =
        (_currentBlockIndex - 1 + _parsed.blocks.length) % _parsed.blocks.length;
    _scrollToBlock(prevIndex, baseRowHeight);
  }

  /// 在完整编辑器中打开并手动编辑
  Future<void> _openInEditor() async {
    final tabProvider = context.read<TabProvider>();
    await tabProvider.reloadTabFromDisk(widget.file.absolutePath);
    await tabProvider.openFile(widget.file.absolutePath);
    if (!mounted) return;
    // 1. 一路关闭全屏冲突页及底下的下拉菜单/冲突面板，回到主页面
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    // 2. 关闭主界面侧边栏抽屉，直达代码编辑区
    MainView.closeDrawerIfOpen();
  }

  /// 保存并标记为已解决
  Future<void> _saveAndMark() async {
    final l10n = AppLocalizations.of(context)!;
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

  // ---------------------------- 比较查看 (Compare Changes) 弹窗 ----------------------------

  void _showCompareDialog(
    int blockIndex,
    EditorTheme editorTheme,
    AppFontItem editorFont,
    double fontSize,
  ) {
    if (blockIndex < 0 || blockIndex >= _parsed.blocks.length) return;
    final block = _parsed.blocks[blockIndex];
    final oursText = _segmentText(blockIndex, ConflictLineRole.oursContent);
    final theirsText = _segmentText(blockIndex, ConflictLineRole.theirsContent);

    final split = GitDiffHelper.computeSplitDiff(oursText, theirsText);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ConflictCompareDialog(
        blockIndex: blockIndex,
        oursLabel: block.oursLabel.isNotEmpty ? block.oursLabel : '当前侧 (Current)',
        theirsLabel: block.theirsLabel.isNotEmpty ? block.theirsLabel : '传入侧 (Incoming)',
        oursText: oursText,
        theirsText: theirsText,
        splitDiff: split,
        editorTheme: editorTheme,
        editorFont: editorFont,
        fontSize: fontSize,
        onAcceptCurrent: () {
          Navigator.of(dialogCtx).pop();
          _acceptCurrent(blockIndex);
        },
        onAcceptIncoming: () {
          Navigator.of(dialogCtx).pop();
          _acceptIncoming(blockIndex);
        },
        onAcceptBoth: () {
          Navigator.of(dialogCtx).pop();
          _acceptBoth(blockIndex);
        },
      ),
    );
  }

  // ---------------------------- 手势与平滑缩放管理 (与 GitDiffPage 规范一致) ----------------------------

  void _handlePointerDown(
    PointerDownEvent event,
    double currentFontSize,
    double rowH,
    double charW,
  ) {
    if (_isInteractingWithCodeLens) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 1) {
      _lastPanPos = event.position;
      _velocityTracker = VelocityTracker.withKind(event.kind);
      _velocityTracker?.addPosition(event.timeStamp, event.position);
    } else if (_pointers.length >= 2 && !_isPinching) {
      final keys = _pointers.keys.toList();
      _pointer1 = keys[0];
      _pointer2 = keys[1];

      final p1 = _pointers[_pointer1]!;
      final p2 = _pointers[_pointer2]!;

      _initialDistance = (p1 - p2).distance;
      _initialFontSize = _activeZoomFontSize ?? currentFontSize;
      _activeZoomFontSize = _initialFontSize;

      final globalFocal = (p1 + p2) / 2;
      final renderBox = context.findRenderObject() as RenderBox?;
      final localFocal =
          renderBox != null ? renderBox.globalToLocal(globalFocal) : globalFocal;
      _initialLocalFocal = localFocal;

      final curV = _vController.hasClients ? _vController.offset : 0.0;
      final curH = _hController.hasClients ? _hController.offset : 0.0;

      _focalLineContinuous = (curV + localFocal.dy) / math.max(1.0, rowH);
      _focalCharContinuous = curH <= 4.0 ? 0.0 : curH / math.max(1.0, charW);

      _lastPanPos = null;
      setState(() => _isPinching = true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isInteractingWithCodeLens) return;
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_isPinching) {
      if (_pointer1 != null &&
          _pointer2 != null &&
          _pointers.containsKey(_pointer1) &&
          _pointers.containsKey(_pointer2) &&
          _initialDistance != null &&
          _initialDistance! > 10.0 &&
          _initialFontSize != null &&
          _initialLocalFocal != null) {
        final p1 = _pointers[_pointer1]!;
        final p2 = _pointers[_pointer2]!;

        final currentDistance = (p1 - p2).distance;
        final rawScale = currentDistance / _initialDistance!;

        final minScale = SettingsProvider.minFontSize / _initialFontSize!;
        final maxScale = SettingsProvider.maxFontSize / _initialFontSize!;
        final clampedScale = rawScale.clamp(minScale * 0.9, maxScale * 1.1);

        final continuousFontSize =
            ((_initialFontSize! * clampedScale) * 10).round() / 10.0;
        final newFontSize = continuousFontSize.clamp(
          SettingsProvider.minFontSize,
          SettingsProvider.maxFontSize,
        );

        final newRowH = (newFontSize * 1.45 + 4.0).roundToDouble();
        final newCharW = newFontSize * 0.60;

        final currentGlobalFocal = (p1 + p2) / 2;
        final renderBox = context.findRenderObject() as RenderBox?;
        final currentLocalFocal = renderBox != null
            ? renderBox.globalToLocal(currentGlobalFocal)
            : currentGlobalFocal;
        _currentLocalFocal = currentLocalFocal;

        final targetScrollV =
            _focalLineContinuous * newRowH - currentLocalFocal.dy;
        final targetScrollH = _focalCharContinuous <= 0.0
            ? 0.0
            : _focalCharContinuous * newCharW;

        _syncing = true;
        if (_vController.hasClients) {
          final maxV = _vController.position.maxScrollExtent;
          final clampedV =
              targetScrollV.clamp(0.0, math.max(maxV, targetScrollV)).toDouble();
          _vController.jumpTo(clampedV);
          if (_gutterController.hasClients) _gutterController.jumpTo(clampedV);
        }
        if (_hController.hasClients) {
          final maxH = _hController.position.maxScrollExtent;
          final clampedH =
              targetScrollH.clamp(0.0, math.max(maxH, targetScrollH)).toDouble();
          _hController.jumpTo(clampedH);
        }
        _syncing = false;

        if (_splitFontSize != newFontSize) {
          setState(() {
            _splitFontSize = newFontSize;
            _activeZoomFontSize = newFontSize;
          });
        }
      }
    } else if (_pointers.length == 1 && !_isPinching) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      final curPos = event.position;
      if (_lastPanPos != null) {
        final delta = curPos - _lastPanPos!;
        _syncing = true;
        if (_vController.hasClients) {
          final maxV = _vController.position.maxScrollExtent;
          final newV = (_vController.offset - delta.dy).clamp(0.0, maxV);
          _vController.jumpTo(newV);
          if (_gutterController.hasClients) _gutterController.jumpTo(newV);
        }
        if (_hController.hasClients) {
          final maxH = _hController.position.maxScrollExtent;
          final newH = (_hController.offset - delta.dx).clamp(0.0, maxH);
          _hController.jumpTo(newH);
        }
        _syncing = false;
      }
      _lastPanPos = curPos;
    }
  }

  void _finishPinchZoom() {
    final finalSize = _activeZoomFontSize;
    if (finalSize != null) {
      final double targetFontSize = finalSize
          .clamp(
            SettingsProvider.minFontSize,
            SettingsProvider.maxFontSize,
          )
          .roundToDouble();
      _splitFontSize = targetFontSize;
      final finalH = (targetFontSize * 1.45 + 4.0).roundToDouble();
      final finalW = targetFontSize * 0.60;
      final currentLocalFocal = _currentLocalFocal ?? _initialLocalFocal;
      if (currentLocalFocal != null) {
        final targetScrollV =
            _focalLineContinuous * finalH - currentLocalFocal.dy;
        final targetScrollH = _focalCharContinuous <= 0.0
            ? 0.0
            : _focalCharContinuous * finalW;
        _syncing = true;
        if (_vController.hasClients) {
          final maxV = _vController.position.maxScrollExtent;
          final clampedV =
              targetScrollV.clamp(0.0, math.max(maxV, targetScrollV)).toDouble();
          _vController.jumpTo(clampedV);
          if (_gutterController.hasClients) _gutterController.jumpTo(clampedV);
        }
        if (_hController.hasClients) {
          final maxH = _hController.position.maxScrollExtent;
          final clampedH =
              targetScrollH.clamp(0.0, math.max(maxH, targetScrollH)).toDouble();
          _hController.jumpTo(clampedH);
        }
        _syncing = false;
      }
    }
    setState(() {
      _isPinching = false;
      _pointer1 = null;
      _pointer2 = null;
      _initialDistance = null;
      _initialFontSize = null;
      _activeZoomFontSize = null;
      _initialLocalFocal = null;
      _currentLocalFocal = null;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_isInteractingWithCodeLens) {
      _isInteractingWithCodeLens = false;
      _lastPanPos = null;
      return;
    }
    if (_isPinching &&
        (_pointers.length < 2 ||
            event.pointer == _pointer1 ||
            event.pointer == _pointer2)) {
      _finishPinchZoom();
    } else if (!_isPinching && _pointers.isEmpty) {
      if (_velocityTracker != null) {
        final estimate = _velocityTracker!.getVelocity();
        final velocity = estimate.pixelsPerSecond;
        if (velocity.dy.abs() > 60 && _vController.hasClients) {
          final maxV = _vController.position.maxScrollExtent;
          final targetV =
              (_vController.offset - velocity.dy * 0.22).clamp(0.0, maxV);
          _vController.animateTo(
            targetV,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        if (velocity.dx.abs() > 60 && _hController.hasClients) {
          final maxH = _hController.position.maxScrollExtent;
          final targetH =
              (_hController.offset - velocity.dx * 0.22).clamp(0.0, maxH);
          _hController.animateTo(
            targetH,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
      _lastPanPos = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_isInteractingWithCodeLens) {
      _isInteractingWithCodeLens = false;
      _lastPanPos = null;
      return;
    }
    if (_isPinching) {
      _finishPinchZoom();
    }
    _lastPanPos = null;
  }

  Widget _buildZoomBadge(EditorTheme editorTheme, double fontSize) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: editorTheme.isDark
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${fontSize.toStringAsFixed(1)} pt',
            style: TextStyle(
              color: editorTheme.isDark ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------- 语法高亮缓存 ----------------------------

  TextSpan _getHighlightedLineSpan({
    required String code,
    required TextStyle baseStyle,
    required EditorTheme editorTheme,
  }) {
    if (code.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }
    final key = '${baseStyle.fontSize}-${editorTheme.id}-$code';
    final cached = _highlightSpanCache[key];
    if (cached != null) return cached;

    final span = SyntaxHighlightHelper.highlightLine(
      code: code,
      filePath: widget.file.relativePath,
      baseStyle: baseStyle,
      highlightTheme: editorTheme.highlightTheme,
    );
    _highlightSpanCache[key] = span;
    return span;
  }

  // ---------------------------- 核心 UI 构建 ----------------------------

  double _getLineHeight(ConflictLine line, double baseRowHeight) {
    // 冲突块开头标记行渲染 CodeLens 操作栏 + 标记行标题，其他行按 baseRowHeight
    if (line.role == ConflictLineRole.oursHeader) {
      return baseRowHeight + _codeLensBarHeight;
    }
    return baseRowHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // 获取独立的代码编辑器主题与默认字号配置（对齐 GitDiffPage）
    EditorTheme editorTheme = EditorTheme.atomOneDark;
    double baseFontSize = 14.0;
    AppFontItem editorFont = AppFonts.editorJetBrainsMono;
    try {
      final settings = context.watch<SettingsProvider>();
      editorTheme = settings.editorTheme;
      baseFontSize = settings.fontSize;
      editorFont = settings.editorFont;
    } catch (_) {}

    final displayFontSize =
        _activeZoomFontSize ?? _splitFontSize ?? baseFontSize;
    final baseRowHeight = (displayFontSize * 1.45 + 4.0).roundToDouble();
    final remainingConflicts = _parsed.blocks.length;

    final fileName = p.basename(widget.file.relativePath);
    final dirPath = p.dirname(widget.file.relativePath);

    return Scaffold(
      backgroundColor: editorTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(
              FileIconUtils.getIcon(name: fileName, isDirectory: false),
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 冲突状态徽标（VS Code 风格）
                      if (!_isLoading) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _parsed.isMalformed
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 11,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          l10n.gitConflictMalformedBadge,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : (remainingConflicts > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer.withValues(
                                          alpha: 0.85,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        l10n.gitConflictUnresolvedBadge(remainingConflicts),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 11,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              l10n.gitConflictAllResolvedBadge,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                        ),
                      ],
                    ],
                  ),
                  if (dirPath != '.' && dirPath.isNotEmpty)
                    Text(
                      dirPath,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 上一处冲突
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: l10n.gitConflictPrev,
            onPressed: (!_isLoading && _parsed.blocks.isNotEmpty)
                ? () => _navigateToPrevBlock(baseRowHeight)
                : null,
          ),
          // 下一处冲突
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: l10n.gitConflictNext,
            onPressed: (!_isLoading && _parsed.blocks.isNotEmpty)
                ? () => _navigateToNextBlock(baseRowHeight)
                : null,
          ),
          // 更多操作下拉菜单
          PopupMenuButton<String>(
            tooltip: l10n.gitConflictMoreOptions,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (val) {
              switch (val) {
                case 'all_current':
                  _acceptAllCurrent();
                  break;
                case 'all_incoming':
                  _acceptAllIncoming();
                  break;
                case 'reset_initial':
                  _resetToInitial();
                  break;
                case 'reload_disk':
                  _loadFromDisk();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (remainingConflicts > 0) ...[
                PopupMenuItem(
                  value: 'all_current',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.gitConflictAllOurs),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'all_incoming',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.gitConflictAllTheirs),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'reset_initial',
                child: Row(
                  children: [
                    const Icon(Icons.restore_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(l10n.gitConflictResetToInitial),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reload_disk',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(l10n.gitConflictReloadFromDisk),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildBody(
              context: context,
              theme: theme,
              l10n: l10n,
              editorTheme: editorTheme,
              editorFont: editorFont,
              displayFontSize: displayFontSize,
              baseRowHeight: baseRowHeight,
            ),
          ),
          _buildBottomBar(context, l10n, editorTheme, remainingConflicts),
        ],
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required double displayFontSize,
    required double baseRowHeight,
  }) {
    if (_isLoading) {
      return Container(
        color: editorTheme.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: editorTheme.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 13, color: editorTheme.textColor),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _loadFromDisk(),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.gitRefresh),
              ),
            ],
          ),
        ),
      );
    }

    final gutterBg =
        editorTheme.gutterBackgroundColor ?? editorTheme.backgroundColor;
    final gutterDividerColor =
        editorTheme.gutterTextColor.withValues(alpha: 0.25);
    final displayCharWidth = displayFontSize * 0.60;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final viewportWidth = constraints.maxWidth;
        final totalLines = _lines.length;
        final digits = totalLines > 0 ? '$totalLines'.length : 1;
        final signW = (displayCharWidth + 4.0).clamp(14.0, 36.0);
        final gutterWidth =
            math.max(46.0, digits * displayCharWidth + signW + 14.0);

        final bool hasCodeArea = viewportWidth > (gutterWidth + 1.0);
        final double actualGutterWidth = hasCodeArea
            ? gutterWidth
            : math.max(0.0, viewportWidth - 1.0);
        final bool hasDivider = viewportWidth >= 1.0;

        int maxChars = 0;
        for (final l in _lines) {
          if (l.text.length > maxChars) maxChars = l.text.length;
        }
        final codeContentAvailableWidth =
            math.max(10.0, viewportWidth - gutterWidth - 1.0);
        final maxCodeWidth = math.max(
          codeContentAvailableWidth,
          maxChars * displayCharWidth + 240.0,
        );

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _handlePointerDown(
            e,
            displayFontSize,
            baseRowHeight,
            displayCharWidth,
          ),
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Stack(
            children: [
              // 1. 底层常驻背景与分割线（对标 GitDiffPage）
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (actualGutterWidth > 0)
                      Container(width: actualGutterWidth, color: gutterBg),
                    if (hasDivider)
                      Container(width: 1.0, color: gutterDividerColor),
                    if (hasCodeArea)
                      Expanded(
                        child: Container(color: editorTheme.backgroundColor),
                      ),
                  ],
                ),
              ),

              // 2. 主体视口内容
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 行号栏（与代码区高度严格同步，彻底消除错位）
                    if (actualGutterWidth > 0)
                      SizedBox(
                        width: actualGutterWidth,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: 0,
                            maxWidth: gutterWidth,
                            child: SizedBox(
                              width: gutterWidth,
                              child: ListView.builder(
                                controller: _gutterController,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _lines.length,
                                padding: const EdgeInsets.only(bottom: 240.0),
                                itemBuilder: (ctx, index) {
                                  return _buildGutterItem(
                                    line: _lines[index],
                                    editorTheme: editorTheme,
                                    editorFont: editorFont,
                                    fontSize: displayFontSize,
                                    baseRowHeight: baseRowHeight,
                                    signW: signW,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (hasDivider)
                      Container(width: 1.0, color: gutterDividerColor),

                    // 代码内容区（横向滚动支撑与垂直列表同步）
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
                              padding: const EdgeInsets.only(bottom: 240.0),
                              itemBuilder: (ctx, index) {
                                return _buildCodeItem(
                                  line: _lines[index],
                                  editorTheme: editorTheme,
                                  editorFont: editorFont,
                                  fontSize: displayFontSize,
                                  baseRowHeight: baseRowHeight,
                                  l10n: l10n,
                                  availableWidth: codeContentAvailableWidth,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 畸形冲突警告横幅
              if (_parsed.isMalformed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.92),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.gitConflictMalformedBanner,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 缩放实时字号悬浮胶囊
              if (_isPinching && _activeZoomFontSize != null)
                _buildZoomBadge(editorTheme, _activeZoomFontSize!),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------- 行号栏单元格构建 ----------------------------

  Widget _buildGutterItem({
    required ConflictLine line,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required double fontSize,
    required double baseRowHeight,
    required double signW,
  }) {
    final isDark = editorTheme.isDark;
    final rowHeight = _getLineHeight(line, baseRowHeight);

    // 冲突符号与高亮颜色（VS Code 规范）
    String sign = '';
    Color? signColor;
    if (line.isOurs) {
      sign = line.role == ConflictLineRole.oursHeader ? '!' : '+';
      signColor = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
    } else if (line.isTheirs) {
      sign = line.role == ConflictLineRole.theirsHeader ? '!' : '~';
      signColor = isDark ? const Color(0xFF58A6FF) : const Color(0xFF1976D2);
    } else if (line.isBase) {
      sign = '|';
      signColor = editorTheme.gutterTextColor;
    }

    final isOursHeader = line.role == ConflictLineRole.oursHeader;

    return Container(
      height: rowHeight,
      color: _getGutterBackgroundColor(line.role, isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 若为冲突起始行，顶部预留与 CodeLens 相同的 32px 高度并居中展示合并图标
          if (isOursHeader)
            Container(
              height: _codeLensBarHeight,
              alignment: Alignment.center,
              child: Icon(
                Icons.call_merge_rounded,
                size: 13,
                color: signColor?.withValues(alpha: 0.8),
              ),
            ),
          // 行号与符号展示区
          SizedBox(
            height: baseRowHeight,
            child: Padding(
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
                          SettingsProvider.maxFontSize,
                        ),
                        fontFamily: editorFont.fontFamily,
                        fontFamilyFallback: editorFont.fallback,
                        height: 1.4,
                        color: signColor ?? editorTheme.gutterTextColor,
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
                            SettingsProvider.maxFontSize,
                          ),
                          fontWeight: FontWeight.bold,
                          fontFamily: editorFont.fontFamily,
                          fontFamilyFallback: editorFont.fallback,
                          height: 1.4,
                          color: signColor ?? editorTheme.gutterTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------- 代码内容区单元格构建 ----------------------------

  Widget _buildCodeItem({
    required ConflictLine line,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required double fontSize,
    required double baseRowHeight,
    required AppLocalizations l10n,
    required double availableWidth,
  }) {
    final isDark = editorTheme.isDark;
    final rowHeight = _getLineHeight(line, baseRowHeight);

    // 1. 冲突标记行开头：渲染 CodeLens 操作栏 + 当前侧色带标头
    if (line.role == ConflictLineRole.oursHeader) {
      final blockIndex = line.blockIndex ?? 0;
      return SizedBox(
        height: rowHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _hController,
              builder: (ctx, child) {
                final scrollX =
                    _hController.hasClients ? _hController.offset : 0.0;
                return Padding(
                  padding: EdgeInsets.only(left: math.max(0.0, scrollX)),
                  child: child,
                );
              },
              child: _ConflictCodeLensBar(
                blockIndex: blockIndex,
                editorTheme: editorTheme,
                l10n: l10n,
                availableWidth: availableWidth,
                onTouchStart: () => _isInteractingWithCodeLens = true,
                onTouchEnd: () => _isInteractingWithCodeLens = false,
                onAcceptCurrent: () => _acceptCurrent(blockIndex),
                onAcceptIncoming: () => _acceptIncoming(blockIndex),
                onAcceptBoth: () => _acceptBoth(blockIndex),
                onCompare: () => _showCompareDialog(
                  blockIndex,
                  editorTheme,
                  editorFont,
                  fontSize,
                ),
              ),
            ),
            _buildOursHeaderBand(
              line: line,
              baseRowHeight: baseRowHeight,
              fontSize: fontSize,
              editorTheme: editorTheme,
              editorFont: editorFont,
              l10n: l10n,
            ),
          ],
        ),
      );
    }

    // 2. 传入侧标头色带
    if (line.role == ConflictLineRole.theirsHeader) {
      return _buildTheirsHeaderBand(
        line: line,
        baseRowHeight: baseRowHeight,
        fontSize: fontSize,
        editorTheme: editorTheme,
        editorFont: editorFont,
        l10n: l10n,
      );
    }

    // 3. 基线侧标头色带
    if (line.role == ConflictLineRole.baseHeader) {
      return _buildBaseHeaderBand(
        line: line,
        baseRowHeight: baseRowHeight,
        fontSize: fontSize,
        editorTheme: editorTheme,
        editorFont: editorFont,
        l10n: l10n,
      );
    }

    // 4. 分隔线 (=======)
    if (line.role == ConflictLineRole.separator) {
      return _buildSeparatorLine(
        baseRowHeight: baseRowHeight,
        editorTheme: editorTheme,
      );
    }

    // 5. 普通上下文行或冲突内容行
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: editorFont.fontFamily,
      fontFamilyFallback: editorFont.fallback,
      height: 1.4,
      color: editorTheme.textColor,
    );

    final span = _getHighlightedLineSpan(
      code: line.text,
      baseStyle: baseStyle,
      editorTheme: editorTheme,
    );

    final contentBg = _getCodeRowBackgroundColor(line.role, isDark);

    // 左侧高亮边条色 (对标 VS Code 编辑区边缘指示色带)
    Color? leftIndicatorColor;
    if (line.role == ConflictLineRole.oursContent) {
      leftIndicatorColor =
          isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
    } else if (line.role == ConflictLineRole.theirsContent) {
      leftIndicatorColor =
          isDark ? const Color(0xFF58A6FF) : const Color(0xFF1976D2);
    } else if (line.role == ConflictLineRole.baseContent) {
      leftIndicatorColor = editorTheme.gutterTextColor.withValues(alpha: 0.6);
    }

    return Container(
      height: baseRowHeight,
      color: contentBg,
      child: Stack(
        children: [
          if (leftIndicatorColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.0,
              child: Container(color: leftIndicatorColor),
            ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8.0, right: 160.0),
              child: Text.rich(
                span,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------- 各侧标头色带构建 (VS Code 规范) ----------------------------

  Widget _buildOursHeaderBand({
    required ConflictLine line,
    required double baseRowHeight,
    required double fontSize,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required AppLocalizations l10n,
  }) {
    final isDark = editorTheme.isDark;
    final greenColor =
        isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);

    return Container(
      height: baseRowHeight,
      decoration: BoxDecoration(
        color: greenColor.withValues(alpha: isDark ? 0.30 : 0.20),
        border: Border(
          top: BorderSide(color: greenColor.withValues(alpha: 0.8), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.only(left: 8.0, right: 16.0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.arrow_downward_rounded, size: 13, color: greenColor),
          const SizedBox(width: 4),
          Text(
            '${line.text} · ${l10n.gitConflictSectionOurs}',
            style: TextStyle(
              fontSize: (fontSize - 1).clamp(
                SettingsProvider.minFontSize - 1.0,
                SettingsProvider.maxFontSize,
              ),
              fontWeight: FontWeight.bold,
              fontFamily: editorFont.fontFamily,
              fontFamilyFallback: editorFont.fallback,
              color: greenColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheirsHeaderBand({
    required ConflictLine line,
    required double baseRowHeight,
    required double fontSize,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required AppLocalizations l10n,
  }) {
    final isDark = editorTheme.isDark;
    final blueColor =
        isDark ? const Color(0xFF58A6FF) : const Color(0xFF1976D2);

    return Container(
      height: baseRowHeight,
      decoration: BoxDecoration(
        color: blueColor.withValues(alpha: isDark ? 0.30 : 0.20),
        border: Border(
          bottom: BorderSide(
            color: blueColor.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 8.0, right: 16.0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.arrow_upward_rounded, size: 13, color: blueColor),
          const SizedBox(width: 4),
          Text(
            '${line.text} · ${l10n.gitConflictSectionTheirs}',
            style: TextStyle(
              fontSize: (fontSize - 1).clamp(
                SettingsProvider.minFontSize - 1.0,
                SettingsProvider.maxFontSize,
              ),
              fontWeight: FontWeight.bold,
              fontFamily: editorFont.fontFamily,
              fontFamilyFallback: editorFont.fallback,
              color: blueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseHeaderBand({
    required ConflictLine line,
    required double baseRowHeight,
    required double fontSize,
    required EditorTheme editorTheme,
    required AppFontItem editorFont,
    required AppLocalizations l10n,
  }) {
    final grayColor = editorTheme.gutterTextColor;
    final isDark = editorTheme.isDark;

    return Container(
      height: baseRowHeight,
      color: grayColor.withValues(alpha: isDark ? 0.22 : 0.15),
      padding: const EdgeInsets.only(left: 8.0, right: 16.0),
      alignment: Alignment.centerLeft,
      child: Text(
        '${line.text} · ${l10n.gitConflictSectionBaseline}',
        style: TextStyle(
          fontSize: (fontSize - 1).clamp(
            SettingsProvider.minFontSize - 1.0,
            SettingsProvider.maxFontSize,
          ),
          fontWeight: FontWeight.w600,
          fontFamily: editorFont.fontFamily,
          fontFamilyFallback: editorFont.fallback,
          color: grayColor,
        ),
      ),
    );
  }

  Widget _buildSeparatorLine({
    required double baseRowHeight,
    required EditorTheme editorTheme,
  }) {
    final isDark = editorTheme.isDark;
    return Container(
      height: baseRowHeight,
      color: isDark ? const Color(0xFF1E2227) : const Color(0xFFF1F5F9),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8.0, right: 160.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.0,
              color: editorTheme.gutterTextColor.withValues(alpha: 0.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '=======',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold,
                color: editorTheme.gutterTextColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.0,
              color: editorTheme.gutterTextColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------- 色彩映射辅助 ----------------------------

  Color? _getGutterBackgroundColor(ConflictLineRole role, bool isDark) {
    return switch (role) {
      ConflictLineRole.oursHeader ||
      ConflictLineRole.oursContent =>
        Colors.green.withValues(alpha: isDark ? 0.16 : 0.09),
      ConflictLineRole.theirsHeader ||
      ConflictLineRole.theirsContent =>
        Colors.blue.withValues(alpha: isDark ? 0.16 : 0.09),
      ConflictLineRole.baseHeader ||
      ConflictLineRole.baseContent =>
        Colors.grey.withValues(alpha: isDark ? 0.12 : 0.06),
      ConflictLineRole.separator =>
        isDark ? const Color(0xFF1E2227) : const Color(0xFFF1F5F9),
      ConflictLineRole.context => null,
    };
  }

  Color? _getCodeRowBackgroundColor(ConflictLineRole role, bool isDark) {
    return switch (role) {
      ConflictLineRole.oursContent =>
        Colors.green.withValues(alpha: isDark ? 0.14 : 0.08),
      ConflictLineRole.theirsContent =>
        Colors.blue.withValues(alpha: isDark ? 0.14 : 0.08),
      ConflictLineRole.baseContent =>
        Colors.grey.withValues(alpha: isDark ? 0.10 : 0.05),
      _ => null,
    };
  }

  // ---------------------------- 底部操作栏 ----------------------------

  Widget _buildBottomBar(
    BuildContext context,
    AppLocalizations l10n,
    EditorTheme editorTheme,
    int remainingConflicts,
  ) {
    final theme = Theme.of(context);
    final isDone = !_parsed.isMalformed &&
        remainingConflicts == 0 &&
        !GitConflictParser.containsMarkers(_content);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 手动编辑
            Flexible(
              flex: 2,
              child: OutlinedButton.icon(
                key: const ValueKey('git_conflict_edit_manually'),
                onPressed: _openInEditor,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
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
            // 保存并标记已解决
            Flexible(
              flex: 3,
              child: FilledButton.icon(
                key: const ValueKey('git_conflict_save_and_mark'),
                onPressed: _saveAndMark,
                style: FilledButton.styleFrom(
                  backgroundColor: isDone ? Colors.green : null,
                  foregroundColor: isDone ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(
                  isDone
                      ? l10n.gitConflictResolvedCommit
                      : l10n.gitConflictSaveAndMarkShort,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
}

// ==============================================================================
// 冲突操作 CodeLens 悬浮胶囊栏（支持水平手势自由拖动，彻底杜绝 RenderFlex 溢出）
// ==============================================================================

class _ConflictCodeLensBar extends StatefulWidget {
  const _ConflictCodeLensBar({
    required this.blockIndex,
    required this.editorTheme,
    required this.l10n,
    required this.availableWidth,
    required this.onAcceptCurrent,
    required this.onAcceptIncoming,
    required this.onAcceptBoth,
    required this.onCompare,
    this.onTouchStart,
    this.onTouchEnd,
  });

  final int blockIndex;
  final EditorTheme editorTheme;
  final AppLocalizations l10n;
  final double availableWidth;
  final VoidCallback onAcceptCurrent;
  final VoidCallback onAcceptIncoming;
  final VoidCallback onAcceptBoth;
  final VoidCallback onCompare;
  final VoidCallback? onTouchStart;
  final VoidCallback? onTouchEnd;

  @override
  State<_ConflictCodeLensBar> createState() => _ConflictCodeLensBarState();
}

class _ConflictCodeLensBarState extends State<_ConflictCodeLensBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.editorTheme.isDark;
    final barBg = isDark ? const Color(0xFF1E2227) : const Color(0xFFF3F4F6);
    final borderColor = widget.editorTheme.gutterTextColor.withValues(alpha: 0.2);

    return Container(
      height: 32.0,
      width: math.max(100.0, widget.availableWidth),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onTouchStart?.call(),
        onPointerUp: (_) => widget.onTouchEnd?.call(),
        onPointerCancel: (_) => widget.onTouchEnd?.call(),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChip(
                  key: ValueKey('conflict_accept_current_${widget.blockIndex}'),
                  label: widget.l10n.gitConflictAcceptCurrentShort,
                  icon: Icons.check_rounded,
                  color: isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
                  onTap: widget.onAcceptCurrent,
                  tooltip: widget.l10n.gitConflictAcceptCurrent,
                ),
                const SizedBox(width: 6),
                _buildChip(
                  key: ValueKey('conflict_accept_incoming_${widget.blockIndex}'),
                  label: widget.l10n.gitConflictAcceptIncomingShort,
                  icon: Icons.check_rounded,
                  color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF1976D2),
                  onTap: widget.onAcceptIncoming,
                  tooltip: widget.l10n.gitConflictAcceptIncoming,
                ),
                const SizedBox(width: 6),
                _buildChip(
                  key: ValueKey('conflict_accept_both_${widget.blockIndex}'),
                  label: widget.l10n.gitConflictAcceptBothShort,
                  icon: Icons.call_merge_rounded,
                  color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
                  onTap: widget.onAcceptBoth,
                  tooltip: widget.l10n.gitConflictAcceptBoth,
                ),
                const SizedBox(width: 6),
                _buildChip(
                  key: ValueKey('conflict_compare_${widget.blockIndex}'),
                  label: widget.l10n.gitConflictCompareShort,
                  icon: Icons.difference_outlined,
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                  onTap: widget.onCompare,
                  tooltip: widget.l10n.gitConflictCompare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    Key? key,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12.5, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 冲突比较查看弹窗 (Compare Changes Modal Dialog)
// ==============================================================================

class _ConflictCompareDialog extends StatelessWidget {
  const _ConflictCompareDialog({
    required this.blockIndex,
    required this.oursLabel,
    required this.theirsLabel,
    required this.oursText,
    required this.theirsText,
    required this.splitDiff,
    required this.editorTheme,
    required this.editorFont,
    required this.fontSize,
    required this.onAcceptCurrent,
    required this.onAcceptIncoming,
    required this.onAcceptBoth,
  });

  final int blockIndex;
  final String oursLabel;
  final String theirsLabel;
  final String oursText;
  final String theirsText;
  final SplitDiffResult splitDiff;
  final EditorTheme editorTheme;
  final AppFontItem editorFont;
  final double fontSize;

  final VoidCallback onAcceptCurrent;
  final VoidCallback onAcceptIncoming;
  final VoidCallback onAcceptBoth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rowH = (fontSize * 1.35 + 2.0).roundToDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: editorTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 600),
        child: Column(
          children: [
            // 顶栏标头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.difference_rounded,
                    size: 18,
                    color: Color(0xFFFF9800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.gitConflictCompareTitle(blockIndex + 1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 双侧标题标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: editorTheme.isDark
                  ? const Color(0xFF1E2227)
                  : const Color(0xFFEEEEEE),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 13,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.gitConflictCurrentWithLabel(oursLabel),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: editorTheme.gutterTextColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 13,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.gitConflictIncomingWithLabel(theirsLabel),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 差异双栏对比内容
            Expanded(
              child: splitDiff.leftLines.isEmpty && splitDiff.rightLines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.gitConflictBothEmpty,
                        style: TextStyle(
                          fontSize: 12,
                          color: editorTheme.gutterTextColor,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 左侧 (当前版本)
                        Expanded(
                          child: ListView.builder(
                            itemCount: splitDiff.leftLines.length,
                            itemExtent: rowH,
                            itemBuilder: (ctx, i) {
                              final line = splitDiff.leftLines[i];
                              final isDel = line.type == DiffLineType.deleted;
                              final isEmpty = line.type == DiffLineType.empty;
                              Color? bg;
                              if (isDel) {
                                bg = Colors.red.withValues(
                                  alpha: editorTheme.isDark ? 0.22 : 0.12,
                                );
                              } else if (isEmpty) {
                                bg = editorTheme.isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.03);
                              }
                              return Container(
                                color: bg,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  line.text,
                                  style: TextStyle(
                                    fontSize: fontSize - 1,
                                    fontFamily: editorFont.fontFamily,
                                    fontFamilyFallback: editorFont.fallback,
                                    color: isDel
                                        ? (editorTheme.isDark
                                            ? const Color(0xFFEF5350)
                                            : const Color(0xFFD32F2F))
                                        : editorTheme.textColor,
                                  ),
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          width: 1.0,
                          color: editorTheme.gutterTextColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        // 右侧 (传入版本)
                        Expanded(
                          child: ListView.builder(
                            itemCount: splitDiff.rightLines.length,
                            itemExtent: rowH,
                            itemBuilder: (ctx, i) {
                              final line = splitDiff.rightLines[i];
                              final isAdd = line.type == DiffLineType.added;
                              final isEmpty = line.type == DiffLineType.empty;
                              Color? bg;
                              if (isAdd) {
                                bg = Colors.green.withValues(
                                  alpha: editorTheme.isDark ? 0.22 : 0.12,
                                );
                              } else if (isEmpty) {
                                bg = editorTheme.isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.03);
                              }
                              return Container(
                                color: bg,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  line.text,
                                  style: TextStyle(
                                    fontSize: fontSize - 1,
                                    fontFamily: editorFont.fontFamily,
                                    fontFamilyFallback: editorFont.fallback,
                                    color: isAdd
                                        ? (editorTheme.isDark
                                            ? const Color(0xFF66BB6A)
                                            : const Color(0xFF2E7D32))
                                        : editorTheme.textColor,
                                  ),
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),

            // 底栏快速决策按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                    label: Text(l10n.gitConflictAcceptIncoming),
                    onPressed: onAcceptIncoming,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                    label: Text(l10n.gitConflictAcceptCurrent),
                    onPressed: onAcceptCurrent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


