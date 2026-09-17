import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/services/permission_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/project_management_view.dart';
import 'package:code_editor/widgets/project_history_widget.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:code_editor/widgets/search/search_panel_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum _OpenProjectSource {
  fromApp,
  fromExternal,
}

class CodeEditorDrawer extends StatefulWidget {
  /// 内存中常驻记录抽屉当前选中的 Tab 索引 (0: 文件, 1: 搜索, 2: Git)
  static int lastSelectedTabIndex = 0;

  const CodeEditorDrawer({super.key});

  @override
  State<CodeEditorDrawer> createState() => _CodeEditorDrawerState();
}

class _CodeEditorDrawerState extends State<CodeEditorDrawer> {
  int _selectedIndex = CodeEditorDrawer.lastSelectedTabIndex;

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

  Future<void> _handleImportFiles(BuildContext context, String rootPath) async {
    final hasPermission = await PermissionService.instance
        .ensureStoragePermission(context: context);
    if (!hasPermission || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return;

      final count = await _getProjectProvider(context).importFiles(
        rootPath,
        result.files,
      );
      if (context.mounted && count > 0) {
        DialogUtils.showSuccessToast(
          context,
          l10n?.importFilesSuccess(count) ?? '成功导入 $count 个文件',
        );
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorToast(
          context,
          l10n?.importFilesFailed(e.toString()) ?? '导入文件失败: $e',
        );
      }
    }
  }

  Widget _buildActivityBarItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedIndex == index;
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              CodeEditorDrawer.lastSelectedTabIndex = index;
            });
          }
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  width: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityBar(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: true,
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildActivityBarItem(
              context: context,
              index: 0,
              icon: Icons.folder_copy_outlined,
              label: l10n.drawerTabExplorer,
            ),
            const SizedBox(height: 4),
            _buildActivityBarItem(
              context: context,
              index: 1,
              icon: Icons.search,
              label: l10n.drawerTabSearch,
            ),
            const SizedBox(height: 4),
            _buildActivityBarItem(
              context: context,
              index: 2,
              icon: Icons.alt_route_rounded,
              label: l10n.drawerTabGit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorerPage(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    String? rootPath,
    bool hasProject,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
          ),
          child: SafeArea(
            bottom: false,
            left: false,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.fileDirectory,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh),
                        tooltip: l10n.refreshDirectory,
                        onPressed: () {
                          _getProjectProvider(context).refreshTree();
                          final runProvider = context.read<RunProvider?>();
                          final root = _getProjectProvider(context).rootPath;
                          if (root != null && root.isNotEmpty) {
                            runProvider?.onProjectOpened(
                              root,
                              systemName: context.read<DistroProvider?>()?.selectedSystem,
                            );
                          }
                        },
                      ),
                      PopupMenuButton<_OpenProjectSource>(
                        icon: const Icon(Icons.folder_open),
                        tooltip: l10n.openFileDirectory,
                        itemBuilder: (popupContext) => [
                          PopupMenuItem<_OpenProjectSource>(
                            value: _OpenProjectSource.fromApp,
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(l10n.openFromApp),
                              ],
                            ),
                          ),
                          PopupMenuItem<_OpenProjectSource>(
                            value: _OpenProjectSource.fromExternal,
                            child: Row(
                              children: [
                                const Icon(Icons.folder_open_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(l10n.openFromExternal),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (source) async {
                          switch (source) {
                            case _OpenProjectSource.fromApp:
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ProjectManagementView(),
                                ),
                              );
                              break;
                            case _OpenProjectSource.fromExternal:
                              final hasPermission = await PermissionService
                                  .instance
                                  .ensureStoragePermission(context: context);
                              if (!hasPermission || !context.mounted) return;
                              final canProceed = await _getTabProvider(
                                context,
                              ).checkUnsavedChanges(context);
                              if (!canProceed || !context.mounted) return;
                              _getProjectProvider(context).openDirectory();
                              break;
                          }
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
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
                          hasProject
                              ? (InternalProjectService.instance
                                      .isInternalProject(rootPath!)
                                  ? p.basename(rootPath)
                                  : rootPath)
                              : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasProject) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(3),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          iconSize: 18,
                          icon: const Icon(Icons.note_add_outlined),
                          tooltip: l10n.newFile,
                          onPressed: () => _handleNewFile(context, rootPath!),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(3),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          iconSize: 18,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          tooltip: l10n.newFolder,
                          onPressed: () =>
                              _handleNewFolder(context, rootPath!),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(3),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          iconSize: 18,
                          icon: const Icon(Icons.file_upload_outlined),
                          tooltip: l10n.importFromExternal,
                          onPressed: () =>
                              _handleImportFiles(context, rootPath!),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: SafeArea(top: false, left: false, child: FileTreeWidget())),
      ],
    );
  }



  Widget _buildGitPlaceholder(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
          ),
          child: SafeArea(
            bottom: false,
            left: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.drawerTabGit,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final projectProvider = _getProjectProvider(context, listen: true);
    final rootPath = projectProvider.rootPath;
    final hasProject = rootPath != null && rootPath.trim().isNotEmpty;

    return Drawer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActivityBar(context, l10n, theme),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildExplorerPage(context, l10n, theme, rootPath, hasProject),
                const SearchPanelWidget(),
                _buildGitPlaceholder(context, l10n, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
