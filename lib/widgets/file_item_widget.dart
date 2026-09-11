import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
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
  static ProjectProvider _getProjectProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
    } catch (_) {
      final editor = listen ? context.watch<EditorProvider>() : context.read<EditorProvider>();
      return editor.projectProvider;
    }
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
    } catch (_) {
      final editor = listen ? context.watch<EditorProvider>() : context.read<EditorProvider>();
      return editor.tabProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildFileItem(context, widget.fileItem);
  }

  Widget _buildFileItem(BuildContext context, FileItem item) {
    final theme = Theme.of(context);
    final projectProvider = _getProjectProvider(context, listen: true);
    final tabProvider = _getTabProvider(context, listen: true);
    final indent = EdgeInsets.only(left: item.depth * 16.0 + 8.0, right: 8.0);

    // 判断该文件是否处于被剪切状态
    final isCut = projectProvider.isItemCut(item.path);

    // 判断该文件是否为当前正在编辑/修改的文件
    final isSelected = !item.isDirectory && tabProvider.isFileSelected(item.path);

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
            _getProjectProvider(context).toggleDirectory(item, expanded);
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
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: indent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                final scaffold = Scaffold.maybeOf(context);
                if (scaffold != null && scaffold.isDrawerOpen) {
                  scaffold.closeDrawer();
                }
                if (tabProvider.isFileSelected(item.path)) {
                  return;
                }
                _getTabProvider(context).selectFile(item);
              },
            ),
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

    return switch (item.extension) {
      '.dart' => Icons.flutter_dash,
      '.html' || '.htm' => Icons.html,
      '.css' || '.scss' || '.sass' || '.less' => Icons.css,
      '.js' || '.mjs' || '.cjs' => Icons.javascript,
      '.ts' || '.tsx' || '.jsx' || '.vue' || '.svelte' => Icons.code,
      '.json' => Icons.data_object,
      '.yaml' || '.yml' || '.toml' || '.ini' || '.env' || '.conf' || '.config' || '.properties' =>
        Icons.settings_suggest_outlined,
      '.xml' => Icons.code,
      '.md' || '.markdown' => Icons.article_outlined,
      '.pdf' => Icons.picture_as_pdf_outlined,
      '.py' || '.pyw' || '.java' || '.kt' || '.kts' || '.c' || '.cpp' || '.cc' ||
      '.h' || '.hpp' || '.cs' || '.go' || '.rs' || '.swift' || '.rb' || '.php' =>
        Icons.code,
      '.sh' || '.bash' || '.zsh' || '.bat' || '.cmd' || '.ps1' => Icons.terminal,
      '.sql' || '.db' || '.sqlite' => Icons.storage_outlined,
      '.png' || '.jpg' || '.jpeg' || '.gif' || '.webp' || '.svg' || '.ico' || '.bmp' =>
        Icons.image_outlined,
      '.mp3' || '.wav' || '.ogg' || '.flac' || '.aac' => Icons.audio_file_outlined,
      '.mp4' || '.avi' || '.mov' || '.mkv' || '.flv' || '.webm' => Icons.video_file_outlined,
      '.zip' || '.rar' || '.7z' || '.tar' || '.gz' => Icons.folder_zip_outlined,
      '.lock' => Icons.lock_outline,
      _ => Icons.description_outlined,
    };
  }

  void _showContextMenu(FileItem item, Offset tapPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final canPaste = _getProjectProvider(context).canPaste;
    final menuItems = <PopupMenuEntry<String>>[];

    final strNewFile = l10n?.newFile ?? '新建文件';
    final strNewFolder = l10n?.newFolder ?? '新建文件夹';
    final strCut = l10n?.cut ?? '剪切';
    final strCopy = l10n?.copy ?? '复制';
    final strPaste = l10n?.paste ?? '粘贴';
    final strCopyPath = l10n?.copyPath ?? '复制路径';
    final strCopyRelativePath = l10n?.copyRelativePath ?? '复制相对路径';
    final strRename = l10n?.rename ?? '重命名';
    final strDelete = l10n?.delete ?? '删除';

    if (item.isDirectory) {
      menuItems.addAll([
        _buildMenuItem('new_file', Icons.note_add_outlined, strNewFile, onSurfaceColor),
        _buildMenuItem('new_folder', Icons.create_new_folder_outlined, strNewFolder, onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('cut', Icons.content_cut, strCut, onSurfaceColor),
        _buildMenuItem('copy', Icons.copy, strCopy, onSurfaceColor),
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
                strPaste,
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
        _buildMenuItem('copy_path', Icons.link, strCopyPath, onSurfaceColor),
        _buildMenuItem('copy_relative_path', Icons.short_text, strCopyRelativePath, onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('rename', Icons.edit_outlined, strRename, onSurfaceColor),
        _buildMenuItem(
          'delete',
          Icons.delete_outline,
          strDelete,
          theme.colorScheme.error,
          isDestructive: true,
        ),
      ]);
    } else {
      menuItems.addAll([
        _buildMenuItem('cut', Icons.content_cut, strCut, onSurfaceColor),
        _buildMenuItem('copy', Icons.copy, strCopy, onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('copy_path', Icons.link, strCopyPath, onSurfaceColor),
        _buildMenuItem('copy_relative_path', Icons.short_text, strCopyRelativePath, onSurfaceColor),
        const PopupMenuDivider(),
        _buildMenuItem('rename', Icons.edit_outlined, strRename, onSurfaceColor),
        _buildMenuItem(
          'delete',
          Icons.delete_outline,
          strDelete,
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
    final provider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context);

    switch (action) {
      case 'new_file':
        final name = await DialogUtils.showInputDialog(
          context,
          title: l10n?.newFile ?? '新建文件',
          hintText: l10n?.fileNameHint ?? '文件名 (例如: main.dart)',
        );
        if (name != null && name.trim().isNotEmpty) {
          try {
            await provider.createFile(item.path, name.trim());
          } catch (e) {
            if (mounted) DialogUtils.showErrorToast(context, l10n?.createFileFailed(e.toString()) ?? '创建文件失败: $e');
          }
        }
        break;

      case 'new_folder':
        final name = await DialogUtils.showInputDialog(
          context,
          title: l10n?.newFolder ?? '新建文件夹',
          hintText: l10n?.folderNameHint ?? '文件夹名',
        );
        if (name != null && name.trim().isNotEmpty) {
          try {
            await provider.createDirectory(item.path, name.trim());
          } catch (e) {
            if (mounted) DialogUtils.showErrorToast(context, l10n?.createFolderFailed(e.toString()) ?? '创建文件夹失败: $e');
          }
        }
        break;

      case 'cut':
        provider.cut(item);
        if (mounted) DialogUtils.showInfoToast(context, l10n?.cutItem(item.name) ?? '已剪切: ${item.name}');
        break;

      case 'copy':
        provider.copy(item);
        if (mounted) DialogUtils.showInfoToast(context, l10n?.copiedItem(item.name) ?? '已复制: ${item.name}');
        break;

      case 'paste':
        try {
          await provider.paste(item);
          if (mounted) DialogUtils.showSuccessToast(context, l10n?.operationSuccess ?? '操作成功');
        } catch (e) {
          if (mounted) DialogUtils.showErrorToast(context, l10n?.operationFailed(e.toString()) ?? '操作失败: $e');
        }
        break;

      case 'copy_path':
        await Clipboard.setData(ClipboardData(text: item.fullPath));
        if (mounted) {
          DialogUtils.showSuccessToast(context, l10n?.copiedPathToClipboard ?? '已复制完整路径到剪贴板');
        }
        break;

      case 'copy_relative_path':
        await Clipboard.setData(ClipboardData(text: item.getRelativePath(provider.rootPath)));
        if (mounted) {
          DialogUtils.showSuccessToast(context, l10n?.copiedRelativePathToClipboard ?? '已复制相对路径到剪贴板');
        }
        break;

      case 'rename':
        final newName = await DialogUtils.showInputDialog(
          context,
          title: l10n?.rename ?? '重命名',
          hintText: l10n?.newName ?? '新名称',
          initialValue: item.name,
        );
        if (newName != null && newName.trim().isNotEmpty && newName.trim() != item.name) {
          try {
            await provider.rename(item, newName.trim());
          } catch (e) {
            if (mounted) DialogUtils.showErrorToast(context, l10n?.renameFailed(e.toString()) ?? '重命名失败: $e');
          }
        }
        break;

      case 'delete':
        final confirmed = await DialogUtils.showDestructiveConfirmDialog(
          context,
          title: l10n?.confirmDelete ?? '确认删除',
          message: l10n?.confirmDeleteMessage(item.name) ?? '确定要删除 "${item.name}" 吗？此操作不可恢复。',
        );
        if (confirmed && mounted) {
          try {
            await provider.delete(item);
          } catch (e) {
            if (mounted) DialogUtils.showErrorToast(context, l10n?.deleteFailed(e.toString()) ?? '删除失败: $e');
          }
        }
        break;
    }
  }
}
