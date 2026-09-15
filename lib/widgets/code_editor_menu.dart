import 'dart:math';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

/// 桌面端代码编辑器的右键菜单项组件
class _EditorContextMenuItem extends PopupMenuItem<void> implements PreferredSizeWidget {
  _EditorContextMenuItem({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    super.enabled = true,
  }) : super(
          onTap: onTap,
          height: 36,
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );

  @override
  Size get preferredSize => const Size(140, 36);
}

/// 移动端选区悬浮工具栏布局代理：
/// 负责根据 EditorToolbarPlacement 与 safeEditorRect（精准剔除 AppBar/TabBar/虚拟小键盘/软键盘）精确定位
class _MobileToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final TextSelectionToolbarAnchors anchors;
  final Rect? renderRect;
  final MediaQueryData mediaQuery;

  _MobileToolbarLayoutDelegate({
    required this.anchors,
    required this.renderRect,
    required this.mediaQuery,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 1. 计算受保护的可视安全编辑区 safeEditorRect
    // 顶部：排除 AppBar, TabBar (renderRect.top) 以及系统状态栏
    final double safeTop = max(renderRect?.top ?? 0.0, mediaQuery.padding.top) + 6.0;
    // 底部：排除软键盘 (viewInsets.bottom)、虚拟小键盘 (renderRect.bottom) 以及底部安全区
    final double screenBottomWithoutKeyboard = mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.bottom;
    final double safeBottom = min(renderRect?.bottom ?? screenBottomWithoutKeyboard, screenBottomWithoutKeyboard) - 6.0;
    // 左右：留出安全内边距
    final double safeLeft = max(renderRect?.left ?? 0.0, mediaQuery.padding.left) + 8.0;
    final double safeRight = min(renderRect?.right ?? mediaQuery.size.width, mediaQuery.size.width - mediaQuery.padding.right) - 8.0;

    final double availableWidth = max(0.0, safeRight - safeLeft);
    final double availableHeight = max(0.0, safeBottom - safeTop);

    // 2. 根据 anchors 中的 EditorToolbarPlacement 或传统 anchors 计算位置
    EditorToolbarPlacement placement = EditorToolbarPlacement.aboveStart;
    Offset targetOffset = anchors.primaryAnchor;

    if (anchors is EditorSelectionToolbarAnchors) {
      final customAnchors = anchors as EditorSelectionToolbarAnchors;
      placement = customAnchors.placement;
      targetOffset = customAnchors.targetOffset;
    }

    double x;
    double y;

    switch (placement) {
      case EditorToolbarPlacement.center:
        // 框选文本完全占据当前屏幕：在中间显示
        x = safeLeft + (availableWidth - childSize.width) / 2.0;
        y = safeTop + (availableHeight - childSize.height) / 2.0;
        break;

      case EditorToolbarPlacement.top:
        // 选区整体在视口上方：在视口顶部贴边显示
        x = safeLeft + (availableWidth - childSize.width) / 2.0;
        y = safeTop + 4.0;
        break;

      case EditorToolbarPlacement.bottom:
        // 选区整体在视口下方：在视口底部贴边显示（紧贴软键盘/小键盘上方）
        x = safeLeft + (availableWidth - childSize.width) / 2.0;
        y = max(safeTop, safeBottom - childSize.height - 4.0);
        break;

      case EditorToolbarPlacement.aboveStart:
        // 在左端点上方弹出，若上方空间不足则翻转至下方
        x = targetOffset.dx - childSize.width / 2.0;
        final double yAbove = targetOffset.dy - childSize.height - 8.0;
        if (yAbove >= safeTop) {
          y = yAbove;
        } else {
          // 上方空间不足，翻转到左端点下方（行高约为 24）
          y = targetOffset.dy + 24.0 + 8.0;
        }
        break;

      case EditorToolbarPlacement.belowEnd:
        // 在右端点下方弹出，若下方空间不足则翻转至上方
        x = targetOffset.dx - childSize.width / 2.0;
        // 右端点手柄下挂高度约 28px，避免遮挡光标水滴手柄
        final double yBelow = targetOffset.dy + 24.0 + 26.0;
        if (yBelow + childSize.height <= safeBottom) {
          y = yBelow;
        } else {
          // 下方空间不足（被软键盘或小键盘限制），翻转到右端点上方
          y = targetOffset.dy - childSize.height - 8.0;
        }
        break;
    }

    // 3. 水平与垂直安全夹紧，防止任何溢出
    final double clampedX = (availableWidth >= childSize.width)
        ? x.clamp(safeLeft, safeRight - childSize.width)
        : safeLeft;
    final double clampedY = (availableHeight >= childSize.height)
        ? y.clamp(safeTop, safeBottom - childSize.height)
        : safeTop;

    return Offset(clampedX, clampedY);
  }

  @override
  bool shouldRelayout(covariant _MobileToolbarLayoutDelegate oldDelegate) {
    return anchors != oldDelegate.anchors ||
        renderRect != oldDelegate.renderRect ||
        mediaQuery != oldDelegate.mediaQuery;
  }
}

/// 移动端选区悬浮工具栏（基于 OverlayEntry，绝不压入 Route，软键盘保持弹起）
class _MobileSelectionToolbarWidget extends StatefulWidget {
  final TextSelectionToolbarAnchors anchors;
  final CodeLineEditingController controller;
  final VoidCallback onDismiss;
  final FocusNode? focusNode;
  final Rect? renderRect;

  const _MobileSelectionToolbarWidget({
    required this.anchors,
    required this.controller,
    required this.onDismiss,
    this.focusNode,
    this.renderRect,
  });

  @override
  State<_MobileSelectionToolbarWidget> createState() => _MobileSelectionToolbarWidgetState();
}

class _MobileSelectionToolbarWidgetState extends State<_MobileSelectionToolbarWidget> {
  bool _canPaste = true;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final hasStrings = await Clipboard.hasStrings();
      if (mounted && !hasStrings) {
        setState(() {
          _canPaste = false;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = widget.controller.selection.baseOffset != -1 &&
        widget.controller.selection.extentOffset != -1 &&
        !widget.controller.selection.isCollapsed;

    final cutLabel = l10n?.cut ?? 'Cut';
    final copyLabel = l10n?.copy ?? 'Copy';
    final pasteLabel = l10n?.paste ?? 'Paste';
    final selectAllLabel = l10n?.selectAll ?? 'Select All';

    final theme = Theme.of(context);

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
            if (hasSelection) ...[
              _buildItem(
                context,
                icon: Icons.content_cut,
                label: cutLabel,
                onTap: () {
                  widget.controller.cut();
                  widget.onDismiss();
                  widget.focusNode?.requestFocus();
                },
              ),
              _buildDivider(context),
              _buildItem(
                context,
                icon: Icons.copy,
                label: copyLabel,
                onTap: () {
                  widget.controller.copy();
                  widget.onDismiss();
                  widget.focusNode?.requestFocus();
                },
              ),
            ],
            if (_canPaste) ...[
              if (hasSelection) _buildDivider(context),
              _buildItem(
                context,
                icon: Icons.paste,
                label: pasteLabel,
                onTap: () {
                  widget.controller.paste();
                  widget.onDismiss();
                  widget.focusNode?.requestFocus();
                },
              ),
            ],
            if (!widget.controller.isEmpty) ...[
              _buildDivider(context),
              _buildItem(
                context,
                icon: Icons.select_all,
                label: selectAllLabel,
                onTap: () {
                  widget.controller.selectAll();
                  widget.onDismiss();
                  widget.focusNode?.requestFocus();
                },
              ),
            ],
          ],
        ),
      ),
    );

    return CustomSingleChildLayout(
      delegate: _MobileToolbarLayoutDelegate(
        anchors: widget.anchors,
        renderRect: widget.renderRect,
        mediaQuery: MediaQuery.of(context),
      ),
      child: toolbarContent,
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ],
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

/// 自定义代码编辑器选区与右键菜单控制器
class CodeEditorToolbarController implements SelectionToolbarController {
  final FocusNode? focusNode;
  late final SelectionToolbarController _mobileController;

  CodeLineEditingController? _lastController;
  TextSelectionToolbarAnchors? _lastAnchors;
  Rect? _lastRenderRect;
  LayerLink? _lastLayerLink;
  ValueNotifier<bool>? _lastVisibility;

  CodeEditorToolbarController({this.focusNode}) {
    _mobileController = MobileSelectionToolbarController(
      builder: ({
        required BuildContext context,
        required TextSelectionToolbarAnchors anchors,
        required CodeLineEditingController controller,
        required VoidCallback onDismiss,
        required VoidCallback onRefresh,
        Rect? renderRect,
      }) {
        return _MobileSelectionToolbarWidget(
          anchors: anchors,
          controller: controller,
          onDismiss: onDismiss,
          focusNode: focusNode,
          renderRect: renderRect,
        );
      },
    );
  }

  @override
  void hide(BuildContext context) {
    _mobileController.hide(context);
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _lastController = controller;
    _lastAnchors = anchors;
    _lastRenderRect = renderRect;
    _lastLayerLink = layerLink;
    _lastVisibility = visibility;

    if (renderRect == null) {
      _showDesktopMenu(
        context: context,
        controller: controller,
        anchors: anchors,
      );
    } else {
      _mobileController.show(
        context: context,
        controller: controller,
        anchors: anchors,
        renderRect: renderRect,
        layerLink: layerLink,
        visibility: visibility,
      );
    }
  }

  /// 重新唤起上一次的选区悬浮工具栏（常用于滚动结束时自动恢复）
  void reshowLastToolbar(BuildContext context) {
    final controller = _lastController;
    if (controller == null || controller.selection.isCollapsed || controller.selection.baseOffset == -1) {
      return;
    }
    if (_lastAnchors == null || _lastLayerLink == null || _lastVisibility == null) {
      return;
    }
    show(
      context: context,
      controller: controller,
      anchors: _lastAnchors!,
      renderRect: _lastRenderRect,
      layerLink: _lastLayerLink!,
      visibility: _lastVisibility!,
    );
  }

  Future<void> _showDesktopMenu({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
  }) async {
    final hasSelection = controller.selection.baseOffset != -1 &&
        controller.selection.extentOffset != -1 &&
        !controller.selection.isCollapsed;

    // 检查剪贴板是否有内容以决定是否启用粘贴
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final hasClipboard = clipboardData != null && (clipboardData.text?.isNotEmpty ?? false);

    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final anchor = anchors.primaryAnchor.dx > 0 && anchors.primaryAnchor.dy > 0
        ? anchors.primaryAnchor
        : (anchors.secondaryAnchor ?? Offset.zero);

    await showMenu<void>(
      context: context,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      position: RelativeRect.fromRect(
        anchor & const Size(140, 40),
        Offset.zero & mediaQuery.size,
      ),
      items: [
        _EditorContextMenuItem(
          text: l10n?.cut ?? 'Cut',
          icon: Icons.content_cut,
          enabled: hasSelection,
          onTap: () {
            controller.cut();
          },
        ),
        _EditorContextMenuItem(
          text: l10n?.copy ?? 'Copy',
          icon: Icons.copy,
          enabled: hasSelection,
          onTap: () {
            controller.copy();
          },
        ),
        _EditorContextMenuItem(
          text: l10n?.paste ?? 'Paste',
          icon: Icons.paste,
          enabled: hasClipboard,
          onTap: () {
            controller.paste();
          },
        ),
        const PopupMenuDivider(height: 1),
        _EditorContextMenuItem(
          text: l10n?.selectAll ?? 'Select All',
          icon: Icons.select_all,
          enabled: !controller.isEmpty,
          onTap: () {
            controller.selectAll();
          },
        ),
      ],
    );

    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }
}
