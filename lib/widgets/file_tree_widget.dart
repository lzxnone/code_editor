import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileTreeWidget extends StatelessWidget {
  final FileItem? rootFileItem;

  const FileTreeWidget({
    super.key,
    required this.rootFileItem
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final root = rootFileItem;
    if(root == null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "请点击上方按钮打开文件目录",
            style: TextStyle(
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      );
    }

    final children = root.children;
    if(children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "目录为空",
            style: TextStyle(
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return FileItemWidget(
          fileItem: children[index],
        );
      },
    );
  }
}