import 'package:code_editor/models/file_item.dart';
import 'package:flutter/material.dart';

class FileItemWidget extends StatefulWidget {
  final FileItem fileItem;

  const FileItemWidget({
    super.key, 
    required this.fileItem
  });

  @override
  State<FileItemWidget> createState() => _FileItemWidget();
}

class _FileItemWidget extends State<FileItemWidget> {
  @override
  Widget build(BuildContext context) {
    return _buildFileItem(context, widget.fileItem);
  }

  Widget _buildFileItem(BuildContext context, FileItem item) {
    final indent = EdgeInsets.only(left: item.depth * 16.0 + 8.0, right: 8.0);
    if(item.isDirectory) {
      if(item.isOpen) {
        return GestureDetector(
          onLongPressStart: (details) {
            _showContextMenu(context, item, details.globalPosition);
          },
          child: ExpansionTile(
            initiallyExpanded: item.isOpen,
            onExpansionChanged: (bool expanded) {
              item.isOpen = expanded;
            },
            tilePadding: indent,
            leading: const Icon(Icons.folder_outlined, color: Colors.amber, size: 20),
            title: Text(
              item.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            dense: true,
            children: item.children.map((child) => _buildFileItem(context, child)).toList()
          )
        );
      }else {
        return GestureDetector(
          onLongPressStart: (details) {
            _showContextMenu(context, item, details.globalPosition);
          },
          child: ListTile(
            contentPadding: indent,
            leading: Icon(Icons.file_copy),
            title: Text(
              item.name,
              style: const TextStyle(fontSize: 13),
            ),
            dense: true,
            onTap: () {
              _openFile(item);
            },
          )
        );
      }
    }else {
      return GestureDetector(
        onLongPressStart: (details) {
          _showContextMenu(context, item, details.globalPosition);
        },
        child: ListTile(
          contentPadding: indent,
          leading: Icon(Icons.file_copy),
          title: Text(
            item.name,
            style: const TextStyle(fontSize: 13),
          ),
          dense: true,
          onTap: () {
            _openFile(item);
          },
        )
      );
    }
  }

  //打开文件
  void _openFile(FileItem item) {

  }

  void _showContextMenu(BuildContext context, FileItem item, Offset tapPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    // 弹出 Material 原生菜单
    final selectedAction = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF252526),
      elevation: 8,
      items: const [
        PopupMenuItem(
          value: 'new_file',
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 18, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('新建文件'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('重命名'),
            ],
          ),
        ),
        PopupMenuDivider(), // 分割线
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
    // 用户点击了某一项后的处理逻辑
    if(selectedAction != null) {
      _handleMenuAction(context, selectedAction);
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
    }
  }
}

