import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/virtual_keyboard_config.dart';

/// 虚拟小键盘页面管理抽屉
class VirtualKeyboardPageDrawer extends StatelessWidget {
  final List<KeyboardPageItem> pages;
  final int currentPageIndex;
  final VoidCallback onAddNewPage;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<int> onDeletePage;
  final void Function(int oldIndex, int newIndex) onReorderPages;

  const VirtualKeyboardPageDrawer({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onAddNewPage,
    required this.onSelectPage,
    required this.onDeletePage,
    required this.onReorderPages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 抽屉头部
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4.0, bottom: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.keyboardDrawerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 单独加号，后面文本为新建页面
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.keyboardNewPage),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      onAddNewPage();
                      Navigator.of(context).pop(); // 关闭抽屉
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 页面可拖动排序列表
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              itemCount: pages.length,
              onReorderItem: onReorderPages,
              itemBuilder: (context, index) {
                final isSelected = index == currentPageIndex;
                final pageItem = pages[index];

                return VirtualKeyboardPageDrawerItem(
                  key: ValueKey('page_$index'),
                  index: index,
                  pageItem: pageItem,
                  isSelected: isSelected,
                  canDelete: pages.length > 1,
                  onSelect: () {
                    onSelectPage(index);
                    Navigator.of(context).pop();
                  },
                  onDelete: () => onDeletePage(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽屉内的独立页面列表项组件
class VirtualKeyboardPageDrawerItem extends StatelessWidget {
  final int index;
  final KeyboardPageItem pageItem;
  final bool isSelected;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const VirtualKeyboardPageDrawerItem({
    super.key,
    required this.index,
    required this.pageItem,
    required this.isSelected,
    required this.canDelete,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          leading: Icon(
            Icons.dashboard_outlined,
            size: 20,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            l10n.keyboardPageItemTitle(index + 1),
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: Text(
            l10n.keyboardPageItemSubtitle(pageItem.keys.length),
            style: TextStyle(
              fontSize: 12.0,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          dense: true,
          onTap: onSelect,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: l10n.keyboardDeletePageTooltip,
                onPressed: canDelete ? onDelete : null,
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
