import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileTreeWidget extends StatelessWidget {
  const FileTreeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rootPath = context.select<EditorProvider, String?>((p) => p.rootPath);
    final items = context.select<EditorProvider, List<FileItem>>((p) => p.items);

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