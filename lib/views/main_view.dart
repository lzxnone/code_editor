import 'dart:async';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/toolchain_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_tab_bar.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/views/run_task_edit_view.dart';
import 'package:code_editor/widgets/distro_selector_dialog.dart';
import 'package:code_editor/widgets/run_tasks_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  String? _lastProjectRoot;

  static ProjectProvider _getProjectProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  static RunProvider? _getRunProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? Provider.of<RunProvider>(context, listen: listen) : Provider.of<RunProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  static TerminalProvider? _getTerminalProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? Provider.of<TerminalProvider>(context, listen: listen) : Provider.of<TerminalProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _handleSave(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    if (tabProvider.currentFilePath == null || tabProvider.currentFilePath!.isEmpty) {
      return;
    }
    final saved = await tabProvider.saveCurrentFile();
    if (saved && context.mounted) {
      final l10n = AppLocalizations.of(context);
      DialogUtils.showSuccessToast(context, l10n?.saveSuccess ?? '保存成功');
    }
  }

  void _handleSaveAll(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    final saved = await tabProvider.saveAllFiles();
    if (saved && context.mounted) {
      final l10n = AppLocalizations.of(context);
      DialogUtils.showSuccessToast(context, l10n?.saveAllSuccess ?? '所有文件已保存');
    }
  }

  void _handleCloseAllTabs(BuildContext context) async {
    await _getTabProvider(context).closeAllTabs(context);
  }

  void _handleCloseProject(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    final projectProvider = _getProjectProvider(context);
    final canProceed = await tabProvider.checkUnsavedChanges(context);
    if (canProceed && context.mounted) {
      await projectProvider.closeProject();
      if (context.mounted) {
        _getRunProvider(context)?.onProjectClosed();
      }
    }
  }

  static DistroProvider? _getDistroProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? Provider.of<DistroProvider>(context, listen: listen) : Provider.of<DistroProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  /// 提示用户缺失 Linux 执行环境并引导前往系统管理进行配置
  void _showMissingDistroDialog(BuildContext context, String? targetDistro) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.missingDistroTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          targetDistro == null
              ? l10n.noDistroAvailableContent
              : l10n.distroNotInstalledContent(targetDistro),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              DistroSelectorDialog.show(context);
            },
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: Text(l10n.systemManagement),
          ),
        ],
      ),
    );
  }

  /// 执行某个具体的运行任务（前置校验环境、识别工具链并推入终端 PTY 执行）
  Future<void> _executeRunTask(BuildContext context, RunTask task) async {
    final projectProvider = _getProjectProvider(context);
    final terminalProvider = _getTerminalProvider(context);
    final runProvider = _getRunProvider(context);
    final distroProvider = _getDistroProvider(context);

    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.noOpenDirectory);
      return;
    }

    final distroManager = DistroManager();
    var targetDistro = distroProvider?.selectedSystem;

    // 1. 运行前环境可用性前置拦截校验与状态自动校准
    // 如果尚未选定系统，或者已选系统校验未通过，主动重新扫描物理系统列表进行校准
    if (targetDistro == null || !(await distroManager.isSystemInstalled(targetDistro))) {
      if (distroProvider != null) {
        await distroProvider.refreshSystems();
        targetDistro = distroProvider.selectedSystem;
      }
      // 如果 Provider 仍未选定，兜底从物理已安装列表中选取并同步
      if (targetDistro == null || !(await distroManager.isSystemInstalled(targetDistro))) {
        final physicalSystems = await distroManager.listInstalledSystems();
        if (physicalSystems.isNotEmpty) {
          targetDistro = physicalSystems.first;
          await distroProvider?.selectSystem(targetDistro);
        }
      }
    }

    final hasDistro = targetDistro != null && await distroManager.isSystemInstalled(targetDistro);
    if (!hasDistro) {
      if (!context.mounted) return;
      _showMissingDistroDialog(context, targetDistro);
      return;
    }

    // 2. 识别目标系统发行版家族并自适应合成工具链前置检测/安装命令
    final family = await distroManager.detectDistroFamily(targetDistro);
    final rootDir = await distroManager.getSystemRootDir(targetDistro);
    final effectiveCommand = ToolchainService.resolveCommand(
      task.command,
      family,
      rootDir: rootDir,
    );

    // 3. 查找或创建绑定了该工程工作路径与目标系统的终端会话
    final session = terminalProvider?.getOrCreateSessionForProject(
      projectRoot: rootPath,
      distroId: targetDistro,
    );

    // 4. 记录最近执行的任务
    runProvider?.setLastRunTask(task);

    // 5. 跳转至终端视图
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const TerminalView(),
      ),
    );

    // 6. 执行任务命令（推入底层 PTY 的 stdin 并等待进程就绪）
    if (session != null) {
      if (task.clearBeforeRun) {
        session.clear();
      }
      unawaited(session.executeCommand(effectiveCommand));
    }
  }

  /// 点击运行按钮 (Play)：有历史任务或单文件即直接执行，否则弹出任务列表
  void _handleRun(BuildContext context) {
    final projectProvider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.pleaseOpenProjectFirst);
      return;
    }

    final runProvider = _getRunProvider(context);
    if (runProvider == null) return;

    // 优先: 最近运行的任务（若已持久化并存在且确实属于当前打开的工程）
    if (runProvider.currentProjectRoot == rootPath && runProvider.lastRunTask != null) {
      _executeRunTask(context, runProvider.lastRunTask!);
      return;
    }

    // 若当前项目尚未初始化完成或没有上一次运行的任务，直接打开运行任务列表
    _handleOpenRunTasksDialog(context);
  }

  /// 打开运行任务选择弹窗
  void _handleOpenRunTasksDialog(BuildContext context) {
    final runProvider = _getRunProvider(context);
    if (runProvider == null) return;
    final projectProvider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.pleaseOpenProjectFirst);
      return;
    }

    // 如果 runProvider 尚未绑定当前项目，立即触发同步
    if (runProvider.currentProjectRoot != rootPath) {
      final tabProvider = _getTabProvider(context);
      runProvider.onProjectOpened(rootPath, activeFilePath: tabProvider.currentFilePath);
    }

    final isCurrentProject = runProvider.currentProjectRoot == rootPath;
    RunTasksDialog.show(
      context: context,
      customTasks: isCurrentProject ? runProvider.customTasks : const [],
      detectedTasks: isCurrentProject ? runProvider.detectedTasks : const [],
      lastRunTaskId: isCurrentProject ? (runProvider.lastRunTaskId ?? runProvider.lastRunTask?.id) : null,
      onTaskSelected: (task) => _executeRunTask(context, task),
      onEditCustomTasks: () => _handleOpenEditRunTasks(context),
    );
  }

  /// 打开运行任务编辑独立 View
  void _handleOpenEditRunTasks(BuildContext context) {
    final projectProvider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.pleaseOpenProjectFirst);
      return;
    }

    final runProvider = _getRunProvider(context);
    if (runProvider == null) return;

    RunTaskEditView.navigate(
      context: context,
      currentTasks: runProvider.customTasks,
      onSave: (updatedTasks) async {
        await runProvider.updateCustomTasks(updatedTasks);
        if (context.mounted) {
          DialogUtils.showSuccessToast(context, l10n.runTasksUpdated);
        }
      },
    );
  }

  /// 手动触发项目探测
  void _handleProjectDetect(BuildContext context) async {
    final projectProvider = _getProjectProvider(context);
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) return;

    final tabProvider = _getTabProvider(context);
    final runProvider = _getRunProvider(context);
    if (runProvider == null) return;

    await runProvider.detectTasks(
      projectRoot: rootPath,
      currentFilePath: tabProvider.currentFilePath,
    );

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      DialogUtils.showSuccessToast(
        context,
        l10n.detectCompletedMessage(runProvider.detectedTasks.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = _getProjectProvider(context, listen: true);
    final tabProvider = _getTabProvider(context, listen: true);
    final runProvider = _getRunProvider(context, listen: true);

    if (projectProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentFile = tabProvider.currentFilePath;
    final rootPath = projectProvider.rootPath;
    final isModified = tabProvider.isModified;

    // 当检测到切换了项目根目录时，自动触发初始化并进行一次探测
    if (rootPath != _lastProjectRoot) {
      _lastProjectRoot = rootPath;
      if (rootPath != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            runProvider?.onProjectOpened(rootPath, activeFilePath: currentFile);
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            runProvider?.onProjectClosed();
          }
        });
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canProceed = await _getTabProvider(context).checkUnsavedChanges(context);
        if (canProceed && context.mounted) {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          } else {
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: CodeEditorAppBar(
          filePath: currentFile,
          rootPath: rootPath,
          isModified: isModified,
          onSave: () => _handleSave(context),
          onSaveAll: () => _handleSaveAll(context),
          onCloseAllTabs: () => _handleCloseAllTabs(context),
          onCloseProject: () => _handleCloseProject(context),
          onRun: () => _handleRun(context),
          onRunTasks: () => _handleOpenRunTasksDialog(context),
          onProjectDetect: () => _handleProjectDetect(context),
          onEditRunTasks: () => _handleOpenEditRunTasks(context),
          isDetecting: runProvider?.isDetecting ?? false,
          onSettings: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SettingsView(),
              ),
            );
          },
        ),
        drawer: const CodeEditorDrawer(),
        body: Column(
          children: [
            const CodeEditorTabBar(),
            Expanded(
              child: CodeEditorWidget(
                filePath: currentFile,
                rootPath: rootPath,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
