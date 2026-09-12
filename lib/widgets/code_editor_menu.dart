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
              Text(text, style: const TextStyle(fontSize: 13)),
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

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: widget.anchors,
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
