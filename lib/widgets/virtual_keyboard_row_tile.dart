import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/virtual_keyboard_config.dart';
import 'virtual_keyboard_key_tile.dart';

/// 虚拟小键盘页面内的单个按键行（含 ExpansionTile 与行内按键列表）
class VirtualKeyboardRowTile extends StatelessWidget {
  final int pageIndex;
  final int rowIndex;
  final List<KeyboardKeyItem> rowKeys;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onAddKey;
  final VoidCallback onDeleteRow;
  final void Function(int oldIndex, int newIndex) onReorderKeys;
  final void Function(int keyIndex, KeyboardKeyItem key) onEditKey;
  final ValueChanged<int> onDeleteKey;

  const VirtualKeyboardRowTile({
    super.key,
    required this.pageIndex,
    required this.rowIndex,
    required this.rowKeys,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onAddKey,
    required this.onDeleteRow,
    required this.onReorderKeys,
    required this.onEditKey,
    required this.onDeleteKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      key: ValueKey('page_${pageIndex}_row_$rowIndex'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('page_${pageIndex}_row_${rowIndex}_$isExpanded'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              '${rowIndex + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          title: Text(l10n.keyboardRowKeyCount(rowKeys.length)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: l10n.keyboardAddKeyTooltip,
                color: theme.colorScheme.primary,
                onPressed: onAddKey,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: l10n.keyboardDeleteRowTooltip,
                onPressed: onDeleteRow,
              ),
              ReorderableDragStartListener(
                index: rowIndex,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle, color: Colors.grey),
                ),
              ),
            ],
          ),
          children: [
            if (rowKeys.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n.keyboardEmptyRowKeysHint,
                    style: TextStyle(fontSize: 13, color: theme.hintColor),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: rowKeys.length,
                  onReorderItem: onReorderKeys,
                  itemBuilder: (context, keyIndex) {
                    final keyItem = rowKeys[keyIndex];
                    return VirtualKeyboardKeyTile(
                      key: ValueKey('page_${pageIndex}_row_${rowIndex}_key_$keyIndex'),
                      pageIndex: pageIndex,
                      rowIndex: rowIndex,
                      keyIndex: keyIndex,
                      keyItem: keyItem,
                      onEdit: () => onEditKey(keyIndex, keyItem),
                      onDelete: () => onDeleteKey(keyIndex),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
