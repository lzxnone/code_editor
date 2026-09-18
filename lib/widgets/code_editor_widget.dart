import 'dart:async';
import 'dart:math';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/models/search_model.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/services/file_watcher_service.dart';
import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:code_editor/services/lsp/lsp_diagnostics_store.dart';
import 'package:code_editor/services/lsp/lsp_manager.dart';
import 'package:code_editor/services/lsp/lsp_protocol.dart';
import 'package:code_editor/utils/case_utils.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/utils/git_diff_helper.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:code_editor/widgets/code_autocomplete_view.dart';
import 'package:code_editor/widgets/code_editor_menu.dart';
import 'package:code_editor/widgets/editor/editor_diagnostic_controller.dart';
import 'package:code_editor/widgets/editor/editor_lsp_coordinator.dart';
import 'package:code_editor/widgets/editor/editor_overlay_scope.dart';
import 'package:code_editor/widgets/virtual_keyboard_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

/// 行号指示器红/黄圆点装饰器
class DiagnosticGutterDotDecoration extends Decoration {
  final Color color;
  final double radius;

  const DiagnosticGutterDotDecoration({
    required this.color,
    this.radius = 3.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DiagnosticGutterDotPainter(this);
  }
}

class _DiagnosticGutterDotPainter extends BoxPainter {
  final DiagnosticGutterDotDecoration decoration;
  _DiagnosticGutterDotPainter(this.decoration);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;
    final center = Offset(offset.dx + 4.0, offset.dy + size.height / 2);
    canvas.drawCircle(center, decoration.radius, paint);
  }
}

/// 编辑区行号栏与代码折叠箭头之间的 Git 差异条指示器（对标 VS Code）
class GitDiffGutterIndicator extends LeafRenderObjectWidget {
  final double width;
  final CodeIndicatorValueNotifier notifier;
  final ValueListenable<Map<int, GitGutterDiffType>> diffMarkers;

  const GitDiffGutterIndicator({
    super.key,
    required this.width,
    required this.notifier,
    required this.diffMarkers,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => GitDiffGutterIndicatorRenderObject(
    width: width,
    notifier: notifier,
    diffMarkers: diffMarkers,
  );

  @override
  void updateRenderObject(BuildContext context, covariant GitDiffGutterIndicatorRenderObject renderObject) {
    renderObject
      ..width = width
      ..notifier = notifier
      ..diffMarkers = diffMarkers;
    super.updateRenderObject(context, renderObject);
  }
}

class GitDiffGutterIndicatorRenderObject extends RenderBox {
  double _width;
  CodeIndicatorValueNotifier _notifier;
  ValueListenable<Map<int, GitGutterDiffType>> _diffMarkers;

  GitDiffGutterIndicatorRenderObject({
    required double width,
    required CodeIndicatorValueNotifier notifier,
    required ValueListenable<Map<int, GitGutterDiffType>> diffMarkers,
  }) : _width = width,
       _notifier = notifier,
       _diffMarkers = diffMarkers;

  set width(double val) {
    if (_width == val) return;
    _width = val;
    markNeedsLayout();
  }

  set notifier(CodeIndicatorValueNotifier val) {
    if (_notifier == val) return;
    if (attached) _notifier.removeListener(markNeedsPaint);
    _notifier = val;
    if (attached) _notifier.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set diffMarkers(ValueListenable<Map<int, GitGutterDiffType>> val) {
    if (_diffMarkers == val) return;
    if (attached) _diffMarkers.removeListener(markNeedsPaint);
    _diffMarkers = val;
    if (attached) _diffMarkers.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    _notifier.addListener(markNeedsPaint);
    _diffMarkers.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _notifier.removeListener(markNeedsPaint);
    _diffMarkers.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _width;

  @override
  double computeMaxIntrinsicWidth(double height) => _width;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0.0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(Size(_width, constraints.maxHeight));
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_width, constraints.maxHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final CodeIndicatorValue? value = _notifier.value;
    if (value == null || value.paragraphs.isEmpty) return;

    final markers = _diffMarkers.value;
    if (markers.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));

    for (final CodeLineRenderParagraph paragraph in value.paragraphs) {
      final markerType = markers[paragraph.index];
      if (markerType == null) continue;

      final top = offset.dy + paragraph.offset.dy;
      final height = paragraph.preferredLineHeight;

      switch (markerType) {
        case GitGutterDiffType.modified:
          paint.color = const Color(0xFFE2B340); // 黄色/琥珀色
          canvas.drawRect(
            Rect.fromLTWH(offset.dx + 1.0, top, 3.0, height),
            paint,
          );
          break;
        case GitGutterDiffType.added:
          paint.color = const Color(0xFF2EA043); // 绿色
          canvas.drawRect(
            Rect.fromLTWH(offset.dx + 1.0, top, 3.0, height),
            paint,
          );
          break;
        case GitGutterDiffType.deleted:
          paint.color = const Color(0xFFF85149); // 红色删除三角形
          final path = Path()
            ..moveTo(offset.dx + 1.0, top)
            ..lineTo(offset.dx + 4.5, top + 3.0)
            ..lineTo(offset.dx + 1.0, top + 6.0)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
    }

    canvas.restore();
  }
}

class CodeEditorWidget extends StatefulWidget {
  final String? rootPath;
  final String? filePath;

  const CodeEditorWidget({
    super.key,
    required this.rootPath,
    required this.filePath,
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  static SettingsProvider _getSettingsProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<SettingsProvider>() : context.read<SettingsProvider>();
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  CodeLineEditingController? _controller;
  CodeScrollController? _scrollController;
  CodeFindController? _findController;
  final FocusNode _focusNode = FocusNode();
  late final CodeEditorToolbarController _toolbarController;
  final EditorDiagnosticController _diagnosticController = const EditorDiagnosticController();
  final EditorLspCoordinator _lspCoordinator = const EditorLspCoordinator();
  bool _isLoading = false;
  int _currentLoadVersion = 0;
  String? _errorMessage;
  String? _currentLoadedPath;
  int? _currentIndentSize;
  bool _isShowingConflictDialog = false;
  int _currentCursorLine = -1;

  // Git 行差异状态管理（对标 VS Code 实时黄绿高亮）
  String? _gitBaseContent;
  final ValueNotifier<Map<int, GitGutterDiffType>> _gitLineMarkers = ValueNotifier(const {});
  Timer? _gitDiffDebounceTimer;
  String? _lastGitStateKey;

  // 双指捏合实时缩放字号及中心锚定状态
  final GlobalKey _editorContainerKey = GlobalKey();
  final Map<int, Offset> _pointerPositions = {};
  int? _pinchPointer1;
  int? _pinchPointer2;
  double? _initialPinchDistance;
  double? _initialPinchFontSize;
  double? _activeZoomFontSize;
  bool _isPinching = false;
  CodeLineSelection? _pinchSelection;
  Offset? _initialLocalFocal;
  Offset? _currentLocalFocal;
  double _initialScrollV = 0.0;
  double _initialScrollH = 0.0;
  double _focalLineContinuous = 0.0;
  double _focalCharContinuous = 0.0;

  final Map<String, double> _lineHeightCache = {};
  final Map<String, double> _charWidthCache = {};

  double getLineHeight(double fontSize, String? fontFamily, List<String>? fallback) {
    final key = '$fontSize-$fontFamily-${fallback?.join(',')}';
    if (_lineHeightCache.containsKey(key)) {
      return _lineHeightCache[key]!;
    }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontFamilyFallback: fallback,
        height: 1.4,
        forceStrutHeight: true,
      ),
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
          height: 1.4,
        ),
      ),
    )..layout();
    final h = painter.preferredLineHeight;
    _lineHeightCache[key] = h;
    return h;
  }

  double getCharWidth(double fontSize, String? fontFamily, List<String>? fallback) {
    final key = '$fontSize-$fontFamily-${fallback?.join(',')}';
    if (_charWidthCache.containsKey(key)) {
      return _charWidthCache[key]!;
    }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
        ),
      ),
    )..layout();
    final w = painter.width;
    _charWidthCache[key] = w;
    return w;
  }

  void _handlePointerDown(PointerDownEvent event, double currentFontSize, AppFontItem activeEditorFont) {
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length >= 2 && !_isPinching) {
      final keys = _pointerPositions.keys.toList();
      _pinchPointer1 = keys[0];
      _pinchPointer2 = keys[1];

      final p1 = _pointerPositions[_pinchPointer1]!;
      final p2 = _pointerPositions[_pinchPointer2]!;

      _initialPinchDistance = (p1 - p2).distance;
      _initialPinchFontSize = _activeZoomFontSize ?? currentFontSize;
      _activeZoomFontSize = _initialPinchFontSize;

      // 锁定底层滚动控制器并停止惯性滚动，彻底阻断单指拖拽识别器与内部 viewport 修正干扰
      final vScroller = _scrollController?.verticalScroller;
      if (vScroller is CodeEditorScrollController) {
        vScroller.isPinchLocked = true;
      }
      final hScroller = _scrollController?.horizontalScroller;
      if (hScroller is CodeEditorScrollController) {
        hScroller.isPinchLocked = true;
      }

      final globalFocal = (p1 + p2) / 2;
      final renderBox = _editorContainerKey.currentContext?.findRenderObject() as RenderBox?;
      final localFocal = renderBox != null ? renderBox.globalToLocal(globalFocal) : globalFocal;
      _initialLocalFocal = localFocal;
      _currentLocalFocal = localFocal;

      _initialScrollV = (_scrollController?.verticalScroller.hasClients == true)
          ? _scrollController!.verticalScroller.offset
          : 0.0;
      _initialScrollH = (_scrollController?.horizontalScroller.hasClients == true)
          ? _scrollController!.horizontalScroller.offset
          : 0.0;

      final startH = getLineHeight(_initialPinchFontSize!, activeEditorFont.fontFamily, activeEditorFont.fallback);
      final startW = getCharWidth(_initialPinchFontSize!, activeEditorFont.fontFamily, activeEditorFont.fallback);

      _focalLineContinuous = (_initialScrollV + localFocal.dy) / max(1.0, startH);
      _focalCharContinuous = (_initialScrollH + localFocal.dx) / max(1.0, startW);

      final currentController = _controller;
      if (currentController != null &&
          !currentController.selection.isCollapsed &&
          currentController.selection.baseOffset != -1) {
        _pinchSelection = currentController.selection;
      }
      _toolbarController.hide(context);
      setState(() {
        _isPinching = true;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;

    if (_isPinching &&
        _pinchPointer1 != null &&
        _pinchPointer2 != null &&
        _pointerPositions.containsKey(_pinchPointer1) &&
        _pointerPositions.containsKey(_pinchPointer2) &&
        _initialPinchDistance != null &&
        _initialPinchDistance! > 10.0 &&
        _initialPinchFontSize != null &&
        _initialLocalFocal != null) {
      final p1 = _pointerPositions[_pinchPointer1]!;
      final p2 = _pointerPositions[_pinchPointer2]!;

      final currentDistance = (p1 - p2).distance;
      final rawScale = currentDistance / _initialPinchDistance!;

      // 边界弹性阻尼（SettingsProvider.minFontSize ~ SettingsProvider.maxFontSize）
      final minScale = SettingsProvider.minFontSize / _initialPinchFontSize!;
      final maxScale = SettingsProvider.maxFontSize / _initialPinchFontSize!;
      final clampedScale = rawScale.clamp(minScale * 0.9, maxScale * 1.1);

      final currentGlobalFocal = (p1 + p2) / 2;
      final renderBox = _editorContainerKey.currentContext?.findRenderObject() as RenderBox?;
      final currentLocalFocal = renderBox != null
          ? renderBox.globalToLocal(currentGlobalFocal)
          : currentGlobalFocal;
      _currentLocalFocal = currentLocalFocal;

      final continuousFontSize = ((_initialPinchFontSize! * clampedScale) * 10).round() / 10.0;
      final newFontSize = continuousFontSize.clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize);

      AppFontItem activeEditorFont = AppFonts.editorJetBrainsMono;
      try {
        activeEditorFont = _getSettingsProvider(context).editorFont;
      } catch (_) {}

      final newH = getLineHeight(newFontSize, activeEditorFont.fontFamily, activeEditorFont.fallback);
      final newW = getCharWidth(newFontSize, activeEditorFont.fontFamily, activeEditorFont.fallback);

      final targetScrollV = _focalLineContinuous * newH - currentLocalFocal.dy;
      final targetScrollH = _focalCharContinuous * newW - currentLocalFocal.dx;

      if (_scrollController?.verticalScroller.hasClients == true) {
        final pos = _scrollController!.verticalScroller.position;
        final totalLines = _controller?.lineCount ?? 1;
        final viewportHeight = renderBox?.size.height ?? 500.0;
        final computedMaxV = max(0.0, totalLines * newH + viewportHeight * 0.5 - viewportHeight);
        final maxV = max(computedMaxV, pos.maxScrollExtent);
        final clampedV = targetScrollV.clamp(0.0, maxV).toDouble();
        _scrollController!.verticalScroller.jumpTo(clampedV);
      }
      if (_scrollController?.horizontalScroller.hasClients == true) {
        final pos = _scrollController!.horizontalScroller.position;
        final maxH = max(0.0, pos.maxScrollExtent);
        final clampedH = targetScrollH.clamp(0.0, max(maxH, targetScrollH)).toDouble();
        _scrollController!.horizontalScroller.jumpTo(clampedH);
      }

      if (_activeZoomFontSize != newFontSize) {
        setState(() {
          _activeZoomFontSize = newFontSize;
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_isPinching && (event.pointer == _pinchPointer1 || event.pointer == _pinchPointer2 || _pointerPositions.length < 2)) {
      _finishPinchZoom();
    }
    if (_pointerPositions.isEmpty) {
      _unlockPinch();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_isPinching && (event.pointer == _pinchPointer1 || event.pointer == _pinchPointer2 || _pointerPositions.length < 2)) {
      _finishPinchZoom();
    }
    if (_pointerPositions.isEmpty) {
      _unlockPinch();
    }
  }

  void _unlockPinch() {
    final vScroller = _scrollController?.verticalScroller;
    if (vScroller is CodeEditorScrollController) {
      vScroller.isPinchLocked = false;
    }
    final hScroller = _scrollController?.horizontalScroller;
    if (hScroller is CodeEditorScrollController) {
      hScroller.isPinchLocked = false;
    }
  }

  void _finishPinchZoom() {
    final finalSize = _activeZoomFontSize;
    final savedSelection = _pinchSelection;
    _pinchSelection = null;

    final initialFontSize = _initialPinchFontSize;
    final initialLocalFocal = _initialLocalFocal;
    final currentLocalFocal = _currentLocalFocal ?? initialLocalFocal;

    if (finalSize != null && initialFontSize != null && initialLocalFocal != null && currentLocalFocal != null) {
      // 手势释放后定格为整数（如 16.0），持久化到用户设置
      final double targetFontSize = finalSize.clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize).roundToDouble();

      AppFontItem activeEditorFont = AppFonts.editorJetBrainsMono;
      try {
        final settings = _getSettingsProvider(context);
        activeEditorFont = settings.editorFont;
        settings.setFontSize(targetFontSize);
      } catch (_) {}

      final finalH = getLineHeight(targetFontSize, activeEditorFont.fontFamily, activeEditorFont.fallback);
      final finalW = getCharWidth(targetFontSize, activeEditorFont.fontFamily, activeEditorFont.fallback);

      final targetScrollV = _focalLineContinuous * finalH - currentLocalFocal.dy;
      final targetScrollH = _focalCharContinuous * finalW - currentLocalFocal.dx;

      if (_scrollController?.verticalScroller.hasClients == true) {
        final pos = _scrollController!.verticalScroller.position;
        final totalLines = _controller?.lineCount ?? 1;
        final renderBox = _editorContainerKey.currentContext?.findRenderObject() as RenderBox?;
        final viewportHeight = renderBox?.size.height ?? 500.0;
        final computedMaxV = max(0.0, totalLines * finalH + viewportHeight * 0.5 - viewportHeight);
        final maxV = max(computedMaxV, pos.maxScrollExtent);
        final clampedV = targetScrollV.clamp(0.0, maxV).toDouble();
        _scrollController!.verticalScroller.jumpTo(clampedV);
      }
      if (_scrollController?.horizontalScroller.hasClients == true) {
        final pos = _scrollController!.horizontalScroller.position;
        final maxH = max(0.0, pos.maxScrollExtent);
        final clampedH = targetScrollH.clamp(0.0, max(maxH, targetScrollH)).toDouble();
        _scrollController!.horizontalScroller.jumpTo(clampedH);
      }
    }

    setState(() {
      _isPinching = false;
      _pinchPointer1 = null;
      _pinchPointer2 = null;
      _initialPinchDistance = null;
      _initialPinchFontSize = null;
      _activeZoomFontSize = null;
      _initialLocalFocal = null;
      _currentLocalFocal = null;
      _initialScrollV = 0.0;
      _initialScrollH = 0.0;
      _focalLineContinuous = 0.0;
      _focalCharContinuous = 0.0;
    });

    if (savedSelection != null && !savedSelection.isCollapsed) {
      final currentController = _controller;
      if (currentController != null) {
        currentController.selection = savedSelection;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toolbarController.reshowLastToolbar(context);
      });
    }
  }

  EditorTabItem? _getCurrentTab() {
    final filePath = widget.filePath;
    if (filePath == null || filePath.isEmpty) return null;
    try {
      final provider = _getTabProvider(context);
      final rootPath = widget.rootPath;
      final fullFilePath = (rootPath == null || rootPath.isEmpty || p.isAbsolute(filePath))
          ? filePath
          : p.join(rootPath, filePath);
      final cleanPath = p.normalize(fullFilePath);
      return provider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  void _saveCurrentTabScrollState(EditorTabItem? tab) {
    if (tab == null || _scrollController == null) return;
    if (_scrollController!.verticalScroller.hasClients) {
      tab.verticalScrollOffset = _scrollController!.verticalScroller.offset;
    }
    if (_scrollController!.horizontalScroller.hasClients) {
      tab.horizontalScrollOffset = _scrollController!.horizontalScroller.offset;
    }
  }

  void _restoreTabScrollState(EditorTabItem tab) {
    final oldScroll = _scrollController;

    final vScroller = CodeEditorScrollController(initialScrollOffset: tab.verticalScrollOffset);
    final hScroller = CodeEditorScrollController(initialScrollOffset: tab.horizontalScrollOffset);

    vScroller.addListener(() {
      if (vScroller.hasClients) {
        tab.verticalScrollOffset = vScroller.offset;
      }
    });
    hScroller.addListener(() {
      if (hScroller.hasClients) {
        tab.horizontalScrollOffset = hScroller.offset;
      }
    });

    _scrollController = CodeScrollController(
      verticalScroller: vScroller,
      horizontalScroller: hScroller,
    );

    oldScroll?.verticalScroller.dispose();
    oldScroll?.horizontalScroller.dispose();
    oldScroll?.dispose();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollController == null) return;
      if (vScroller.hasClients) {
        final maxV = vScroller.position.maxScrollExtent;
        final targetV = tab.verticalScrollOffset.clamp(0.0, maxV);
        if ((vScroller.offset - targetV).abs() > 0.5) {
          vScroller.jumpTo(targetV);
        }
      }
      if (hScroller.hasClients) {
        final maxH = hScroller.position.maxScrollExtent;
        final targetH = tab.horizontalScrollOffset.clamp(0.0, maxH);
        if ((hScroller.offset - targetH).abs() > 0.5) {
          hScroller.jumpTo(targetH);
        }
      }
    });
  }

  void _handleNavigationTarget(TabProvider tabProvider) {
    final target = tabProvider.navigationTarget;
    if (target != null &&
        _controller != null &&
        p.equals(target.filePath, _currentLoadedPath ?? '')) {
      final int totalLines = _controller!.lineCount;
      final int maxLine = max(0, totalLines - 1);
      final int line = target.line.clamp(0, maxLine);
      final lineText = _controller!.codeLines[line].text;
      final int col = (target.column ?? 0).clamp(0, lineText.length);
      final int len = (target.length ?? 0).clamp(0, lineText.length - col);

      _controller!.selection = CodeLineSelection(
        baseIndex: line,
        baseOffset: col,
        extentIndex: line,
        extentOffset: col + len,
      );
      _controller!.makePositionCenterIfInvisible(CodeLinePosition(index: line, offset: col));
      tabProvider.clearNavigationTarget();
    }
  }

  CodeFindValue _buildCurrentFindValue(SearchProvider? searchProvider) {
    final isTextSearch = searchProvider?.options.mode == SearchMode.text;
    final query = (isTextSearch ? searchProvider?.query : null) ?? '';
    return CodeFindValue(
      option: CodeFindOption(
        pattern: query,
        caseSensitive: searchProvider?.caseSensitive ?? false,
        regex: searchProvider?.isRegex ?? false,
      ),
      replaceMode: false,
      searching: query.isNotEmpty,
    );
  }

  void _syncSearchHighlight(SearchProvider? searchProvider) {
    if (searchProvider == null || _findController == null) return;
    // 仅在文本内容搜索模式（SearchMode.text）下才同步编辑区高亮；
    // 文件名搜索模式（SearchMode.fileName）下严禁在代码编辑区高亮匹配词。
    final isTextSearch = searchProvider.options.mode == SearchMode.text;
    final query = isTextSearch ? searchProvider.query : '';
    final curVal = _findController!.value;
    final curOpt = curVal?.option;

    if (curOpt == null ||
        curOpt.pattern != query ||
        curOpt.caseSensitive != searchProvider.caseSensitive ||
        curOpt.regex != searchProvider.isRegex) {
      if (_findController!.findInputController.text != query) {
        _findController!.findInputController.text = query;
      }
      _findController!.value = CodeFindValue(
        option: CodeFindOption(
          pattern: query,
          caseSensitive: searchProvider.caseSensitive,
          regex: searchProvider.isRegex,
        ),
        replaceMode: false,
        searching: query.isNotEmpty,
      );
      _controller?.forceRepaint();
    }
  }

  List<CodeLineSelection> _findAllMatches(RegExp regExp) {
    if (_controller == null) return const [];
    final matches = <CodeLineSelection>[];
    final lines = _controller!.codeLines;
    for (int i = 0; i < lines.length; i++) {
      final lineText = lines[i].text;
      for (final m in regExp.allMatches(lineText)) {
        matches.add(CodeLineSelection(
          baseIndex: i,
          baseOffset: m.start,
          extentIndex: i,
          extentOffset: m.end,
        ));
      }
    }
    return matches;
  }

  void _handleFindNext() {
    if (!mounted || _controller == null) return;
    SearchProvider? searchProvider;
    try {
      searchProvider = context.read<SearchProvider?>();
    } catch (_) {}
    if (searchProvider == null || searchProvider.query.trim().isEmpty) return;

    final regExp = searchProvider.options.buildRegExp();
    if (regExp == null) return;

    final matches = _findAllMatches(regExp);
    if (matches.isEmpty) return;

    final curSelection = _controller!.selection;
    final curEndLine = curSelection.endIndex;
    final curEndOffset = curSelection.endOffset;

    CodeLineSelection? target;
    for (final match in matches) {
      if (match.startIndex > curEndLine ||
          (match.startIndex == curEndLine && match.startOffset >= curEndOffset)) {
        target = match;
        break;
      }
    }
    target ??= matches.first;

    _controller!.selection = target;
    _controller!.makePositionCenterIfInvisible(target.start);
    _syncSearchHighlight(searchProvider);
  }

  void _handleFindPrevious() {
    if (!mounted || _controller == null) return;
    SearchProvider? searchProvider;
    try {
      searchProvider = context.read<SearchProvider?>();
    } catch (_) {}
    if (searchProvider == null || searchProvider.query.trim().isEmpty) return;

    final regExp = searchProvider.options.buildRegExp();
    if (regExp == null) return;

    final matches = _findAllMatches(regExp);
    if (matches.isEmpty) return;

    final curSelection = _controller!.selection;
    final curStartLine = curSelection.startIndex;
    final curStartOffset = curSelection.startOffset;

    CodeLineSelection? target;
    for (int i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      if (match.endIndex < curStartLine ||
          (match.endIndex == curStartLine && match.endOffset <= curStartOffset)) {
        target = match;
        break;
      }
    }
    target ??= matches.last;

    _controller!.selection = target;
    _controller!.makePositionCenterIfInvisible(target.start);
    _syncSearchHighlight(searchProvider);
  }

  void _handleReplaceCurrent() {
    if (!mounted || _controller == null) return;
    SearchProvider? searchProvider;
    try {
      searchProvider = context.read<SearchProvider?>();
    } catch (_) {}
    if (searchProvider == null || searchProvider.query.trim().isEmpty) return;

    final selection = _controller!.selection;
    if (selection.isCollapsed) return;

    final selectedText = _controller!.selectedText;
    final regExp = searchProvider.options.buildRegExp();
    if (regExp == null) return;

    // 先判断框选文本和搜索内容是否一致（全匹配校验）
    final match = regExp.firstMatch(selectedText);
    if (match == null || match.start != 0 || match.end != selectedText.length) {
      // 不一致，静默失败
      return;
    }

    // 计算替换文本（支持保留大小写）
    String replacement = searchProvider.replaceText;
    if (searchProvider.preserveCase) {
      replacement = CaseUtils.applyPreserveCase(
        original: selectedText,
        replacement: replacement,
      );
    }

    _controller!.replaceSelection(replacement);

    // 替换后自动定位并框选下一个匹配
    _handleFindNext();
  }

  Future<void> _updateGitBaseContent() async {
    final path = _currentLoadedPath;
    if (path == null) {
      _gitBaseContent = null;
      if (_gitLineMarkers.value.isNotEmpty) _gitLineMarkers.value = const {};
      return;
    }
    GitProvider? gitProvider;
    try {
      gitProvider = context.read<GitProvider?>();
    } catch (_) {}
    final repoPath = gitProvider?.currentRepoPath;
    if (repoPath == null || !p.isWithin(repoPath, path)) {
      _gitBaseContent = null;
      if (_gitLineMarkers.value.isNotEmpty) _gitLineMarkers.value = const {};
      return;
    }
    final relPath = p.relative(path, from: repoPath).replaceAll(r'\', '/');
    try {
      final content = await gitProvider!.gitService.getFileContentAtRef(repoPath, ':0', relPath)
          ?? await gitProvider.gitService.getFileContentAtRef(repoPath, 'HEAD', relPath);
      if (!mounted || _currentLoadedPath != path) return;
      _gitBaseContent = content?.replaceAll('\r\n', '\n');
      _recomputeGitDiff();
    } catch (_) {
      _gitBaseContent = null;
      _recomputeGitDiff();
    }
  }

  Future<void> _recomputeGitDiff() async {
    if (!mounted || _controller == null) return;
    if (_gitBaseContent == null) {
      GitProvider? gitProvider;
      try {
        gitProvider = context.read<GitProvider?>();
      } catch (_) {}
      final path = _currentLoadedPath;
      if (path != null && gitProvider != null) {
        final status = gitProvider.getFileStatus(path);
        if (status?.statusType == GitFileStatusType.untracked) {
          final linesCount = _controller!.codeLines.length;
          final markers = <int, GitGutterDiffType>{};
          for (int i = 0; i < linesCount; i++) {
            markers[i] = GitGutterDiffType.added;
          }
          if (mounted) _gitLineMarkers.value = markers;
          return;
        }
      }
      if (_gitLineMarkers.value.isNotEmpty) _gitLineMarkers.value = const {};
      return;
    }
    final currentText = _controller!.text.replaceAll('\r\n', '\n');
    final markers = await GitDiffHelper.computeLineDiffAsync(_gitBaseContent!, currentText);
    if (mounted) {
      _gitLineMarkers.value = markers;
    }
  }

  void _onDiagnosticsChanged() {
    if (!mounted || _controller == null) return;
    _controller?.forceRepaint();
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _toolbarController = CodeEditorToolbarController(
      focusNode: _focusNode,
      filePathGetter: () => _currentLoadedPath ?? widget.filePath,
    );
    LspDiagnosticsStore.instance.addListener(_onDiagnosticsChanged);
    _loadFileContent();
  }

  @override
  void didUpdateWidget(covariant CodeEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.rootPath != widget.rootPath) {
      if (_controller != null && oldWidget.filePath != null) {
        try {
          final provider = _getTabProvider(context);
          final oldPath = p.normalize(oldWidget.filePath!);
          final oldTab = provider.openTabs.where((t) => p.equals(t.path, oldPath)).firstOrNull;
          if (oldTab != null && oldTab.isLoaded) {
            final current = _controller!.text.replaceAll('\r\n', '\n');
            final normalizedOriginal = oldTab.originalContent.replaceAll('\r\n', '\n');
            oldTab.content = current;
            oldTab.isModified = current != normalizedOriginal;
            _saveCurrentTabScrollState(oldTab);
          }
        } catch (_) {}
      }
      _loadFileContent();
    }
  }

  @override
  void dispose() {
    try {
      final provider = _getTabProvider(context);
      provider.registerSaveHandler(null);
      provider.registerSearchHandlers();
    } catch (_) {}
    LspDiagnosticsStore.instance.removeListener(_onDiagnosticsChanged);
    if (_currentLoadedPath != null) {
      LspManager.instance.onFileClosed(_currentLoadedPath!);
    }
    _toolbarController.hide(context);
    final currentTab = _getCurrentTab();
    _saveCurrentTabScrollState(currentTab);
    _scrollController?.verticalScroller.dispose();
    _scrollController?.horizontalScroller.dispose();
    _scrollController?.dispose();
    _findController?.dispose();
    _findController = null;
    _gitDiffDebounceTimer?.cancel();
    _gitLineMarkers.dispose();
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted || _controller == null) return;

    final newCursorLine = _controller?.selection.baseIndex ?? -1;
    if (_currentCursorLine != newCursorLine) {
      _currentCursorLine = newCursorLine;
      if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }

    final currentTab = _getCurrentTab();
    if (currentTab == null || !currentTab.isLoaded) return;
    // 确保当前活跃 tab 与当前加载的控制器路径严格一致，杜绝切换过程中误写其他 tab
    if (!p.equals(currentTab.path, _currentLoadedPath ?? '')) return;

    final current = _controller!.text.replaceAll('\r\n', '\n');
    final normalizedOriginal = currentTab.originalContent.replaceAll('\r\n', '\n');
    final isModified = current != normalizedOriginal;

    // 若文本内容与脏状态均未变化（例如光标移动、选区变动、代理绑定），直接跳过
    if (currentTab.content == current && currentTab.isModified == isModified) {
      return;
    }

    currentTab.content = current;
    currentTab.isModified = isModified;

    // LSP 文档变更增量/全量同步及本地语法诊断兜底
    if (_currentLoadedPath != null && _controller != null) {
      _lspCoordinator.onFileChanged(
        _currentLoadedPath!,
        current,
        _controller!.codeLines,
      );
    }

    void notifyProvider() {
      if (!mounted) return;
      try {
        final provider = _getTabProvider(context);
        provider.updateActiveTabContent(current, isModified: isModified);
      } catch (_) {}
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyProvider());
    } else {
      notifyProvider();
    }

    _gitDiffDebounceTimer?.cancel();
    _gitDiffDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _recomputeGitDiff();
    });
  }

  /// 依据 LSP 实时诊断结果，为当前行的代码文本施加波浪下划线（保留已有代码高亮色彩）
  TextSpan _buildDiagnosticSpans({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    return _diagnosticController.buildDiagnosticSpans(
      context: context,
      filePath: _currentLoadedPath ?? widget.filePath,
      index: index,
      codeLine: codeLine,
      textSpan: textSpan,
      style: style,
    );
  }

  Widget _buildDiagnosticBanner(BuildContext context, List<LspDiagnostic> diags, int lineIndex) {
    return _diagnosticController.buildDiagnosticBanner(
      context: context,
      filePath: _currentLoadedPath ?? widget.filePath,
      controller: _controller,
      diags: diags,
      lineIndex: lineIndex,
    );
  }

  Future<bool> _saveFile({bool showToast = false}) async {
    final currentPath = widget.filePath;
    if (currentPath == null || currentPath.isEmpty || _controller == null) {
      return false;
    }
    final rootPath = widget.rootPath;
    final String fullFilePath = (rootPath == null || rootPath.isEmpty || p.isAbsolute(currentPath))
        ? currentPath
        : p.join(rootPath, currentPath);

    try {
      FileWatcherService.instance.markRecentlySaved(fullFilePath);
      final content = _controller!.text.replaceAll('\r\n', '\n');
      await FileService.instance.saveFile(fullFilePath, content);
      if (mounted) {
        try {
          final provider = _getTabProvider(context);
          final tab = provider.activeTab;
          if (tab != null) {
            tab.content = content;
            tab.originalContent = content;
            tab.isModified = false;
          }
          provider.setModified(false);
        } catch (_) {}
        if (showToast) {
          final l10n = AppLocalizations.of(context);
          DialogUtils.showSuccessToast(context, l10n?.saveSuccess ?? '保存成功');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        DialogUtils.showErrorToast(
          context,
          l10n?.saveFailed(e.toString()) ?? '保存失败: $e',
        );
      }
      return false;
    }
  }

  void _syncExternalContentIfChanged(TabProvider provider) {
    final activeTab = provider.activeTab;
    if (activeTab == null || _controller == null || _currentLoadedPath == null) return;
    if (!activeTab.isLoaded) return;
    // 仅在当前编辑器已经加载了当前激活 tab 的内容时，才响应外部变动。杜绝标签切换过程中的状态混淆！
    if (!p.equals(activeTab.path, _currentLoadedPath!)) return;

    // 1. 外部修改冲突处理（本地已修改，外部也发生修改）
    if (activeTab.hasExternalConflict && !_isShowingConflictDialog) {
      _isShowingConflictDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final result = await DialogUtils.showFileConflictDialog(
          context,
          fileName: activeTab.name,
        );
        if (!mounted) return;
        _isShowingConflictDialog = false;
        final reload = result == FileConflictResult.reloadFromDisk;
        await provider.resolveConflict(activeTab, reloadFromDisk: reload);
        if (reload && mounted && p.equals(activeTab.path, _currentLoadedPath!)) {
          _controller?.removeListener(_onTextChanged);
          _controller?.text = activeTab.content;
          _controller?.addListener(_onTextChanged);
          setState(() {});
        }
      });
      return;
    }

    // 2. 未修改文件外部静默热更新
    if (!activeTab.isModified && activeTab.content != _controller!.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null || !p.equals(activeTab.path, _currentLoadedPath!)) return;
        _controller?.removeListener(_onTextChanged);
        _controller?.text = activeTab.content;
        _controller?.addListener(_onTextChanged);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final tabProvider = _getTabProvider(context, listen: true);
      _syncExternalContentIfChanged(tabProvider);
      if (tabProvider.navigationTarget != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleNavigationTarget(tabProvider);
          }
        });
      }
    } catch (_) {}

    final searchProvider = context.watch<SearchProvider?>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSearchHighlight(searchProvider);
      }
    });

    try {
      final gitProvider = context.watch<GitProvider?>();
      final currentStatus = (_currentLoadedPath != null && gitProvider != null)
          ? gitProvider.getFileStatus(_currentLoadedPath!)
          : null;
      final gitStateKey = '${gitProvider?.currentRepoPath}_${gitProvider?.currentBranch}_${currentStatus?.statusType}_${currentStatus?.isStaged}_${currentStatus?.originalPath}_${gitProvider?.totalChangedCount}';
      if (_lastGitStateKey != gitStateKey) {
        _lastGitStateKey = gitStateKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateGitBaseContent();
        });
      }
    } catch (_) {}

    final l10n = AppLocalizations.of(context);
    final hasNoProject = widget.rootPath == null || widget.rootPath!.trim().isEmpty;
    final hasNoFile = widget.filePath == null || widget.filePath!.trim().isEmpty;

    if (hasNoProject && hasNoFile) {
      return Center(
        child: Text(
          l10n?.noOpenDirectory ?? "当前未打开项目",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (hasNoFile) {
      return Center(
        child: Text(
          l10n?.noOpenFile ?? "当前未打开文件",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    // 获取独立的代码编辑器主题与字号（若处于无 Provider 测试环境则安全降级）
    EditorTheme activeTheme = EditorTheme.atomOneDark;
    double activeFontSize = 14.0;
    bool activeWordWrap = true;
    bool enableVirtualKeyboard = false;
    VirtualKeyboardConfig? keyboardConfig;
    AppFontItem activeEditorFont = AppFonts.editorJetBrainsMono;
    bool showLineNumbers = true;
    bool pinLineNumbers = true;
    bool enableLspCompletion = true;
    try {
      final settings = _getSettingsProvider(context, listen: true);
      activeTheme = settings.editorTheme;
      activeFontSize = settings.fontSize;
      activeWordWrap = settings.wordWrap;
      showLineNumbers = settings.showLineNumbers;
      pinLineNumbers = settings.pinLineNumbers;
      enableVirtualKeyboard = settings.enableVirtualKeyboard;
      keyboardConfig = settings.virtualKeyboardConfig;
      activeEditorFont = settings.editorFont;
      enableLspCompletion = settings.enableLspCompletion;
      if (_currentIndentSize != null && _currentIndentSize != settings.indentSize) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFileContent();
        });
      }
    } catch (_) {}

    final double displayFontSize = _activeZoomFontSize ?? activeFontSize;

    return Container(
      color: activeTheme.backgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: Listener(
              key: _editorContainerKey,
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _handlePointerDown(event, activeFontSize, activeEditorFont),
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IgnorePointer(
                    ignoring: _isPinching,
                    child: Builder(
                      builder: (context) {
                        final promptsBuilder = SmartCodeAutocompletePromptsBuilder(
                          controller: controller,
                          filePath: _currentLoadedPath ?? widget.filePath,
                          enableLspCompletion: enableLspCompletion,
                        );
                        return EditorOverlayScope(
                          key: ValueKey(_currentLoadedPath),
                          child: CodeAutocomplete(
                            viewBuilder: (context, notifier, onSelected) {
                              promptsBuilder.activeNotifier = notifier;
                              return CodeAutocompleteView(
                                notifier: notifier,
                                onSelected: onSelected,
                              );
                            },
                            promptsBuilder: promptsBuilder,
                            child: CodeEditor(
                              key: ValueKey(_currentLoadedPath),
                              controller: controller,
                              findController: _findController,
                              focusNode: _focusNode,
                              scrollController: _scrollController,
                              wordWrap: activeWordWrap,
                              pinLineNumbers: pinLineNumbers,
                              toolbarController: _toolbarController,
                              margin: EdgeInsets.zero,
                              extraHorizontalScroll: 160.0,
                              padding: const EdgeInsets.fromLTRB(6.0, 0.0, 0.0, 0.0),
                              leadingDivider: showLineNumbers
                                  ? Container(
                                      width: 1.0,
                                      color: activeTheme.gutterTextColor.withValues(alpha: 0.25),
                                    )
                                  : null,
                              style: CodeEditorStyle(
                                fontSize: displayFontSize,
                                textColor: activeTheme.textColor,
                                backgroundColor: activeTheme.backgroundColor,
                                cursorColor: activeTheme.cursorColor,
                                cursorLineColor: activeTheme.cursorLineColor,
                                selectionColor: activeTheme.selectionColor,
                                highlightColor: const Color(0xFFFFEB3B).withValues(alpha: 0.45),
                                fontFamily: activeEditorFont.fontFamily,
                                fontFamilyFallback: activeEditorFont.fallback,
                                codeTheme: CodeHighlightTheme(
                                  languages: SyntaxHighlightHelper.getLanguagesForFile(_currentLoadedPath ?? widget.filePath),
                                  theme: activeTheme.highlightTheme,
                                ),
                              ),
                              indicatorBuilder: showLineNumbers
                                  ? (context, editingController, chunkController, notifier) {
                                      return Row(
                                        children: [
                                          DefaultCodeLineNumber(
                                            controller: editingController,
                                            notifier: notifier,
                                            lineDecorationBuilder: (lineIndex) {
                                              final filePath = _currentLoadedPath ?? widget.filePath;
                                              if (filePath == null) return null;
                                              final diags = LspDiagnosticsStore.instance.getDiagnosticsForLine(filePath, lineIndex);
                                              if (diags.isEmpty) return null;
                                              final hasError = diags.any((d) => d.severity == LspDiagnosticSeverity.error);
                                              final hasWarning = diags.any((d) => d.severity == LspDiagnosticSeverity.warning);
                                              final dotColor = hasError
                                                  ? Colors.redAccent
                                                  : (hasWarning ? Colors.amberAccent : Colors.lightBlueAccent);
                                              return DiagnosticGutterDotDecoration(color: dotColor);
                                            },
                                            textStyle: TextStyle(
                                              color: activeTheme.gutterTextColor,
                                              fontSize: (displayFontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize),
                                              fontFamily: activeEditorFont.fontFamily,
                                              fontFamilyFallback: activeEditorFont.fallback,
                                              height: 1.4,
                                            ),
                                            focusedTextStyle: TextStyle(
                                              color: activeTheme.focusedGutterTextColor,
                                              fontSize: (displayFontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize),
                                              fontWeight: FontWeight.bold,
                                              fontFamily: activeEditorFont.fontFamily,
                                              fontFamilyFallback: activeEditorFont.fallback,
                                              height: 1.4,
                                            ),
                                          ),
                                          GitDiffGutterIndicator(
                                            width: 5.0,
                                            notifier: notifier,
                                            diffMarkers: _gitLineMarkers,
                                          ),
                                          DefaultCodeChunkIndicator(
                                            width: 20,
                                            controller: chunkController,
                                            notifier: notifier,
                                            painter: DefaultCodeChunkIndicatorPainter(
                                              color: activeTheme.gutterTextColor,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        );
                  },
                ),
              ),
                  // 双指缩放实时字号悬浮胶囊提示
                  if (_isPinching && _activeZoomFontSize != null)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: activeTheme.backgroundColor.computeLuminance() > 0.5
                                ? Colors.black.withValues(alpha: 0.75)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_activeZoomFontSize!.round()} px',
                            style: TextStyle(
                              color: activeTheme.backgroundColor.computeLuminance() > 0.5
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_currentCursorLine >= 0 && (_currentLoadedPath ?? widget.filePath) != null) ...[
            Builder(
              builder: (ctx) {
                final diags = LspDiagnosticsStore.instance.getDiagnosticsForLine(
                  _currentLoadedPath ?? widget.filePath,
                  _currentCursorLine,
                );
                if (diags.isEmpty) return const SizedBox.shrink();
                return _buildDiagnosticBanner(ctx, diags, _currentCursorLine);
              },
            ),
          ],
          if (enableVirtualKeyboard && keyboardConfig != null && keyboardConfig.hasKeys)
            VirtualKeyboardWidget(
              controller: controller,
              focusNode: _focusNode,
              config: keyboardConfig,
            ),
        ],
      ),
    );
  }

  Future<void> _loadFileContent() async {
    final rootPath = widget.rootPath;
    final filePath = widget.filePath;
    final hasNoProject = rootPath == null || rootPath.trim().isEmpty;
    final hasNoFile = filePath == null || filePath.trim().isEmpty;

    if (hasNoFile) {
      _currentLoadedPath = null;
      _gitBaseContent = null;
      if (_gitLineMarkers.value.isNotEmpty) _gitLineMarkers.value = const {};
      _controller?.removeListener(_onTextChanged);
      _controller?.dispose();
      _controller = null;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            final provider = _getTabProvider(context);
            provider.setModified(false);
            provider.registerSaveHandler(null);
          } catch (_) {}
        });
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    final String fullFilePath = (hasNoProject || p.isAbsolute(filePath))
        ? filePath
        : p.join(rootPath, filePath);

    int activeIndentSize = 2;
    try {
      activeIndentSize = _getSettingsProvider(context).indentSize;
    } catch (_) {}

    if (_currentLoadedPath != null &&
        p.equals(_currentLoadedPath!, fullFilePath) &&
        _controller != null &&
        _currentIndentSize == activeIndentSize) {
      return;
    }

    final provider = _getTabProvider(context);
    final cleanPath = p.normalize(fullFilePath);
    final tab = provider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;

    // 内存复用极速通道：若标签页已经在内存中，直接同步切换控制器，0毫秒响应，彻底免去 isLoading 转圈与销毁重建
    if (tab != null && tab.isLoaded) {
      final oldController = _controller;
      oldController?.removeListener(_onTextChanged);

      final normalizedContent = tab.content.replaceAll('\r\n', '\n');
      final normalizedOriginal = tab.originalContent.replaceAll('\r\n', '\n');
      tab.content = normalizedContent;
      tab.originalContent = normalizedOriginal;

      final newController = CodeLineEditingController.fromText(
        normalizedContent,
        CodeLineOptions(indentSize: activeIndentSize),
        _buildDiagnosticSpans,
      );

      _controller = newController;
      SearchProvider? searchProvider;
      try {
        searchProvider = context.read<SearchProvider?>();
      } catch (_) {}
      final initialFindValue = _buildCurrentFindValue(searchProvider);
      _findController?.dispose();
      _findController = CodeFindController(
        newController,
        initialFindValue,
      );
      if (initialFindValue.option.pattern.isNotEmpty) {
        _findController!.findInputController.text = initialFindValue.option.pattern;
      }
      _currentLoadedPath = fullFilePath;
      _currentIndentSize = activeIndentSize;
      _errorMessage = null;
      _isLoading = false;

      _lspCoordinator.onFileOpened(
        fullFilePath,
        normalizedContent,
        newController.codeLines,
        workspaceRoot: widget.rootPath,
      );

      // 必须在 _controller 和 tab 状态准备就绪后再挂载文本监听，避免初始化阶段被误判为脏
      newController.addListener(_onTextChanged);

      oldController?.dispose();

      _restoreTabScrollState(tab);

      try {
        provider.setModified(tab.isModified);
        provider.registerSaveHandler(() => _saveFile());
        provider.registerSearchHandlers(
          findNext: _handleFindNext,
          findPrevious: _handleFindPrevious,
          replace: _handleReplaceCurrent,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleNavigationTarget(provider);
            _syncSearchHighlight(searchProvider);
            _updateGitBaseContent();
          }
        });
      }
      return;
    }

    // 首次冷加载文件（未在内存中）：
    final int requestVersion = ++_currentLoadVersion;

    // 仅在当前未展示任何代码时才显示 loading，已有代码切换时保持编辑器容器，避免白屏闪烁
    if (_controller == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawDiskContent = await FileService.instance.readFileContent(fullFilePath);
      final diskContent = rawDiskContent.replaceAll('\r\n', '\n');

      if (!mounted || requestVersion != _currentLoadVersion) {
        return;
      }

      // 大文本异步分行：对于超过 64KB 的文本在后台 Isolate 完成解析，彻底杜绝主 UI 线程掉帧
      final CodeLines codeLines = diskContent.length > 65536
          ? await diskContent.codeLinesAsync
          : diskContent.codeLines;

      if (!mounted || requestVersion != _currentLoadVersion) {
        return;
      }

      final oldController = _controller;
      oldController?.removeListener(_onTextChanged);

      final newController = CodeLineEditingController(
        codeLines: codeLines,
        options: CodeLineOptions(indentSize: activeIndentSize),
        spanBuilder: _buildDiagnosticSpans,
      );

      _controller = newController;
      SearchProvider? searchProvider;
      try {
        searchProvider = context.read<SearchProvider?>();
      } catch (_) {}
      final initialFindValue = _buildCurrentFindValue(searchProvider);
      _findController?.dispose();
      _findController = CodeFindController(
        newController,
        initialFindValue,
      );
      if (initialFindValue.option.pattern.isNotEmpty) {
        _findController!.findInputController.text = initialFindValue.option.pattern;
      }
      _currentLoadedPath = fullFilePath;
      _currentIndentSize = activeIndentSize;
      _errorMessage = null;

      Future.microtask(() {
        if (!mounted || _currentLoadedPath != fullFilePath) return;
        _lspCoordinator.onFileOpened(
          fullFilePath,
          diskContent,
          newController.codeLines,
          workspaceRoot: widget.rootPath,
        );
      });

      if (tab != null) {
        tab.content = diskContent;
        tab.originalContent = diskContent;
        tab.isLoaded = true;
        tab.isModified = false;
      }

      newController.addListener(_onTextChanged);
      oldController?.dispose();

      if (tab != null) {
        _restoreTabScrollState(tab);
      }

      if (mounted) {
        try {
          provider.setModified(tab?.isModified ?? false);
          provider.registerSaveHandler(() => _saveFile());
          provider.registerSearchHandlers(
            findNext: _handleFindNext,
            findPrevious: _handleFindPrevious,
            replace: _handleReplaceCurrent,
          );
        } catch (_) {}
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleNavigationTarget(provider);
            _syncSearchHighlight(searchProvider);
            _updateGitBaseContent();
          }
        });
      }
    } catch (e) {
      if (!mounted || requestVersion != _currentLoadVersion) return;
      _errorMessage = '$e';
    } finally {
      if (mounted && requestVersion == _currentLoadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }
}