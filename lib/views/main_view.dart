import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_tab_bar.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/views/run_task_edit_view.dart';
import 'package:code_editor/widgets/run_tasks_dialog.dart';
import 'package:flutter/material.dart';
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

  /// 执行某个具体的运行任务（复用/创建当前工程工作目录的终端并执行指令）
  void _executeRunTask(BuildContext context, RunTask task) {
    final projectProvider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.noOpenDirectory);
      return;
    }

    final terminalProvider = _getTerminalProvider(context);
    final runProvider = _getRunProvider(context);

    // 1. 查找或创建绑定了该工程工作路径的终端会话（保持系统默认会话名称）
    final session = terminalProvider?.getOrCreateSessionForProject(
      projectRoot: rootPath,
      distroId: 'alpine',
    );

    // 2. 记录最近执行的任务
    runProvider?.setLastRunTask(task);

    // 3. 跳转至终端视图
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const TerminalView(),
      ),
    );

    // 4. 等待界面跳转后向终端发送指令
    Future.delayed(const Duration(milliseconds: 300), () {
      if (session != null) {
        if (task.clearBeforeRun) {
          session.write('clear\r\n');
        }
        session.write('${task.command}\r\n');
      }
    });
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

    // 优先: 最近运行的任务（若已持久化并存在）
    if (runProvider.lastRunTask != null) {
      _executeRunTask(context, runProvider.lastRunTask!);
      return;
    }

    // 若没有上一次运行的任务，直接打开运行任务列表
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

    RunTasksDialog.show(
      context: context,
      customTasks: runProvider.customTasks,
      detectedTasks: runProvider.detectedTasks,
      lastRunTaskId: runProvider.lastRunTaskId ?? runProvider.lastRunTask?.id,
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
    if (rootPath != null && rootPath != _lastProjectRoot) {
      _lastProjectRoot = rootPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          runProvider?.onProjectOpened(rootPath, activeFilePath: currentFile);
        }
      });
    }

    return PopScope(
      canPop: !isModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canProceed = await _getTabProvider(context).checkUnsavedChanges(context);
        if (canProceed && context.mounted) {
          Navigator.of(context).pop();
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
