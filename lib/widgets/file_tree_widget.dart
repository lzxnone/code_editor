import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileTreeWidget extends StatelessWidget {
  const FileTreeWidget({super.key});

  static ProjectProvider _getProjectProvider(BuildContext context) {
    return context.watch<ProjectProvider>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final projectProvider = _getProjectProvider(context);
    final rootPath = projectProvider.rootPath;
    final items = projectProvider.items;

    // 1. 如果用户还没有打开/选择任何根目录
    if (rootPath == null || rootPath.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            l10n?.openProjectPrompt ?? "请点击上方按钮打开项目",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 2. 如果已经选择了根目录，但该目录下没有任何文件或子目录
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "目录为空",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 3. 动态扁平化已展开的目录树，使所有深度的文件节点均能通过 ListView.builder 获得真正的行级虚拟化
    final flatItems = <FileItem>[];
    void flatten(List<FileItem> list) {
      for (final it in list) {
        flatItems.add(it);
        if (it.isDirectory && it.isOpen && it.children.isNotEmpty) {
          flatten(it.children);
        }
      }
    }
    flatten(items);

    return ListView.builder(
      key: const PageStorageKey('code_editor_file_tree_list'),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];
        return FileItemWidget(
          key: ValueKey(item.path),
          fileItem: item,
        );
      },
    );
  }
}