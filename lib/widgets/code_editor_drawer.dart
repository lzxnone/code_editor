import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/permission_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/widgets/project_history_widget.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class CodeEditorDrawer extends StatelessWidget {
  const CodeEditorDrawer({super.key});

  static ProjectProvider _getProjectProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    return listen
        ? context.watch<ProjectProvider>()
        : context.read<ProjectProvider>();
  }

  static TabProvider _getTabProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  Future<void> _handleNewFile(BuildContext context, String rootPath) async {
    final hasPermission = await PermissionService.instance
        .ensureStoragePermission(context: context);
    if (!hasPermission || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final name = await DialogUtils.showInputDialog(
      context,
      title: l10n?.newFile ?? '新建文件',
      hintText: l10n?.fileNameHint ?? '文件名 (例如: main.dart)',
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      try {
        await _getProjectProvider(context).createFile(rootPath, name.trim());
        if (context.mounted) {
          final newFilePath = p.join(rootPath, name.trim());
          await _getTabProvider(context).openFile(newFilePath);
        }
      } catch (e) {
        if (context.mounted) {
          DialogUtils.showErrorToast(
            context,
            l10n?.createFileFailed(e.toString()) ?? '创建文件失败: $e',
          );
        }
      }
    }
  }

  Future<void> _handleNewFolder(BuildContext context, String rootPath) async {
    final hasPermission = await PermissionService.instance
        .ensureStoragePermission(context: context);
    if (!hasPermission || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final name = await DialogUtils.showInputDialog(
      context,
      title: l10n?.newFolder ?? '新建文件夹',
      hintText: l10n?.folderNameHint ?? '文件夹名',
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      try {
        await _getProjectProvider(
          context,
        ).createDirectory(rootPath, name.trim());
      } catch (e) {
        if (context.mounted) {
          DialogUtils.showErrorToast(
            context,
            l10n?.createFolderFailed(e.toString()) ?? '创建文件夹失败: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final projectProvider = _getProjectProvider(context, listen: true);
    final rootPath = projectProvider.rootPath;
    final hasProject = rootPath != null && rootPath.trim().isNotEmpty;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.fileDirectory,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: l10n.refreshDirectory,
                          onPressed: () =>
                              _getProjectProvider(context).refreshTree(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: l10n.openFileDirectory,
                          onPressed: () async {
                            final hasPermission = await PermissionService
                                .instance
                                .ensureStoragePermission(context: context);
                            if (!hasPermission || !context.mounted) return;
                            final canProceed = await _getTabProvider(
                              context,
                            ).checkUnsavedChanges(context);
                            if (!canProceed || !context.mounted) return;
                            _getProjectProvider(context).openDirectory();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: l10n.viewProjectHistory,
                          onPressed: () {
                            ProjectHistoryWidget.show(
                              context,
                              onSelectHistory: (selectedHistory) async {
                                final canProceed = await _getTabProvider(
                                  context,
                                ).checkUnsavedChanges(context);
                                if (!canProceed || !context.mounted) return;
                                _getProjectProvider(
                                  context,
                                ).switchProject(selectedHistory);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rootPath ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (hasProject) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.note_add_outlined),
                            tooltip: l10n.newFile,
                            onPressed: () => _handleNewFile(context, rootPath),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            tooltip: l10n.newFolder,
                            onPressed: () =>
                                _handleNewFolder(context, rootPath),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: SafeArea(top: false, child: FileTreeWidget())),
        ],
      ),
    );
  }
}
