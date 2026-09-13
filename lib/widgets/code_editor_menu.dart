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

/// 移动端选区悬浮工具栏（基于 OverlayEntry，绝不压入 Route，软键盘保持弹起）
class _MobileSelectionToolbarWidget extends StatefulWidget {
  final TextSelectionToolbarAnchors anchors;
  final CodeLineEditingController controller;
  final VoidCallback onDismiss;
  final FocusNode? focusNode;

  const _MobileSelectionToolbarWidget({
    required this.anchors,
    required this.controller,
    required this.onDismiss,
    this.focusNode,
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

    final mediaQuery = MediaQuery.of(context);
    final availableBottom = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    TextSelectionToolbarAnchors effectiveAnchors = widget.anchors;

    final primary = effectiveAnchors.primaryAnchor;
    final secondary = effectiveAnchors.secondaryAnchor;

    // 针对虚拟键盘或底栏的全局安全高度校准：
    if (secondary != null && secondary.dy + 65.0 > availableBottom) {
      effectiveAnchors = TextSelectionToolbarAnchors(
        primaryAnchor: Offset(
          secondary.dx.clamp(120.0, max(120.0, mediaQuery.size.width - 120.0)),
          (availableBottom - 12.0).clamp(mediaQuery.padding.top + 48.0, availableBottom),
        ),
        secondaryAnchor: null,
      );
    } else if (primary.dy + 60.0 > availableBottom && primary.dx >= 0) {
      effectiveAnchors = TextSelectionToolbarAnchors(
        primaryAnchor: Offset(
          primary.dx.clamp(120.0, max(120.0, mediaQuery.size.width - 120.0)),
          (availableBottom - 12.0).clamp(mediaQuery.padding.top + 48.0, availableBottom),
        ),
        secondaryAnchor: null,
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: effectiveAnchors,
      buttonItems: [
        if (hasSelection)
          ContextMenuButtonItem(
            label: l10n?.cut ?? '剪切',
            type: ContextMenuButtonType.cut,
            onPressed: () {
              widget.controller.cut();
              widget.onDismiss();
              widget.focusNode?.requestFocus();
            },
          ),
        if (hasSelection)
          ContextMenuButtonItem(
            label: l10n?.copy ?? '复制',
            type: ContextMenuButtonType.copy,
            onPressed: () {
              widget.controller.copy();
              widget.onDismiss();
              widget.focusNode?.requestFocus();
            },
          ),
        if (_canPaste)
          ContextMenuButtonItem(
            label: l10n?.paste ?? '粘贴',
            type: ContextMenuButtonType.paste,
            onPressed: () {
              widget.controller.paste();
              widget.onDismiss();
              widget.focusNode?.requestFocus();
            },
          ),
        if (!widget.controller.isEmpty)
          ContextMenuButtonItem(
            label: l10n?.selectAll ?? '全选',
            type: ContextMenuButtonType.selectAll,
            onPressed: () {
              widget.controller.selectAll();
              widget.onDismiss();
              widget.focusNode?.requestFocus();
            },
          ),
      ],
    );
  }
}

/// 自定义代码编辑器选区与右键菜单控制器
class CodeEditorToolbarController implements SelectionToolbarController {
  final FocusNode? focusNode;
  late final SelectionToolbarController _mobileController;

  CodeEditorToolbarController({this.focusNode}) {
    _mobileController = MobileSelectionToolbarController(
      builder: ({
        required BuildContext context,
        required TextSelectionToolbarAnchors anchors,
        required CodeLineEditingController controller,
        required VoidCallback onDismiss,
        required VoidCallback onRefresh,
      }) {
        return _MobileSelectionToolbarWidget(
          anchors: anchors,
          controller: controller,
          onDismiss: onDismiss,
          focusNode: focusNode,
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
    if (renderRect == null) {
      _showDesktopMenu(
        context: context,
        controller: controller,
        anchors: anchors,
      );
    } else {
      final safeAnchors = _sanitizeMobileAnchors(anchors, renderRect);
      _mobileController.show(
        context: context,
        controller: controller,
        anchors: safeAnchors,
        renderRect: renderRect,
        layerLink: layerLink,
        visibility: visibility,
      );
    }
  }

  /// 智能校准移动端选区工具栏锚点：
  /// 1. 优先展示在选区上方（primaryAnchor），避免遮挡当前选中的代码内容及下方代码；
  /// 2. 当选区位于视口顶部（上方空间不足 54px 时），智能翻转至选区下方（secondaryAnchor）；
  /// 3. 当选区靠近视口底部或键盘时，保护次锚点不落入键盘/底栏区域，坚决保持在上方；
  /// 4. 水平坐标智能居中并进行安全边缘约束（左右各留出 120px 缓冲），防止菜单按钮溢出屏幕。
  static TextSelectionToolbarAnchors _sanitizeMobileAnchors(
    TextSelectionToolbarAnchors anchors,
    Rect renderRect,
  ) {
    final primary = anchors.primaryAnchor;
    final secondary = anchors.secondaryAnchor;

    // 确定水平基准坐标并进行安全边距夹取（左右两端预留充足空间以保证多个操作按钮完整可见）
    final double rawX = (primary.dx > 0) ? primary.dx : (secondary?.dx ?? renderRect.center.dx);
    final double safeX = (renderRect.width > 240.0)
        ? rawX.clamp(renderRect.left + 120.0, renderRect.right - 120.0)
        : renderRect.center.dx;

    // 计算选区上方与下方的垂直可用净空间
    final double topY = (primary.dy > 0) ? primary.dy : (secondary?.dy ?? renderRect.top + 60.0);
    final double bottomY = (secondary != null && secondary.dy > 0) ? secondary.dy : (topY + 30.0);

    final double spaceAbove = topY - renderRect.top;
    final double spaceBelow = renderRect.bottom - bottomY;

    // 规则 1：选区上方空间充足（>= 54.0px，足够容纳工具栏），置于选区上方！
    // 选区本身与下方的代码行将保持 100% 清晰可见，绝不遮挡。
    if (spaceAbove >= 54.0) {
      return TextSelectionToolbarAnchors(
        primaryAnchor: Offset(safeX, topY),
        secondaryAnchor: spaceBelow >= 64.0 ? Offset(safeX, bottomY) : null,
      );
    }

    // 规则 2：选区位于第一行/第二行（上方空间不足 54px），但下方空间充足（>= 64px）
    // 智能翻转至选区下方，保证不超出屏幕顶部也不遮挡第一行
    if (spaceBelow >= 64.0) {
      return TextSelectionToolbarAnchors(
        primaryAnchor: const Offset(-10000, -10000),
        secondaryAnchor: Offset(safeX, bottomY),
      );
    }

    // 规则 3：选区跨越很大或上下空间均受限时，安全悬浮于可视区域上边缘内侧
    return TextSelectionToolbarAnchors(
      primaryAnchor: Offset(
        safeX,
        (renderRect.top + 56.0).clamp(renderRect.top + 10.0, renderRect.bottom - 10.0),
      ),
      secondaryAnchor: null,
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
          text: l10n?.cut ?? '剪切',
          icon: Icons.content_cut,
          enabled: hasSelection,
          onTap: () {
            controller.cut();
          },
        ),
        _EditorContextMenuItem(
          text: l10n?.copy ?? '复制',
          icon: Icons.copy,
          enabled: hasSelection,
          onTap: () {
            controller.copy();
          },
        ),
        _EditorContextMenuItem(
          text: l10n?.paste ?? '粘贴',
          icon: Icons.paste,
          enabled: hasClipboard,
          onTap: () {
            controller.paste();
          },
        ),
        const PopupMenuDivider(height: 1),
        _EditorContextMenuItem(
          text: l10n?.selectAll ?? '全选',
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
