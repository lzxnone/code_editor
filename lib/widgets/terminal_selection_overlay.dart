// ignore_for_file: implementation_imports
import 'dart:math';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/xterm.dart' as xterm;

enum _DraggingHandle { none, start, end }

/// 终端选区悬浮工具栏展示位置策略
enum TerminalToolbarPlacement {
  aboveStart,
  belowEnd,
  top,

  /// 选区整体位于可见视口下方时：贴视口底边（紧贴软键盘 / 虚拟按键栏上方）显示，
  /// 与代码编辑区的 `EditorToolbarPlacement.bottom` 行为一致
  bottom,
  smart,
}

/// 终端文字框选交互叠加层
/// 包含双端拖动手柄（Start/End Handle）与智能浮动上下文操作菜单（复制、粘贴、全选），
/// 参考代码编辑区设计，支持拖动手柄至视口边缘时平滑自动滚动，并在手指松开或手势取消时
/// 100% 可靠停止滚动，绝不发生松手后依然自动滚动的 Bug。
class TerminalSelectionOverlay extends StatefulWidget {
  final xterm.Terminal terminal;
  final xterm.TerminalController controller;
  final GlobalKey<xterm.TerminalViewState> terminalViewKey;
  final FocusNode focusNode;
  final ScrollController? scrollController;
  final Widget child;

  const TerminalSelectionOverlay({
    super.key,
    required this.terminal,
    required this.controller,
    required this.terminalViewKey,
    required this.focusNode,
    this.scrollController,
    required this.child,
  });

  @override
  State<TerminalSelectionOverlay> createState() => _TerminalSelectionOverlayState();
}

class _TerminalSelectionOverlayState extends State<TerminalSelectionOverlay> {
  OverlayEntry? _menuOverlayEntry;
  _DraggingHandle _dragging = _DraggingHandle.none;
  bool _isScrolling = false;
  bool _isPointerSelecting = false;
  Offset? _lastActiveAnchor;

  /// 记录上一次构建时是否存在有效选区：
  /// 用于在缓冲区变更（clear / ESC[3J 裁掉选区所在行）导致锚点失效时，
  /// 及时收起残留的手柄与菜单，同时避免高频输出的额外开销。
  bool _lastHadSelection = false;

  // 拖动手柄时的自动滚动引擎（参考 re_editor 架构，采用带严格 guard 条件的循环与全局指针路由保底）
  bool _isAutoScrolling = false;
  Offset? _lastDragGlobalPosition;
  DateTime? _lastAutoScrollTime;
  DateTime? _dwellStartTime;
  ScrollableState? _cachedScrollableState;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
    // 监听底层终端缓冲区变化：shell 的 clear / Ctrl+L（ESC[3J 清除回滚缓冲）会让
    // 选区锚点随被裁掉的行一起失效，此时 controller 本身不会收到通知，
    // 必须由这里主动清理，否则会残留悬空的拖动手柄与浮动菜单。
    widget.terminal.addListener(_onTerminalBufferChanged);
    // 注入全局指针路由：无论手柄被何种异常情况打断，只要系统检测到任何 PointerUp 或 PointerCancel，立即停止滚动！
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void didUpdateWidget(TerminalSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
    }
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalBufferChanged);
      widget.terminal.addListener(_onTerminalBufferChanged);
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerEvent);
    _stopAutoScroll();
    widget.controller.removeListener(_onSelectionChanged);
    widget.terminal.removeListener(_onTerminalBufferChanged);
    _hideMenu();
    super.dispose();
  }

  void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_dragging != _DraggingHandle.none) {
        _endCurrentHandleDrag();
      }
    }
  }

  RenderTerminal? get _renderTerminal {
    return widget.terminalViewKey.currentState?.renderTerminal;
  }

  Rect? _getTerminalRect() {
    final render = _renderTerminal;
    if (render == null || !render.hasSize) return null;
    final topLeft = render.localToGlobal(Offset.zero);
    return topLeft & render.size;
  }

  ScrollPosition? get _scrollPosition {
    if (widget.scrollController?.hasClients ?? false) {
      return widget.scrollController!.position;
    }
    if (_cachedScrollableState != null && _cachedScrollableState!.mounted) {
      return _cachedScrollableState!.position;
    }
    _cachedScrollableState = _findScrollableState();
    return _cachedScrollableState?.position;
  }

  ScrollableState? _findScrollableState() {
    final rootContext = widget.terminalViewKey.currentContext;
    if (rootContext == null) return null;

    ScrollableState? found;
    void search(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = element.state as ScrollableState;
        return;
      }
      element.visitChildren(search);
    }

    rootContext.visitChildElements(search);
    return found;
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      _lastHadSelection = false;
      _hideMenu();
      setState(() {});
      return;
    }

    _lastHadSelection = true;

    // 若非正在拖动手柄或滑动，展示菜单
    if (_dragging == _DraggingHandle.none && !_isScrolling && !_isPointerSelecting) {
      _updateLastActiveAnchorDefault();
      _showMenu();
    }
    setState(() {});
  }

  /// 底层终端缓冲区发生变化（可能是普通输出，也可能是 clear / ESC[3J 裁掉选区所在行）。
  /// 一旦选区锚点失效，controller 不会收到通知，需在此清理残留的手柄与菜单。
  void _onTerminalBufferChanged() {
    if (!mounted) return;
    // 快速短路：当前没有任何选区相关 UI 时，完全不做额外工作（高频输出场景零成本）
    if (!_lastHadSelection && _menuOverlayEntry == null) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection != null && !selection.isCollapsed) {
      _lastHadSelection = true;
      return;
    }
    _lastHadSelection = false;
    _hideMenu();
    // clearSelection() 会通知 controller，从而走 _onSelectionChanged 收起手柄并重建
    widget.controller.clearSelection();
  }

  void _updateLastActiveAnchorDefault() {
    final render = _renderTerminal;
    final selection = widget.controller.selection;
    if (render == null || selection == null || selection.isCollapsed) return;

    final range = selection.normalized;
    final endOffset = render.getOffset(range.end);
    final globalEnd = render.localToGlobal(
      endOffset + Offset(0, render.cellSize.height),
    );
    _lastActiveAnchor = globalEnd;
  }

  void _hideMenu() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
  }

  void _showMenu({Offset? targetAnchor, TerminalToolbarPlacement? placement}) {
    _hideMenu();
    if (!mounted) return;

    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;

    final render = _renderTerminal;
    if (render == null || !render.hasSize) return;

    final range = selection.normalized;

    // 防御：若缓冲区曾被裁剪/重建导致锚点行号越界，视为无效选区并清理
    if (range.begin.y >= widget.terminal.buffer.height ||
        range.end.y >= widget.terminal.buffer.height) {
      widget.controller.clearSelection();
      return;
    }

    final double lineHeight = render.cellSize.height;
    final terminalRect = _getTerminalRect();

    // --- 端点可见性判定（与编辑区 _MobileToolbarLayoutDelegate 的定位决策保持一致） ---
    final Offset startLocal = render.getOffset(range.begin) + Offset(0, lineHeight);
    final Offset endLocal = render.getOffset(range.end) + Offset(0, lineHeight);
    bool isEndpointOnScreen(Offset local) {
      return local.dy >= -1.0 &&
          local.dy <= render.size.height + 1.0 &&
          local.dx >= -1.0 &&
          local.dx <= render.size.width + 1.0;
    }

    final bool isStartOnScreen = isEndpointOnScreen(startLocal);
    final bool isEndOnScreen = isEndpointOnScreen(endLocal);
    final bool isNeitherEndpointOnScreen = !isStartOnScreen && !isEndOnScreen;

    final int lastVisibleRow = render.getCellOffset(Offset(0, render.size.height)).y;
    final int firstVisibleRow = render.getCellOffset(Offset.zero).y;

    /// 选区整体位于可见视口下方（屏幕下方）
    final bool isEntirelyBelowViewport =
        isNeitherEndpointOnScreen && range.begin.y > lastVisibleRow;

    /// 选区整体位于可见视口上方
    final bool isEntirelyAboveViewport =
        isNeitherEndpointOnScreen && range.end.y < firstVisibleRow;

    final bool isMultiline = (range.end.y - range.begin.y) >= 2;

    TerminalToolbarPlacement effectivePlacement;

    if (placement != null && placement != TerminalToolbarPlacement.smart) {
      // 调用方显式指定（拖动手柄松手、全选等）：原样尊重
      effectivePlacement = placement;
    } else if (isEntirelyBelowViewport) {
      // 选区整体在屏幕下方：贴视口底部显示，避免把菜单钉到顶部或压在选区文字上
      effectivePlacement = TerminalToolbarPlacement.bottom;
    } else if (isEntirelyAboveViewport) {
      // 选区整体在屏幕上方：置于顶部安全区
      effectivePlacement = TerminalToolbarPlacement.top;
    } else if (placement == TerminalToolbarPlacement.smart || !isMultiline) {
      // 单行选区 / 指针抬起：靠近选区端点，由布局代理就近翻转避让
      effectivePlacement = TerminalToolbarPlacement.smart;
    } else {
      // 多行选区：置于顶部安全区，绝不遮挡多行文本（既有行为）
      effectivePlacement = TerminalToolbarPlacement.top;
    }

    final Offset effectiveAnchor = targetAnchor ??
        _resolvePlacementAnchor(
          placement: effectivePlacement,
          render: render,
          beginOffset: range.begin,
          terminalRect: terminalRect,
          startLocal: startLocal,
          endLocal: endLocal,
        );
    _lastActiveAnchor = effectiveAnchor;

    final overlayState = Overlay.of(context, rootOverlay: true);

    _menuOverlayEntry = OverlayEntry(
      builder: (context) {
        return _TerminalContextMenuWidget(
          anchor: effectiveAnchor,
          placement: effectivePlacement,
          terminalRect: terminalRect,
          lineHeight: lineHeight,
          onCopy: _handleCopy,
          onPaste: _handlePaste,
          onSelectAll: _handleSelectAll,
          onDismiss: () {
            _hideMenu();
            widget.controller.clearSelection();
          },
        );
      },
    );

    overlayState.insert(_menuOverlayEntry!);
  }

  /// 依据展示位置策略换算菜单锚点（全局坐标）
  Offset _resolvePlacementAnchor({
    required TerminalToolbarPlacement placement,
    required RenderTerminal render,
    required xterm.CellOffset beginOffset,
    required Rect? terminalRect,
    required Offset startLocal,
    required Offset endLocal,
  }) {
    switch (placement) {
      case TerminalToolbarPlacement.top:
        return terminalRect != null
            ? Offset(terminalRect.center.dx, terminalRect.top)
            : render.localToGlobal(render.getOffset(beginOffset));
      case TerminalToolbarPlacement.bottom:
        return terminalRect != null
            ? Offset(terminalRect.center.dx, terminalRect.bottom)
            : render.localToGlobal(endLocal);
      case TerminalToolbarPlacement.aboveStart:
        return render.localToGlobal(startLocal);
      case TerminalToolbarPlacement.belowEnd:
      case TerminalToolbarPlacement.smart:
        return render.localToGlobal(endLocal);
    }
  }

  Future<void> _handleCopy() async {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      _hideMenu();
      return;
    }
    final text = widget.terminal.buffer.getText(selection);
    await Clipboard.setData(ClipboardData(text: text));
    _hideMenu();
    widget.controller.clearSelection();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        DialogUtils.showSuccessToast(context, l10n.copiedToClipboard);
      }
    }
  }

  Future<void> _handlePaste() async {
    _hideMenu();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      widget.terminal.paste(text);
      widget.controller.clearSelection();
    }
  }

  void _handleSelectAll() {
    final width = widget.terminal.viewWidth;
    final height = widget.terminal.buffer.height;
    widget.controller.setSelection(
      widget.terminal.buffer.createAnchor(0, 0),
      widget.terminal.buffer.createAnchor(max(0, width - 1), max(0, height - 1)),
      mode: xterm.SelectionMode.line,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showMenu(placement: TerminalToolbarPlacement.top);
      }
    });
  }

  // --- 手柄拖拽与边缘自动滚动逻辑（参考 re_editor 架构） ---

  double _calculateAutoScrollVelocity({
    required double pointerPosition,
    required double viewportDimension,
    required double edgeThreshold,
    required bool isStartEdge,
    required double minVelocity,
    required double edgeVelocity,
    required double maxVelocity,
    required double maxPullDistance,
  }) {
    if (isStartEdge) {
      if (pointerPosition >= edgeThreshold) {
        return 0.0;
      }
      if (pointerPosition >= 0.0) {
        final double ratio = (edgeThreshold - pointerPosition) / edgeThreshold;
        return minVelocity + (edgeVelocity - minVelocity) * ratio;
      } else {
        final double pullDistance = -pointerPosition;
        final double ratio = (pullDistance / maxPullDistance).clamp(0.0, 1.0);
        final double factor = ratio * sqrt(ratio);
        return edgeVelocity + (maxVelocity - edgeVelocity) * factor;
      }
    } else {
      final double triggerPos = viewportDimension - edgeThreshold;
      if (pointerPosition <= triggerPos) {
        return 0.0;
      }
      if (pointerPosition <= viewportDimension) {
        final double ratio = (pointerPosition - triggerPos) / edgeThreshold;
        return minVelocity + (edgeVelocity - minVelocity) * ratio;
      } else {
        final double pullDistance = pointerPosition - viewportDimension;
        final double ratio = (pullDistance / maxPullDistance).clamp(0.0, 1.0);
        final double factor = ratio * sqrt(ratio);
        return edgeVelocity + (maxVelocity - edgeVelocity) * factor;
      }
    }
  }

  void _autoScrollWhenDragging() {
    if (_isAutoScrolling) return;
    _isAutoScrolling = true;
    _lastAutoScrollTime = DateTime.now();
    _dwellStartTime = null;
    _runAutoScrollLoop();
  }

  void _runAutoScrollLoop() {
    Future.delayed(const Duration(milliseconds: 16), () {
      if (!mounted || _dragging == _DraggingHandle.none) {
        _isAutoScrolling = false;
        _stopAutoScroll();
        return;
      }
      _performAutoScrollStep();
      if (_dragging != _DraggingHandle.none) {
        _runAutoScrollLoop();
      } else {
        _isAutoScrolling = false;
        _stopAutoScroll();
      }
    });
  }

  void _stopAutoScroll() {
    _isAutoScrolling = false;
    _lastAutoScrollTime = null;
    _dwellStartTime = null;
    _lastDragGlobalPosition = null;
  }

  bool _performAutoScrollStep() {
    if (_dragging == _DraggingHandle.none || _lastDragGlobalPosition == null) {
      _stopAutoScroll();
      return false;
    }

    final render = _renderTerminal;
    final position = _scrollPosition;
    if (render == null || !render.hasSize || position == null || !position.hasContentDimensions) {
      return false;
    }

    final now = DateTime.now();
    final double dt;
    if (_lastAutoScrollTime == null) {
      dt = 0.016;
    } else {
      final double elapsed = now.difference(_lastAutoScrollTime!).inMicroseconds / 1000000.0;
      dt = elapsed.clamp(0.005, 0.05);
    }
    _lastAutoScrollTime = now;

    final localPos = render.globalToLocal(_lastDragGlobalPosition!);
    final double lineHeight = render.cellSize.height;
    final double vEdgeThreshold = max(36.0, lineHeight * 1.8);
    const double vMaxPullDistance = 45.0;
    final double viewportHeight = render.size.height;
    final selection = widget.controller.selection;
    if (selection == null) return false;
    final range = selection.normalized;

    bool scrolled = false;

    if (localPos.dy < vEdgeThreshold && position.pixels > position.minScrollExtent) {
      // 若是结束手柄向上收缩，不能越过起始手柄所在行
      if (_dragging == _DraggingHandle.end && range.end.y <= range.begin.y) {
        _dwellStartTime = null;
        return false;
      }

      _dwellStartTime ??= now;
      final double dwellSeconds = now.difference(_dwellStartTime!).inMicroseconds / 1000000.0;
      final double dwellMultiplier = dwellSeconds > 0.25
          ? 1.0 + ((dwellSeconds - 0.25) / 0.75).clamp(0.0, 1.0) * 2.5
          : 1.0;

      final double baseV = _calculateAutoScrollVelocity(
        pointerPosition: localPos.dy,
        viewportDimension: viewportHeight,
        edgeThreshold: vEdgeThreshold,
        isStartEdge: true,
        minVelocity: 70.0,
        edgeVelocity: 180.0,
        maxVelocity: 1500.0,
        maxPullDistance: vMaxPullDistance,
      );
      final double v = min(1600.0, baseV * dwellMultiplier);
      if (v > 0) {
        final double delta = v * dt;
        final double target = max(position.minScrollExtent, position.pixels - delta);
        if (target != position.pixels) {
          position.jumpTo(target);
          scrolled = true;
        }
      }
    } else if (localPos.dy > viewportHeight - vEdgeThreshold && position.pixels < position.maxScrollExtent) {
      // 若是起始手柄向下收缩，不能越过结束手柄所在行
      if (_dragging == _DraggingHandle.start && range.begin.y >= range.end.y) {
        _dwellStartTime = null;
        return false;
      }

      _dwellStartTime ??= now;
      final double dwellSeconds = now.difference(_dwellStartTime!).inMicroseconds / 1000000.0;
      final double dwellMultiplier = dwellSeconds > 0.25
          ? 1.0 + ((dwellSeconds - 0.25) / 0.75).clamp(0.0, 1.0) * 2.5
          : 1.0;

      final double baseV = _calculateAutoScrollVelocity(
        pointerPosition: localPos.dy,
        viewportDimension: viewportHeight,
        edgeThreshold: vEdgeThreshold,
        isStartEdge: false,
        minVelocity: 70.0,
        edgeVelocity: 180.0,
        maxVelocity: 1500.0,
        maxPullDistance: vMaxPullDistance,
      );
      final double v = min(1600.0, baseV * dwellMultiplier);
      if (v > 0) {
        final double delta = v * dt;
        final double target = min(position.maxScrollExtent, position.pixels + delta);
        if (target != position.pixels) {
          position.jumpTo(target);
          scrolled = true;
        }
      }
    } else {
      _dwellStartTime = null;
    }

    if (scrolled && _lastDragGlobalPosition != null) {
      _updateSelectionForCurrentDrag(_lastDragGlobalPosition!);
    }
    return scrolled;
  }

  void _updateSelectionForCurrentDrag(Offset globalPosition) {
    final render = _renderTerminal;
    final selection = widget.controller.selection;
    if (render == null || selection == null) return;

    final range = selection.normalized;
    final localPos = render.globalToLocal(globalPosition);
    final adjusted = Offset(localPos.dx, localPos.dy - render.cellSize.height / 2);
    final cell = render.getCellOffset(adjusted);

    if (_dragging == _DraggingHandle.start) {
      if (cell.isBefore(range.end) || cell.isEqual(range.end)) {
        widget.controller.setSelection(
          widget.terminal.buffer.createAnchorFromOffset(cell),
          widget.terminal.buffer.createAnchorFromOffset(range.end),
        );
        final newLocal = render.getOffset(cell);
        _lastActiveAnchor = render.localToGlobal(newLocal + Offset(0, render.cellSize.height));
      }
    } else if (_dragging == _DraggingHandle.end) {
      if (cell.isAfter(range.begin) || cell.isEqual(range.begin)) {
        widget.controller.setSelection(
          widget.terminal.buffer.createAnchorFromOffset(range.begin),
          widget.terminal.buffer.createAnchorFromOffset(cell),
        );
        final newLocal = render.getOffset(cell);
        _lastActiveAnchor = render.localToGlobal(
          newLocal + Offset(0, render.cellSize.height),
        );
      }
    }
    setState(() {});
  }

  void _onStartHandlePanStart(DragStartDetails details) {
    _dragging = _DraggingHandle.start;
    _isScrolling = false;
    _lastDragGlobalPosition = details.globalPosition;
    _hideMenu();
    _autoScrollWhenDragging();
  }

  void _onStartHandlePanUpdate(DragUpdateDetails details) {
    _lastDragGlobalPosition = details.globalPosition;
    _updateSelectionForCurrentDrag(details.globalPosition);
  }

  void _onStartHandlePanEnd(DragEndDetails details) {
    _endCurrentHandleDrag();
  }

  void _onEndHandlePanStart(DragStartDetails details) {
    _dragging = _DraggingHandle.end;
    _isScrolling = false;
    _lastDragGlobalPosition = details.globalPosition;
    _hideMenu();
    _autoScrollWhenDragging();
  }

  void _onEndHandlePanUpdate(DragUpdateDetails details) {
    _lastDragGlobalPosition = details.globalPosition;
    _updateSelectionForCurrentDrag(details.globalPosition);
  }

  void _onEndHandlePanEnd(DragEndDetails details) {
    _endCurrentHandleDrag();
  }

  void _onHandlePanCancel() {
    _endCurrentHandleDrag();
  }

  void _endCurrentHandleDrag() {
    if (_dragging == _DraggingHandle.none) return;
    final lastHandle = _dragging;
    _dragging = _DraggingHandle.none;
    _isScrolling = false;
    _stopAutoScroll();

    if (mounted) {
      setState(() {});
      if (widget.controller.selection != null && !widget.controller.selection!.isCollapsed) {
        _showMenu(
          targetAnchor: _lastActiveAnchor,
          placement: lastHandle == _DraggingHandle.start
              ? TerminalToolbarPlacement.aboveStart
              : TerminalToolbarPlacement.belowEnd,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    final hasSelection = selection != null && !selection.isCollapsed;
    final render = _renderTerminal;
    final overlayBox = context.findRenderObject() as RenderBox?;

    Offset? startHandleInOverlay;
    Offset? endHandleInOverlay;
    bool showStartHandle = false;
    bool showEndHandle = false;

    final bool isStartDragging = _dragging == _DraggingHandle.start;
    final bool isEndDragging = _dragging == _DraggingHandle.end;

    if (hasSelection && render != null && render.hasSize) {
      final range = selection.normalized;
      final startCellOffset = render.getOffset(range.begin);
      final endCellOffset = render.getOffset(range.end);

      final startPointInRender = startCellOffset + Offset(0, render.cellSize.height);
      final endPointInRender = endCellOffset + Offset(0, render.cellSize.height);

      final viewportHeight = render.size.height;
      final viewportWidth = render.size.width;

      // 正在拖拽的手柄绝对不能被隐藏或卸载！非拖拽时才做视口边界可见性过滤
      showStartHandle = isStartDragging || (
          startPointInRender.dy >= 0 &&
          startPointInRender.dy <= viewportHeight + render.cellSize.height &&
          startPointInRender.dx >= 0 &&
          startPointInRender.dx <= viewportWidth
      );

      showEndHandle = isEndDragging || (
          endPointInRender.dy >= 0 &&
          endPointInRender.dy <= viewportHeight + render.cellSize.height &&
          endPointInRender.dx >= 0 &&
          endPointInRender.dx <= viewportWidth
      );

      if (overlayBox != null && overlayBox.hasSize) {
        if (isStartDragging && _lastDragGlobalPosition != null) {
          final dragInOverlay = overlayBox.globalToLocal(_lastDragGlobalPosition!);
          final clampedY = dragInOverlay.dy.clamp(0.0, overlayBox.size.height);
          final clampedX = dragInOverlay.dx.clamp(0.0, overlayBox.size.width);
          startHandleInOverlay = Offset(clampedX, clampedY);
        } else {
          startHandleInOverlay = overlayBox.globalToLocal(render.localToGlobal(startPointInRender));
        }

        if (isEndDragging && _lastDragGlobalPosition != null) {
          final dragInOverlay = overlayBox.globalToLocal(_lastDragGlobalPosition!);
          final clampedY = dragInOverlay.dy.clamp(0.0, overlayBox.size.height);
          final clampedX = dragInOverlay.dx.clamp(0.0, overlayBox.size.width);
          endHandleInOverlay = Offset(clampedX, clampedY);
        } else {
          endHandleInOverlay = overlayBox.globalToLocal(render.localToGlobal(endPointInRender));
        }
      } else {
        startHandleInOverlay = startPointInRender;
        endHandleInOverlay = endPointInRender;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_dragging != _DraggingHandle.none) {
          // 正在拖动手柄时的自动滚动，不作为外部普通滚动处理，避免误打断手柄拖拽生命周期
          return false;
        }
        if (notification is ScrollStartNotification) {
          _isScrolling = true;
          _hideMenu();
        } else if (notification is ScrollUpdateNotification) {
          if (mounted) setState(() {});
        } else if (notification is ScrollEndNotification) {
          _isScrolling = false;
          if (hasSelection && mounted && _dragging == _DraggingHandle.none && !_isPointerSelecting) {
            _showMenu();
          }
        }
        return false;
      },
      child: Listener(
        onPointerDown: (event) {
          _isPointerSelecting = true;
        },
        onPointerMove: (event) {
          if (_isPointerSelecting) {
            _hideMenu();
          }
        },
        onPointerUp: (event) {
          _isPointerSelecting = false;
          if (_dragging != _DraggingHandle.none) {
            _endCurrentHandleDrag();
          } else if (!_isScrolling && widget.controller.selection != null && !widget.controller.selection!.isCollapsed) {
            _lastActiveAnchor = event.position;
            _showMenu(
              targetAnchor: _lastActiveAnchor,
              placement: TerminalToolbarPlacement.smart,
            );
          }
          setState(() {});
        },
        onPointerCancel: (event) {
          _isPointerSelecting = false;
          if (_dragging != _DraggingHandle.none) {
            _endCurrentHandleDrag();
          }
        },
        child: Stack(
          children: [
            widget.child,
            if (hasSelection && showStartHandle && startHandleInOverlay != null)
              Positioned(
                left: startHandleInOverlay.dx - 32.0,
                top: startHandleInOverlay.dy - 10.0,
                child: _TerminalSelectionHandle(
                  isStart: true,
                  lineHeight: render?.cellSize.height ?? 20.0,
                  onPanStart: _onStartHandlePanStart,
                  onPanUpdate: _onStartHandlePanUpdate,
                  onPanEnd: _onStartHandlePanEnd,
                  onPanCancel: _onHandlePanCancel,
                ),
              ),
            if (hasSelection && showEndHandle && endHandleInOverlay != null)
              Positioned(
                left: endHandleInOverlay.dx - 10.0,
                top: endHandleInOverlay.dy - 10.0,
                child: _TerminalSelectionHandle(
                  isStart: false,
                  lineHeight: render?.cellSize.height ?? 20.0,
                  onPanStart: _onEndHandlePanStart,
                  onPanUpdate: _onEndHandlePanUpdate,
                  onPanEnd: _onEndHandlePanEnd,
                  onPanCancel: _onHandlePanCancel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 终端选区端点拖动手柄组件（采用与编辑区一致的 Material 水滴造型手柄，兼顾触屏大热区与鼠标拖拽）
class _TerminalSelectionHandle extends StatelessWidget {
  final bool isStart;
  final double lineHeight;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback? onPanCancel;

  const _TerminalSelectionHandle({
    required this.isStart,
    required this.lineHeight,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onPanCancel,
  });

  @override
  Widget build(BuildContext context) {
    final type = isStart ? TextSelectionHandleType.left : TextSelectionHandleType.right;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(
              debugOwner: this,
              supportedDevices: <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.unknown,
              },
            ),
            (PanGestureRecognizer instance) {
              instance
                ..dragStartBehavior = DragStartBehavior.start
                ..onStart = onPanStart
                ..onUpdate = onPanUpdate
                ..onCancel = onPanCancel
                ..onEnd = onPanEnd;
            },
          ),
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: materialTextSelectionControls.buildHandle(
            context,
            type,
            lineHeight,
          ),
        ),
      ),
    );
  }
}

/// 终端选区悬浮工具栏布局代理：
/// 负责根据 TerminalToolbarPlacement、终端可见区域与屏幕顶界/软键盘安全区智能精确定位，
/// 确保菜单不超出屏幕、不遮挡光标手柄与文本
class _TerminalToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchor;
  final TerminalToolbarPlacement placement;
  final Rect? terminalRect;
  final double lineHeight;
  final MediaQueryData mediaQuery;

  _TerminalToolbarLayoutDelegate({
    required this.anchor,
    required this.placement,
    required this.terminalRect,
    required this.lineHeight,
    required this.mediaQuery,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 1. 计算可视安全区与屏幕顶界
    // 顶界：状态栏安全区 + 间距（悬浮于 rootOverlay，允许借用 AppBar/TabBar 空间）
    final double screenTop = mediaQuery.padding.top + 6.0;
    // 底部：排除软键盘 (viewInsets.bottom)、虚拟按键栏与安全区
    final double screenBottomWithoutKeyboard =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.bottom;
    final double safeBottom =
        min(terminalRect?.bottom ?? screenBottomWithoutKeyboard, screenBottomWithoutKeyboard) - 6.0;
    // 左右两端保留安全边距
    final double safeLeft = max(terminalRect?.left ?? 0.0, mediaQuery.padding.left) + 8.0;
    final double safeRight =
        min(terminalRect?.right ?? mediaQuery.size.width, mediaQuery.size.width - mediaQuery.padding.right) - 8.0;

    final double availableWidth = max(0.0, safeRight - safeLeft);

    // 水滴形手柄下挂高度约 26px，加上间距共 32px 避让距离
    const double handleClearance = 32.0;

    double x;
    double y;

    switch (placement) {
      case TerminalToolbarPlacement.top:
        // 多行选区或全选：置于屏幕顶端安全区居中，绝不遮挡终端多行文本
        x = safeLeft + (availableWidth - childSize.width) / 2.0;
        y = screenTop;
        break;

      case TerminalToolbarPlacement.aboveStart:
        // 在左端点上方弹出，若顶部空间不足则翻转到下方充分避让
        x = anchor.dx - childSize.width / 2.0;
        final double yAbove = anchor.dy - lineHeight - childSize.height - 8.0;
        if (yAbove >= screenTop) {
          y = yAbove;
        } else {
          y = anchor.dy + handleClearance;
        }
        break;

      case TerminalToolbarPlacement.belowEnd:
        // 在右端点下方弹出，若下方空间不足（例如靠近软键盘）则翻转到上方
        x = anchor.dx - childSize.width / 2.0;
        final double yBelow = anchor.dy + handleClearance;
        if (yBelow + childSize.height <= safeBottom) {
          y = yBelow;
        } else {
          y = anchor.dy - lineHeight - childSize.height - 8.0;
        }
        break;

      case TerminalToolbarPlacement.bottom:
        // 选区整体在视口下方：贴视口底边显示（紧贴软键盘 / 虚拟按键栏上方），
        // 与代码编辑区的 EditorToolbarPlacement.bottom 完全一致
        x = safeLeft + (availableWidth - childSize.width) / 2.0;
        y = max(screenTop, safeBottom - childSize.height - 4.0);
        break;

      case TerminalToolbarPlacement.smart:
        // 智能单行选区：优先上方，其次下方，最后顶端兜底
        x = anchor.dx - childSize.width / 2.0;
        final double yAbove = anchor.dy - lineHeight - childSize.height - 8.0;
        final double yBelow = anchor.dy + handleClearance;
        if (yAbove >= screenTop) {
          y = yAbove;
        } else if (yBelow + childSize.height <= safeBottom) {
          y = yBelow;
        } else {
          y = screenTop;
        }
        break;
    }

    // 安全夹紧，确保绝不超出屏幕与受遮挡区域
    final double clampedX = (availableWidth >= childSize.width)
        ? x.clamp(safeLeft, safeRight - childSize.width)
        : safeLeft;
    final double clampedY = (safeBottom - screenTop >= childSize.height)
        ? y.clamp(screenTop, safeBottom - childSize.height)
        : screenTop;

    return Offset(clampedX, clampedY);
  }

  @override
  bool shouldRelayout(covariant _TerminalToolbarLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor ||
        placement != oldDelegate.placement ||
        terminalRect != oldDelegate.terminalRect ||
        lineHeight != oldDelegate.lineHeight ||
        mediaQuery != oldDelegate.mediaQuery;
  }
}

/// 终端高层级浮动上下文菜单（挂载于 Root Overlay，纯文字无图标，风格与代码编辑区完全一致）
class _TerminalContextMenuWidget extends StatelessWidget {
  final Offset anchor;
  final TerminalToolbarPlacement placement;
  final Rect? terminalRect;
  final double lineHeight;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onDismiss;

  const _TerminalContextMenuWidget({
    required this.anchor,
    required this.placement,
    required this.terminalRect,
    required this.lineHeight,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final copyLabel = l10n?.copy ?? 'Copy';
    final pasteLabel = l10n?.paste ?? 'Paste';
    final selectAllLabel = l10n?.selectAll ?? 'Select All';

    final toolbarContent = Material(
      elevation: 6.0,
      shadowColor: Colors.black45,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildItem(
              context,
              label: copyLabel,
              onTap: onCopy,
            ),
            _buildDivider(context),
            _buildItem(
              context,
              label: pasteLabel,
              onTap: onPaste,
            ),
            _buildDivider(context),
            _buildItem(
              context,
              label: selectAllLabel,
              onTap: onSelectAll,
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // 点击外部空白区域关闭菜单
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _TerminalToolbarLayoutDelegate(
            anchor: anchor,
            placement: placement,
            terminalRect: terminalRect,
            lineHeight: lineHeight,
            mediaQuery: MediaQuery.of(context),
          ),
          child: toolbarContent,
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 0.8,
      indent: 6,
      endIndent: 6,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
