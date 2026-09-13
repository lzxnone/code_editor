import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/virtual_keyboard_config.dart';

/// 虚拟小键盘单行内的单个按键卡片组件
class VirtualKeyboardKeyTile extends StatelessWidget {
  final int pageIndex;
  final int rowIndex;
  final int keyIndex;
  final KeyboardKeyItem keyItem;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VirtualKeyboardKeyTile({
    super.key,
    required this.pageIndex,
    required this.rowIndex,
    required this.keyIndex,
    required this.keyItem,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasIcon = keyItem.icon != null && keyItem.icon!.isNotEmpty;
    final iconData = hasIcon ? KeyboardIconHelper.getIcon(keyItem.icon) : null;

    return Card(
      key: ValueKey('page_${pageIndex}_row_${rowIndex}_key_$keyIndex'),
      margin: const EdgeInsets.only(bottom: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: iconData != null
              ? Icon(iconData, size: 20, color: theme.colorScheme.primary)
              : Text(
                  keyItem.label.isNotEmpty ? keyItem.label : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        title: Text(
          keyItem.label.isNotEmpty ? keyItem.label : l10n.keyboardNoLabel,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: l10n.keyboardEditKeyTooltip,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: l10n.keyboardDeleteKeyTooltip,
              onPressed: onDelete,
            ),
            ReorderableDragStartListener(
              index: keyIndex,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
