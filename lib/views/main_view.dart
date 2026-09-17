import 'dart:async';
import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/permission_service.dart';
import 'package:code_editor/services/toolchain_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_tab_bar.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/views/run_task_edit_view.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/widgets/distro_extract_dialog.dart';
import 'package:code_editor/widgets/notice_host.dart';
import 'package:code_editor/widgets/probe_cancel_guard.dart';
import 'package:code_editor/widgets/run_tasks_dialog.dart';
import 'package:code_editor/models/lsp_language_config.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/services/internal_engine_service.dart';
import 'package:code_editor/services/lsp/lsp_manager.dart';
import 'package:code_editor/services/lsp_config_service.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  /// 清除指定语言或全部语言的防打扰提示记录（卸载组件后恢复提示资格并重置当前文件检查）
  static void clearPromptedLanguage(String? languageId) {
    _MainViewState.clearPromptedLanguage(languageId);
  }

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  String? _lastProjectRoot;

  /// 最近一次已触发探测的 (工程, 系统) 组合，用于去重与"系统就绪后补探测"
  String? _lastProbeKey;

  static String? _globalLastActiveFile;
  static final Set<String> _promptedLspLanguages = {};

  /// 清除指定语言或全部语言的防打扰提示记录（卸载组件后恢复提示资格并重置当前文件检查）
  static void clearPromptedLanguage(String? languageId) {
    if (languageId == null) {
      _promptedLspLanguages.clear();
    } else {
      _promptedLspLanguages.remove(languageId);
    }
    _globalLastActiveFile = null;
  }

  @override
  void initState() {
    super.initState();
    LspConfigService.instance.addListener(_handleLspConfigChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        InternalEngineService.instance.ensureEngineReady(context);
        LspConfigService.instance.loadConfigs();
        DistroManager().detectAndApplyRuntime(
          context: context,
          settings: context.read<SettingsProvider>(),
          showToast: true,
        );
      }
    });
  }

  @override
  void dispose() {
    LspConfigService.instance.removeListener(_handleLspConfigChanged);
    super.dispose();
  }

  void _handleLspConfigChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLspForOpenTabs();
    });
  }

  Future<void> _syncLspForOpenTabs({String? preferredFilePath}) async {
    if (!mounted) return;
    final tabProvider = _getTabProvider(context);
    final projectProvider = _getProjectProvider(context);
    final workspaceRoot = projectProvider.rootPath;

    final openTabs = tabProvider.openTabs;
    final currentPath = preferredFilePath ?? tabProvider.currentFilePath;

    final filesToSync = <String, String>{};
    for (final tab in openTabs) {
      filesToSync[tab.path] = tab.content;
    }
    if (currentPath != null && !filesToSync.containsKey(currentPath)) {
      filesToSync[currentPath] = '';
    }

    for (final entry in filesToSync.entries) {
      final path = entry.key;
      final ext = p.extension(path);
      if (ext.isEmpty) continue;

      final config = LspConfigService.instance.findByExtension(ext);
      if (config == null || !config.enabled) continue;

      final isCmdInstalled = await InternalEngineService.instance.isCommandInstalled(config.serverCommand);
      if (!isCmdInstalled) continue;

      final existingSession = LspManager.instance.getExistingSession(path);
      if (existingSession == null || !existingSession.isInitialized) {
        String content = entry.value;
        if (content.isEmpty && File(path).existsSync()) {
          try {
            content = await FileService.instance.readFileContent(path);
          } catch (_) {}
        }
        await LspManager.instance.onFileOpened(
          path,
          content,
          workspaceRoot: workspaceRoot,
        );
      }
    }
  }

  void _checkLspForFile(String filePath) async {
    final ext = p.extension(filePath);
    if (ext.isEmpty) return;
    await LspConfigService.instance.loadConfigs();

    // 1. 先检查已安装配置中是否有匹配此后缀的组件
    final existing = LspConfigService.instance.findByExtension(ext);
    if (existing != null) return;

    final engineInstalled = await InternalEngineService.instance.isEngineInstalled();
    if (!engineInstalled) return;

    // 2. 未在已安装配置中，查找代码内置语言预设模版
    final builtin = LspLanguageConfig.findBuiltinByExtension(ext);
    if (builtin == null) return;

    final isInstalled = await InternalEngineService.instance.isCommandInstalled(builtin.serverCommand);
    if (isInstalled) {
      // 若底层环境意外已存在该命令（例如系统自带或此前安装过），直接补充入库
      await LspConfigService.instance.updateConfig(builtin);
      if (mounted) {
        await _syncLspForOpenTabs(preferredFilePath: filePath);
      }
      return;
    }

    if (mounted) {
      final alreadyPrompted = _promptedLspLanguages.contains(builtin.id);
      if (!alreadyPrompted) {
        _promptedLspLanguages.add(builtin.id);
        _promptInstallLspComponent(builtin, targetFilePath: filePath);
      }
    }
  }

  Future<void> _promptInstallLspComponent(LspLanguageConfig config, {String? targetFilePath}) async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || !mounted) return;

    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lspPackageMissingTitle(config.name)),
        content: Text(l10n.lspPackageMissingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.installNow),
          ),
        ],
      ),
    );

    if (install == true && mounted) {
      final success = await DialogUtils.showSyncLoadingDialog<bool>(
        context,
        message: l10n.installingComponent(config.package),
        task: () => InternalEngineService.instance.installPackage(config.package),
      );

      if (mounted) {
        if (success) {
          await LspConfigService.instance.updateConfig(config);
          if (mounted) {
            DialogUtils.showSuccessToast(context, l10n.installComponentSuccess(config.name));
            await _syncLspForOpenTabs(preferredFilePath: targetFilePath);
          }
        } else {
          DialogUtils.showErrorToast(
            context,
            l10n.installComponentFailed('apt exit non-zero'),
          );
        }
      }
    }
  }

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

  /// 提示用户缺失 Linux 执行环境并引导解压安装 Ubuntu
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              final distroProvider = _getDistroProvider(context);
              if (distroProvider != null) {
                await DistroExtractDialog.show(
                  context: context,
                  systemName: DistroRepository.defaultSystemName,
                  task: (onProgress, isCancelled) => distroProvider.importBuiltinUbuntu(
                    systemName: DistroRepository.defaultSystemName,
                    onProgress: onProgress,
                    isCancelled: isCancelled,
                  ),
                );
              }
            },
            icon: const Icon(Icons.system_update_alt, size: 18),
            label: Text(l10n.installNow),
          ),
        ],
      ),
    );
  }

  /// 解析并校准「当前真实可用」的容器系统名。
  /// 返回 null 表示没有任何可用系统（此时不应进行任何任务探测）。
  Future<String?> _resolveUsableDistro(BuildContext context) async {
    final distroProvider = _getDistroProvider(context);
    final distroManager = DistroManager();
    try {
      final isInstalled = await distroManager.isSystemInstalled(DistroRepository.defaultSystemName);
      if (isInstalled) {
        if (distroProvider != null && distroProvider.selectedSystem == null) {
          await distroProvider.refreshSystems();
        }
        return DistroRepository.defaultSystemName;
      }
      return null;
    } catch (e) {
      debugPrint('[MainView] 系统可用性解析失败: $e');
      return null;
    }
  }

  /// 执行某个具体的运行任务（前置校验环境、识别工具链并推入终端 PTY 执行）
  Future<void> _executeRunTask(BuildContext context, RunTask task) async {
    final projectProvider = _getProjectProvider(context);
    final terminalProvider = _getTerminalProvider(context);
    final runProvider = _getRunProvider(context);

    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.noOpenDirectory);
      return;
    }

    final distroManager = DistroManager();

    // 1. 运行前环境可用性前置拦截校验与状态自动校准
    final String? targetDistro = await _resolveUsableDistro(context);
    if (targetDistro == null) {
      if (!context.mounted) return;
      _showMissingDistroDialog(context, null);
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

    // 确保针对当前活动文件刷新单文件任务（支持当前文件单任务联动）
    final currentFilePath = _getTabProvider(context).currentFilePath;
    runProvider.refreshSingleFileTask(currentFilePath: currentFilePath);

    // 优先: 最近运行的任务（若已持久化并存在且确实属于当前打开的工程）
    if (runProvider.currentProjectRoot == rootPath && runProvider.lastRunTask != null) {
      _executeRunTask(context, runProvider.lastRunTask!);
      return;
    }

    // 若当前项目尚未初始化完成或没有上一次运行的任务，直接打开运行任务列表
    _handleOpenRunTasksDialog(context);
  }

  /// 打开运行任务选择弹窗
  Future<void> _handleOpenRunTasksDialog(BuildContext context) async {
    final runProvider = _getRunProvider(context);
    if (runProvider == null) return;
    final projectProvider = _getProjectProvider(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = projectProvider.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      DialogUtils.showErrorToast(context, l10n.pleaseOpenProjectFirst);
      return;
    }

    // 任务探测必须基于「真实可用的容器系统」；没有任何可用系统时不做任何探测，
    // 直接引导用户去系统管理安装环境（避免伪造出并不存在的任务）。
    final systemName = await _resolveUsableDistro(context);
    if (systemName == null) {
      if (!context.mounted) return;
      _showMissingDistroDialog(context, null);
      return;
    }
    if (!context.mounted) return;

    // 如果 runProvider 尚未绑定当前项目，立即触发同步
    if (runProvider.currentProjectRoot != rootPath) {
      final tabProvider = _getTabProvider(context);
      unawaited(runProvider.onProjectOpened(
        rootPath,
        activeFilePath: tabProvider.currentFilePath,
        systemName: systemName,
      ));
    }

    // 单文件任务与"当前打开的文件"强相关：打开列表前本地重算一次（不跑容器）
    runProvider.refreshSingleFileTask(
      currentFilePath: _getTabProvider(context).currentFilePath,
    );

    final isCurrentProject = runProvider.currentProjectRoot == rootPath;
    RunTasksDialog.show(
      context: context,
      customTasks: isCurrentProject ? runProvider.customTasks : const [],
      detectedTasks: isCurrentProject ? runProvider.detectedTasks : const [],
      lastRunTaskId: isCurrentProject ? (runProvider.lastRunTaskId ?? runProvider.lastRunTask?.id) : null,
      onTaskSelected: (task) => _executeRunTask(context, task),
      onEditCustomTasks: () => _handleOpenEditRunTasks(context),
      onSyncModule: (moduleId) => runProvider.syncModuleTasks(moduleId, systemName: systemName),
      isSyncingModule: (moduleId) => runProvider.isModuleSyncing(moduleId),
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

    // 没有可用系统则不探测，直接引导安装（探测必须跑在真实系统里）
    final systemName = await _resolveUsableDistro(context);
    if (systemName == null) {
      if (!context.mounted) return;
      _showMissingDistroDialog(context, null);
      return;
    }
    if (!context.mounted) return;

    // 正在进行探测时：toast 提示并忽略本次点击（不打断、不重复探测）
    final started = await runProvider.requestProjectProbe(
      projectRoot: rootPath,
      currentFilePath: tabProvider.currentFilePath,
      systemName: systemName,
    );

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!started) {
      DialogUtils.showErrorToast(context, l10n.probeAlreadyRunning);
      return;
    }

    DialogUtils.showSuccessToast(
      context,
      l10n.detectCompletedMessage(runProvider.allTasks.length),
    );
  }

  Future<void> _handleOpenTerminal(BuildContext context) async {
    final wentToSettings = await PermissionService.instance.promptBatteryOptimizationIfNeeded(context);
    if (wentToSettings) return;
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const TerminalView(),
        ),
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

    // 【进入项目 = 探测入口】打开 / 切换 / 历史恢复 都由 rootPath 变化体现，
    // 因此这里统一作为唯一触发点；同时把"当前真实系统"纳入去重键：
    // 冷启动时系统尚未就绪会先跳过，等 DistroProvider 就绪后自动补探测一次。
    final systemName = _getDistroProvider(context, listen: true)?.selectedSystem;
    final probeKey = (rootPath == null || systemName == null) ? null : '$rootPath|$systemName';

    if (currentFile != null && currentFile != _globalLastActiveFile) {
      _globalLastActiveFile = currentFile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkLspForFile(currentFile);
          runProvider?.refreshSingleFileTask(currentFilePath: currentFile);
        }
      });
    }

    if (rootPath == null) {
      if (_lastProjectRoot != null) {
        _lastProjectRoot = null;
        _lastProbeKey = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            runProvider?.onProjectClosed();
          }
        });
      }
    } else if (probeKey != null && probeKey != _lastProbeKey) {
      _lastProbeKey = probeKey;
      _lastProjectRoot = rootPath;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final l10n = AppLocalizations.of(this.context);
        await runProvider?.onProjectOpened(
          rootPath,
          activeFilePath: currentFile,
          systemName: systemName,
        );
        if (!mounted) return;
        if (l10n != null && runProvider != null) {
          DialogUtils.showSuccessToast(
            this.context,
            l10n.detectCompletedMessage(runProvider.allTasks.length),
          );
        }
      });
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
          onTerminal: () => _handleOpenTerminal(context),
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CodeEditorWidget(
                      filePath: currentFile,
                      rootPath: rootPath,
                    ),
                  ),
                  if (context.watch<NoticeCenter?>() case final NoticeCenter center)
                    Positioned.fill(
                      child: NoticeHost(
                        center: center,
                        confirmDismissBuilder: confirmCancelProbe,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
