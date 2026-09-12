import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 独立的终端项目组件
class TerminalSessionItemWidget extends StatelessWidget {
  final TerminalSession session;
  final int index;
  final bool isSelected;

  const TerminalSessionItemWidget({
    super.key,
    required this.session,
    required this.index,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayIndex = index + 1; // 索引从 1 开始
    final titleText = '($displayIndex) ${session.name}';
    final isHost = session.distroId == 'host';
    final badgeLabel = isHost ? 'Host' : 'Alpine';

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      color: isSelected ? theme.colorScheme.primary : null,
    );

    final iconColor = isSelected ? theme.colorScheme.primary : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onLongPressStart: (details) {
            _showContextMenu(context, details.globalPosition, displayIndex);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            leading: Icon(
              Icons.terminal,
              size: 20,
              color: iconColor,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isHost
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      color: isHost
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            dense: true,
            onTap: () {
              final provider = context.read<TerminalProvider>();
              provider.selectSession(index);
              final scaffold = Scaffold.maybeOf(context);
              if (scaffold != null && scaffold.isEndDrawerOpen) {
                scaffold.closeEndDrawer();
              }
            },
          ),
        ),
      ),
    );
  }

  /// 长按弹出菜单（样式与文件树长按菜单完全对齐）
  void _showContextMenu(BuildContext context, Offset tapPosition, int displayIndex) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    final selectedAction = await showMenu<String>(
      context: context,
      position: position,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      items: [
        _buildMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          title: '重命名',
          color: onSurfaceColor,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          title: '删除',
          color: theme.colorScheme.error,
          isDestructive: true,
        ),
      ],
    );

    if (selectedAction != null && context.mounted) {
      _handleMenuAction(context, selectedAction, displayIndex);
    }
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required Color color,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, int displayIndex) async {
    final provider = context.read<TerminalProvider>();

    switch (action) {
      case 'rename':
        final newName = await DialogUtils.showInputDialog(
          context,
          title: '重命名',
          hintText: '新名称',
          initialValue: session.name,
        );
        if (newName != null && newName.trim().isNotEmpty && newName.trim() != session.name) {
          provider.renameSession(session.id, newName.trim());
        }
        break;

      case 'delete':
        final confirmed = await DialogUtils.showDestructiveConfirmDialog(
          context,
          title: '确认删除',
          message: '确定要删除终端 "($displayIndex) ${session.name}" 吗？',
        );
        if (confirmed && context.mounted) {
          provider.removeSession(session.id);
        }
        break;
    }
  }
}
