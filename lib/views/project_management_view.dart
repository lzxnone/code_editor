import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// 内部存储项目管理页面 (files/projects)
class ProjectManagementView extends StatefulWidget {
  const ProjectManagementView({super.key});

  @override
  State<ProjectManagementView> createState() => _ProjectManagementViewState();
}

class _ProjectManagementViewState extends State<ProjectManagementView> {
  final InternalProjectService _projectService = InternalProjectService.instance;
  List<Directory> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  static ProjectProvider _getProjectProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  Future<void> _loadProjects() async {
    final list = await _projectService.listProjects();
    if (mounted) {
      setState(() {
        _projects = list;
        _isLoading = false;
      });
    }
  }

  bool _isValidProjectArchive(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.xz') ||
        lower.endsWith('.txz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz') ||
        lower.endsWith('.tbz2') ||
        lower.endsWith('.tar');
  }

  Future<void> _onImportProject() async {
    final l10n = AppLocalizations.of(context)!;

    // 1. 打开手机系统文件管理选择一个压缩文件（限制为常用压缩格式）
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'tar', 'gz', 'tgz', 'xz', 'txz', 'bz2', 'tbz'],
    );

    if (result == null || result.files.isEmpty || !mounted) return;
    final filePath = result.files.single.path;
    if (filePath == null || filePath.trim().isEmpty || !mounted) return;

    // 校验文件格式是否属于受支持的压缩包格式
    if (!_isValidProjectArchive(filePath)) {
      if (mounted) {
        DialogUtils.showErrorToast(context, l10n.unsupportedProjectArchiveFormat);
      }
      return;
    }

    // 2. 提取压缩包默认项目名称（去除 .tar.gz, .tgz, .zip 等扩展名）
    String defaultName = p.basename(filePath);
    if (defaultName.endsWith('.tar.gz')) {
      defaultName = defaultName.substring(0, defaultName.length - 7);
    } else if (defaultName.endsWith('.tar.xz')) {
      defaultName = defaultName.substring(0, defaultName.length - 7);
    } else if (defaultName.endsWith('.tgz')) {
      defaultName = defaultName.substring(0, defaultName.length - 4);
    } else {
      defaultName = p.basenameWithoutExtension(filePath);
    }
    defaultName = defaultName.trim();

    // 3. 弹出一个 dialog，让用户确定项目名称
    final confirmedName = await DialogUtils.showInputDialog(
      context,
      title: l10n.confirmProjectNameTitle,
      hintText: l10n.projectNameHint,
      initialValue: defaultName,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return l10n.nameCannotBeEmpty;
        }
        if (val.contains(RegExp(r'[\\/:*?"<>|]'))) {
          return l10n.nameInvalidChars;
        }
        return null;
      },
    );

    if (confirmedName == null || confirmedName.trim().isEmpty || !mounted) {
      return;
    }

    final trimmedName = confirmedName.trim();
    if (await _projectService.projectExists(trimmedName)) {
      if (mounted) {
        DialogUtils.showErrorToast(context, l10n.projectAlreadyExists);
      }
      return;
    }

    // 4. 注意：确定项目名称之后才去进行解压复制操作
    if (!mounted) return;
    try {
      await DialogUtils.showSyncLoadingDialog(
        context,
        message: l10n.importingProject,
        task: () async {
          await _projectService.importProjectFromArchive(filePath, trimmedName);
        },
      );
      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.projectImported);
        await _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorToast(
          context,
          l10n.importProjectFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _onCreateProject() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await DialogUtils.showInputDialog(
      context,
      title: l10n.newProjectTitle,
      hintText: l10n.projectNameHint,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return l10n.nameCannotBeEmpty;
        }
        if (val.contains(RegExp(r'[\\/:*?"<>|]'))) {
          return l10n.nameInvalidChars;
        }
        return null;
      },
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final trimmedName = name.trim();
    if (await _projectService.projectExists(trimmedName)) {
      if (mounted) {
        DialogUtils.showErrorToast(context, l10n.projectAlreadyExists);
      }
      return;
    }

    try {
      await _projectService.createProject(trimmedName);
      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.projectCreated);
        await _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorToast(context, e.toString());
      }
    }
  }

  Future<void> _onRenameProject(Directory dir, String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final newName = await DialogUtils.showInputDialog(
      context,
      title: l10n.renameProject,
      hintText: l10n.projectNameHint,
      initialValue: currentName,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return l10n.nameCannotBeEmpty;
        }
        if (val.contains(RegExp(r'[\\/:*?"<>|]'))) {
          return l10n.nameInvalidChars;
        }
        return null;
      },
    );

    if (newName == null || newName.trim().isEmpty || newName.trim() == currentName || !mounted) {
      return;
    }

    final trimmedName = newName.trim();
    if (await _projectService.projectExists(trimmedName)) {
      if (mounted) {
        DialogUtils.showErrorToast(context, l10n.projectAlreadyExists);
      }
      return;
    }

    if (!mounted) return;
    final projectProvider = _getProjectProvider(context);
    try {
      final newDir = await _projectService.renameProject(dir, trimmedName);
      if (projectProvider.rootPath != null &&
          p.normalize(projectProvider.rootPath!) == p.normalize(dir.path)) {
        await projectProvider.openSpecificDirectory(newDir.path);
      }
      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.projectRenamed);
        await _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorToast(context, e.toString());
      }
    }
  }

  Future<void> _onExportProject(Directory dir, String projectName) async {
    final l10n = AppLocalizations.of(context)!;

    // 打开系统文件管理选择导出目标文件夹
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.selectExportDirectory,
    );

    if (selectedDir == null || selectedDir.trim().isEmpty || !mounted) {
      return;
    }

    final targetFileName = '$projectName.zip';
    final targetFilePath = p.join(selectedDir, targetFileName);
    final targetFile = File(targetFilePath);

    // 若目标文件已存在，弹出覆盖确认
    if (targetFile.existsSync()) {
      final confirmOverwrite = await DialogUtils.showDestructiveConfirmDialog(
        context,
        title: l10n.exportProject,
        message: l10n.targetFileAlreadyExists(targetFileName),
        confirmText: l10n.overwrite,
        cancelText: l10n.cancel,
      );
      if (!confirmOverwrite || !mounted) {
        return;
      }
    }

    // 执行流式压缩导出任务
    try {
      await DialogUtils.showSyncLoadingDialog(
        context,
        message: l10n.exportingProject,
        task: () async {
          await _projectService.exportProjectToZip(dir, targetFilePath);
        },
      );

      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.projectExported);
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorToast(
          context,
          l10n.exportProjectFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _onDeleteProject(Directory dir, String projectName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.deleteProject,
      message: l10n.deleteProjectConfirmMessage(projectName),
      confirmText: l10n.delete,
      cancelText: l10n.cancel,
    );

    if (!confirmed || !mounted) return;

    final projectProvider = _getProjectProvider(context);
    try {
      await _projectService.deleteProject(dir);
      if (projectProvider.rootPath != null &&
          p.normalize(projectProvider.rootPath!) == p.normalize(dir.path)) {
        await projectProvider.closeProject();
      }
      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.projectDeleted);
        await _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorToast(context, e.toString());
      }
    }
  }

  Future<void> _onOpenProject(Directory dir) async {
    final tabProvider = _getTabProvider(context);
    final projectProvider = _getProjectProvider(context);

    final canProceed = await tabProvider.checkUnsavedChanges(context);
    if (!canProceed || !mounted) return;

    await projectProvider.openSpecificDirectory(dir.path);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.projectsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: l10n.importFromExternal,
            onPressed: _onImportProject,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.newProject,
            onPressed: _onCreateProject,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noProjects,
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final dir = _projects[index];
                    final projectName = p.basename(dir.path);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      leading: Icon(
                        Icons.folder,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        projectName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: l10n.renameProject,
                            onPressed: () => _onRenameProject(dir, projectName),
                          ),
                          IconButton(
                            icon: const Icon(Icons.drive_folder_upload_outlined),
                            tooltip: l10n.exportProjectTooltip,
                            onPressed: () => _onExportProject(dir, projectName),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.deleteProject,
                            onPressed: () => _onDeleteProject(dir, projectName),
                          ),
                        ],
                      ),
                      onTap: () => _onOpenProject(dir),
                    );
                  },
                ),
    );
  }
}
