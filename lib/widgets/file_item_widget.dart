import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FileItemWidget extends StatefulWidget {
  final FileItem fileItem;

  const FileItemWidget({
    super.key,
    required this.fileItem,
  });

  @override
  State<FileItemWidget> createState() => _FileItemWidgetState();
}

class _FileItemWidgetState extends State<FileItemWidget> {
  @override
  Widget build(BuildContext context) {
    return _buildFileItem(context, widget.fileItem);
  }

  Widget _buildFileItem(BuildContext context, FileItem item) {
    final theme = Theme.of(context);
    final provider = context.watch<EditorProvider>();
    final indent = EdgeInsets.only(left: item.depth * 16.0 + 8.0, right: 8.0);

    // 判断该文件是否处于被剪切状态
    final isCut = provider.isItemCut(item.path);

    // 判断该文件是否为当前正在编辑/修改的文件
    final isSelected = !item.isDirectory && provider.isFileSelected(item.path);

    // 文字样式：剪切时变灰，选中时高亮，其余正常
    final itemTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      color: isCut
          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
          : isSelected
              ? theme.colorScheme.primary
              : null,
    );

    final iconColor = isCut
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : isSelected
            ? theme.colorScheme.primary
            : null;

    if (item.isDirectory) {
      return GestureDetector(
        onLongPressStart: (details) {
          _showContextMenu(item, details.globalPosition);
        },
        child: ExpansionTile(
          key: PageStorageKey(item.path),
          initiallyExpanded: item.isOpen,
          tilePadding: indent,
          leading: Icon(
            item.isOpen ? Icons.folder_open_outlined : Icons.folder_outlined,
            color: isCut ? iconColor : null,
            size: 20,
          ),
          title: Text(
            item.name,
            style: itemTextStyle,
          ),
          dense: true,
          onExpansionChanged: (bool expanded) {
            setState(() {
              item.isOpen = expanded;
            });
            context.read<EditorProvider>().toggleDirectory(item, expanded);
          },
          children: item.children
              .map((child) => FileItemWidget(fileItem: child))
              .toList(),
        ),
      );
    } else {
      return GestureDetector(
        onLongPressStart: (details) {
          _showContextMenu(item, details.globalPosition);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1.0),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListTile(
            contentPadding: indent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            selected: isSelected,
            selectedTileColor: Colors.transparent,
            leading: Icon(
              _getFileIcon(item),
              size: 20,
              color: iconColor,
            ),
            title: Text(
              item.name,
              style: itemTextStyle,
            ),
            dense: true,
            onTap: () {
              Navigator.of(context).maybePop(); // 关闭 Drawer
              context.read<EditorProvider>().selectFile(item);
            },
          ),
        ),
      );
    }
  }

  IconData _getFileIcon(FileItem item) {
    final lowerName = item.name.toLowerCase();
    if (lowerName == '.gitignore' || lowerName == '.gitattributes' || lowerName == '.gitmodules') {
      return Icons.commit_outlined;
    }

    switch (item.extension) {
      case '.dart':
        return Icons.flutter_dash;
      case '.html':
      case '.htm':
        return Icons.html;
      case '.css':
      case '.scss':
      case '.sass':
      case '.less':
        return Icons.css;
      case '.js':
      case '.mjs':
      case '.cjs':
        return Icons.javascript;
      case '.ts':
      case '.tsx':
      case '.jsx':
      case '.vue':
      case '.svelte':
        return Icons.code;
      case '.json':
        return Icons.data_object;
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.ini':
      case '.env':
      case '.conf':
      case '.config':
      case '.properties':
        return Icons.settings_suggest_outlined;
      case '.xml':
        return Icons.code;
      case '.md':
      case '.markdown':
        return Icons.article_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.py':
      case '.pyw':
      case '.java':
      case '.kt':
      case '.kts':
      case '.c':
      case '.cpp':
      case '.cc':
      case '.h':
      case '.hpp':
      case '.cs':
      case '.go':
      case '.rs':
      case '.swift':
      case '.rb':
      case '.php':
        return Icons.code;
      case '.sh':
      case '.bash':
      case '.zsh':
      case '.bat':
      case '.cmd':
      case '.ps1':
        return Icons.terminal;
      case '.sql':
      case '.db':
      case '.sqlite':
        return Icons.storage_outlined;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.webp':
      case '.svg':
      case '.ico':
      case '.bmp':
        return Icons.image_outlined;
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.flac':
      case '.aac':
        return Icons.audio_file_outlined;
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.mkv':
      case '.flv':
      case '.webm':
        return Icons.video_file_outlined;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icons.folder_zip_outlined;
      case '.lock':
        return Icons.lock_outline;
      case '.txt':
      default:
        return Icons.description_outlined;
    }
  }

  void _showContextMenu(FileItem item, Offset tapPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final canPaste = context.read<EditorProvider>().canPaste;
    final menuItems = <PopupMenuEntry<String>>[];

    if (item.isDirectory) {
      menuItems.addAll([
        _buildMenuItem('new_file', Icons.note_add_outlined, '新建文件', onSurfaceColor),
        _buildMenuItem('new_folder', Icons.create_new_folder_outlined, '新建文件夹', onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('cut', Icons.content_cut, '剪切', onSurfaceColor),
        _buildMenuItem('copy', Icons.copy, '复制', onSurfaceColor),
        PopupMenuItem<String>(
          value: 'paste',
          enabled: canPaste,
          child: Row(
            children: [
              Icon(
                Icons.paste,
                size: 18,
                color: canPaste
                    ? onSurfaceColor
                    : onSurfaceColor.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 8),
              Text(
                '粘贴',
                style: TextStyle(
                  color: canPaste
                      ? onSurfaceColor
                      : onSurfaceColor.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        _buildMenuItem('copy_path', Icons.link, '复制路径', onSurfaceColor),
        _buildMenuItem('copy_relative_path', Icons.short_text, '复制相对路径', onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('rename', Icons.edit_outlined, '重命名', onSurfaceColor),
        _buildMenuItem(
          'delete',
          Icons.delete_outline,
          '删除',
          theme.colorScheme.error,
          isDestructive: true,
        ),
      ]);
    } else {
      menuItems.addAll([
        _buildMenuItem('cut', Icons.content_cut, '剪切', onSurfaceColor),
        _buildMenuItem('copy', Icons.copy, '复制', onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('copy_path', Icons.link, '复制路径', onSurfaceColor),
        _buildMenuItem('copy_relative_path', Icons.short_text, '复制相对路径', onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('rename', Icons.edit_outlined, '重命名', onSurfaceColor),
        _buildMenuItem(
          'delete',
          Icons.delete_outline,
          '删除',
          theme.colorScheme.error,
          isDestructive: true,
        ),
      ]);
    }

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
      items: menuItems,
    );

    if (selectedAction != null && mounted) {
      _handleMenuAction(item, selectedAction);
    }
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String title,
    Color iconColor, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: isDestructive
                ? TextStyle(color: theme.colorScheme.error)
                : TextStyle(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(FileItem item, String action) async {
    final provider = context.read<EditorProvider>();
    switch (action) {
      case 'new_file':
        await _showCreateInputDialog(
          title: '新建文件',
          hintText: '文件名 (例如: main.dart)',
          onConfirm: (name) async {
            await provider.createFile(item.path, name);
          },
        );
        break;

      case 'new_folder':
        await _showCreateInputDialog(
          title: '新建文件夹',
          hintText: '文件夹名',
          onConfirm: (name) async {
            await provider.createDirectory(item.path, name);
          },
        );
        break;

      case 'cut':
        provider.cut(item);
        if (mounted) _showToast(context, '已剪切: ${item.name}');
        break;

      case 'copy':
        provider.copy(item);
        if (mounted) _showToast(context, '已复制: ${item.name}');
        break;

      case 'paste':
        try {
          await provider.paste(item);
          if (mounted) _showToast(context, '操作成功');
        } catch (e) {
          if (mounted) _showToast(context, '操作失败: $e', isError: true);
        }
        break;

      case 'copy_path':
        await Clipboard.setData(ClipboardData(text: item.fullPath));
        if (mounted) {
          _showToast(context, '已复制完整路径到剪贴板');
        }
        break;

      case 'copy_relative_path':
        await Clipboard.setData(ClipboardData(text: item.getRelativePath(provider.rootPath)));
        if (mounted) {
          _showToast(context, '已复制相对路径到剪贴板');
        }
        break;

      case 'rename':
        await _showCreateInputDialog(
          title: '重命名',
          hintText: '新名称',
          initialValue: item.name,
          onConfirm: (newName) async {
            if (newName.trim() == item.name) return;
            await provider.rename(item, newName.trim());
          },
        );
        break;

      case 'delete':
        final confirmed = await _showConfirmDialog(
          title: '确认删除',
          content: '确定要删除 "${item.name}" 吗？此操作不可恢复。',
        );
        if (confirmed == true && mounted) {
          await provider.delete(item);
        }
        break;
    }
  }

  void _showToast(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final theme = Theme.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 48,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isError
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.outlineVariant,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isError
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  Future<void> _showCreateInputDialog({
    required String title,
    required String hintText,
    String? initialValue,
    required Future<void> Function(String value) onConfirm,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return '名称不能为空';
                }
                if (val.contains(RegExp(r'[\\/:*?"<>|]'))) {
                  return '名称不能包含非法字符 (\\/:*?"<>|)';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final inputVal = controller.text;
                  Navigator.of(dialogContext).pop();
                  try {
                    await onConfirm(inputVal);
                  } catch (e) {
                    if (mounted) {
                      _showToast(context, '操作失败: $e', isError: true);
                    }
                  }
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}

