// ignore_for_file: implementation_imports
import 'dart:math';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/xterm.dart' as xterm;

enum _DraggingHandle { none, start, end }

/// 终端文字框选交互叠加层
/// 包含双端拖动手柄（Start/End Handle）与高层级浮动上下文操作菜单（复制、粘贴、全选）
class TerminalSelectionOverlay extends StatefulWidget {
  final xterm.Terminal terminal;
  final xterm.TerminalController controller;
  final GlobalKey<xterm.TerminalViewState> terminalViewKey;
  final FocusNode focusNode;
  final Widget child;

  const TerminalSelectionOverlay({
    super.key,
    required this.terminal,
    required this.controller,
    required this.terminalViewKey,
    required this.focusNode,
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(TerminalSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    _hideMenu();
    super.dispose();
  }

  RenderTerminal? get _renderTerminal {
    return widget.terminalViewKey.currentState?.renderTerminal;
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      _hideMenu();
      setState(() {});
      return;
    }

    // 若非正在拖动手柄或滑动，展示菜单
    if (_dragging == _DraggingHandle.none && !_isScrolling && !_isPointerSelecting) {
      _updateLastActiveAnchorDefault();
      _showMenu();
    }
    setState(() {});
  }

  void _updateLastActiveAnchorDefault() {
    final render = _renderTerminal;
    final selection = widget.controller.selection;
    if (render == null || selection == null || selection.isCollapsed) return;

    final range = selection.normalized;
    final endOffset = render.getOffset(range.end);
    final globalEnd = render.localToGlobal(
      endOffset + Offset(render.cellSize.width, render.cellSize.height),
    );
    _lastActiveAnchor = globalEnd;
  }

  void _hideMenu() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
  }

  void _showMenu([Offset? targetAnchor]) {
    _hideMenu();
    if (!mounted) return;

    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;

    final anchor = targetAnchor ?? _lastActiveAnchor;
    if (anchor == null) return;
    _lastActiveAnchor = anchor;

    final overlayState = Overlay.of(context, rootOverlay: true);

    _menuOverlayEntry = OverlayEntry(
      builder: (context) {
        return _TerminalContextMenuWidget(
          anchor: anchor,
          onCopy: _handleCopy,
          onPaste: _handlePaste,
          onSelectAll: _handleSelectAll,
          onDismiss: _hideMenu,
        );
      },
    );

    overlayState.insert(_menuOverlayEntry!);
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
        _updateLastActiveAnchorDefault();
        _showMenu();
      }
    });
  }

  // --- 手柄拖拽逻辑 ---

  void _onStartHandlePanStart(DragStartDetails details) {
    _dragging = _DraggingHandle.start;
    _hideMenu();
  }

  void _onStartHandlePanUpdate(DragUpdateDetails details) {
    final render = _renderTerminal;
    final selection = widget.controller.selection;
    if (render == null || selection == null) return;

    final range = selection.normalized;
    final localPos = render.globalToLocal(details.globalPosition);
    final adjusted = Offset(localPos.dx, localPos.dy - render.cellSize.height / 2);
    final cell = render.getCellOffset(adjusted);

    // 约束：起始手柄不能越过结束手柄
    if (cell.isBefore(range.end) || cell.isEqual(range.end)) {
      widget.controller.setSelection(
        widget.terminal.buffer.createAnchorFromOffset(cell),
        widget.terminal.buffer.createAnchorFromOffset(range.end),
      );
      final newLocal = render.getOffset(cell);
      _lastActiveAnchor = render.localToGlobal(newLocal + Offset(0, render.cellSize.height));
    }
  }

  void _onStartHandlePanEnd(DragEndDetails details) {
    _dragging = _DraggingHandle.none;
    if (mounted && widget.controller.selection != null && !widget.controller.selection!.isCollapsed) {
      _showMenu(_lastActiveAnchor);
    }
  }

  void _onEndHandlePanStart(DragStartDetails details) {
    _dragging = _DraggingHandle.end;
    _hideMenu();
  }

  void _onEndHandlePanUpdate(DragUpdateDetails details) {
    final render = _renderTerminal;
    final selection = widget.controller.selection;
    if (render == null || selection == null) return;

    final range = selection.normalized;
    final localPos = render.globalToLocal(details.globalPosition);
    final adjusted = Offset(localPos.dx, localPos.dy - render.cellSize.height / 2);
    final cell = render.getCellOffset(adjusted);

    // 约束：结束手柄不能移到起始手柄之前
    if (cell.isAfter(range.begin) || cell.isEqual(range.begin)) {
      widget.controller.setSelection(
        widget.terminal.buffer.createAnchorFromOffset(range.begin),
        widget.terminal.buffer.createAnchorFromOffset(cell),
      );
      final newLocal = render.getOffset(cell);
      _lastActiveAnchor = render.localToGlobal(
        newLocal + Offset(render.cellSize.width, render.cellSize.height),
      );
    }
  }

  void _onEndHandlePanEnd(DragEndDetails details) {
    _dragging = _DraggingHandle.none;
    if (mounted && widget.controller.selection != null && !widget.controller.selection!.isCollapsed) {
      _showMenu(_lastActiveAnchor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    final hasSelection = selection != null && !selection.isCollapsed;
    final render = _renderTerminal;

    Offset? startHandleLocal;
    Offset? endHandleLocal;

    if (hasSelection && render != null && render.hasSize) {
      final range = selection.normalized;
      final startCellOffset = render.getOffset(range.begin);
      final endCellOffset = render.getOffset(range.end);

      final viewportHeight = render.size.height;
      final viewportWidth = render.size.width;

      // 起始手柄锚点（字符底部左侧）
      final rawStartY = startCellOffset.dy + render.cellSize.height;
      final clampedStartY = rawStartY.clamp(0.0, viewportHeight - 10.0);
      final clampedStartX = startCellOffset.dx.clamp(0.0, viewportWidth - 20.0);
      startHandleLocal = Offset(clampedStartX, clampedStartY);

      // 结束手柄锚点（字符底部右侧）
      final rawEndY = endCellOffset.dy + render.cellSize.height;
      final clampedEndY = rawEndY.clamp(0.0, viewportHeight - 10.0);
      final clampedEndX = (endCellOffset.dx + render.cellSize.width).clamp(0.0, viewportWidth - 20.0);
      endHandleLocal = Offset(clampedEndX, clampedEndY);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isScrolling = true;
          _hideMenu();
        } else if (notification is ScrollUpdateNotification) {
          if (mounted) setState(() {});
        } else if (notification is ScrollEndNotification) {
          _isScrolling = false;
          if (hasSelection && mounted && _dragging == _DraggingHandle.none) {
            _showMenu(_lastActiveAnchor);
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
          if (widget.controller.selection != null && !widget.controller.selection!.isCollapsed) {
            _lastActiveAnchor = event.position;
            if (_dragging == _DraggingHandle.none && !_isScrolling) {
              _showMenu(_lastActiveAnchor);
            }
          }
          setState(() {});
        },
        child: Stack(
          children: [
            widget.child,
            if (hasSelection && startHandleLocal != null)
              Positioned(
                left: startHandleLocal.dx - 32.0,
                top: startHandleLocal.dy - 10.0,
                child: _TerminalSelectionHandle(
                  isStart: true,
                  lineHeight: render?.cellSize.height ?? 20.0,
                  onPanStart: _onStartHandlePanStart,
                  onPanUpdate: _onStartHandlePanUpdate,
                  onPanEnd: _onStartHandlePanEnd,
                ),
              ),
            if (hasSelection && endHandleLocal != null)
              Positioned(
                left: endHandleLocal.dx - 10.0,
                top: endHandleLocal.dy - 10.0,
                child: _TerminalSelectionHandle(
                  isStart: false,
                  lineHeight: render?.cellSize.height ?? 20.0,
                  onPanStart: _onEndHandlePanStart,
                  onPanUpdate: _onEndHandlePanUpdate,
                  onPanEnd: _onEndHandlePanEnd,
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

  const _TerminalSelectionHandle({
    required this.isStart,
    required this.lineHeight,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    final type = isStart ? TextSelectionHandleType.left : TextSelectionHandleType.right;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
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

/// 终端高层级浮动上下文菜单（挂载于 Root Overlay）
class _TerminalContextMenuWidget extends StatelessWidget {
  final Offset anchor;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onDismiss;

  const _TerminalContextMenuWidget({
    required this.anchor,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    const menuWidth = 210.0;
    const menuHeight = 44.0;

    // 水平居中并限制在屏幕内
    final screenWidth = mediaQuery.size.width;
    final double left = (anchor.dx - menuWidth / 2).clamp(12.0, max(12.0, screenWidth - menuWidth - 12.0));

    // 垂直计算：优先位于锚点上方，若贴近屏幕顶端则悬浮于锚点下方
    final topThreshold = mediaQuery.padding.top + 48.0;
    final double top;
    if (anchor.dy - menuHeight - 12.0 >= topThreshold) {
      top = anchor.dy - menuHeight - 12.0;
    } else {
      top = (anchor.dy + 14.0).clamp(topThreshold, mediaQuery.size.height - menuHeight - 12.0);
    }

    return Stack(
      children: [
        // 点击外部空白区域关闭菜单
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(10.0),
            color: theme.colorScheme.surfaceContainerHighest,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: menuHeight,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItemButton(
                    label: l10n.copy,
                    icon: Icons.copy_rounded,
                    onPressed: onCopy,
                  ),
                  _buildDivider(theme),
                  _MenuItemButton(
                    label: l10n.paste,
                    icon: Icons.paste_rounded,
                    onPressed: onPaste,
                  ),
                  _buildDivider(theme),
                  _MenuItemButton(
                    label: l10n.selectAll,
                    icon: Icons.select_all_rounded,
                    onPressed: onSelectAll,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      width: 1.0,
      height: 20.0,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

class _MenuItemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _MenuItemButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.0, color: theme.colorScheme.primary),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
