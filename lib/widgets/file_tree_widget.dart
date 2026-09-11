import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileTreeWidget extends StatelessWidget {
  const FileTreeWidget({super.key});

  static ProjectProvider _getProjectProvider(BuildContext context) {
    try {
      return context.watch<ProjectProvider>();
    } catch (_) {
      return context.watch<EditorProvider>().projectProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectProvider = _getProjectProvider(context);
    final rootPath = projectProvider.rootPath;
    final items = projectProvider.items;

    // 1. 如果用户还没有打开/选择任何根目录
    if (rootPath == null || rootPath.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "请点击上方按钮打开文件目录",
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

    return ListView.builder(
      key: const PageStorageKey('code_editor_file_tree_list'),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return FileItemWidget(
          fileItem: items[index],
        );
      },
    );
  }
}