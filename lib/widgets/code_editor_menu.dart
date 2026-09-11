import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

/// 桌面端与移动端代码编辑器的浮动/右键菜单项组件
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

/// 自定义代码编辑器选区与右键菜单控制器
class CodeEditorToolbarController implements SelectionToolbarController {
  const CodeEditorToolbarController();

  @override
  void hide(BuildContext context) {
    // 菜单由 showMenu / 遮罩自动关闭，不需要额外动作
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
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
  }
}
