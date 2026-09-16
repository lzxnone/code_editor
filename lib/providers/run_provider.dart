import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notice_item.dart';
import '../models/project_task_table.dart';
import '../models/run_task.dart';
import '../models/run_task_type.dart';
import '../services/distro_manager.dart';
import '../services/project_task_dispatcher.dart';
import '../services/project_modules/project_module.dart';
import '../services/project_modules/project_probe.dart';
import '../services/run_task_storage_service.dart';
import 'notice_center.dart';

/// 运行任务状态管理 Provider
///
/// 探测相关职责已收敛为"探测会话"模型：
/// * 每次探测创建一次 [ProjectProbe]，进度通过 [probeProgress] 暴露给 UI；
/// * 每个模块对应一条通知（[NoticeCenter]），并发模块 = 多条通知并存；
/// * 失败按 [ModuleProbeResult] 结构化上报，绝不返回硬编码兜底任务。
class RunProvider extends ChangeNotifier {
  final RunTaskStorageService _storageService;
  final ProjectTaskDispatcher _dispatcher;
  final DistroManager _distroManager;
  final NoticeCenter? _noticeCenter;

  RunProvider({
    RunTaskStorageService? storageService,
    ProjectTaskDispatcher? dispatcher,
    DistroManager? distroManager,
    NoticeCenter? noticeCenter,
    Duration? probeBudget,
  })  : _storageService = storageService ?? RunTaskStorageService(),
        _dispatcher = dispatcher ?? ProjectTaskDispatcher.instance,
        _distroManager = distroManager ?? DistroManager(),
        _noticeCenter = noticeCenter,
        _probeBudget = probeBudget ?? ProjectProbe.defaultBudget;

  /// 整轮探测的时间预算（超出后剩余模块跳过，并弹一条可关闭的提示）
  final Duration _probeBudget;

  /// 当前工程的系统任务内存表：**类型 → 任务数组**（哈希表）
  ///
  /// 进入项目时逐类型加载；模块探测完成即写入自己类型那一格（增量更新）。
  final ProjectTaskTable _taskTable = ProjectTaskTable();

  /// 最近一次运行的任务ID（持久化保存）
  String? _lastRunTaskId;

  /// 最近一次运行的任务（如果有）
  RunTask? _lastRunTask;

  /// 当前绑定的工程根路径
  String? _currentProjectRoot;

  /// 当前工程最近活跃打开的文件路径（用于维持当前文件任务）
  String? _lastActiveFilePath;

  /// 当前进行中的探测会话（null 表示空闲）
  ProjectProbe? _activeProbe;
  ProjectProbeReport? _lastProbeReport;
  final List<String> _activeProbeNoticeIds = [];

  /// 本轮已结算（成功/失败/跳过）的模块通知 id：
  /// 这些卡片内容已定稿，后续队列进度不得再覆盖它们
  /// （否则完成卡片会被回写为"排队等待中…"，失败原因也会被冲掉）
  final Set<String> _finishedProbeNoticeIds = {};

  /// 用户探测并发合并：正在执行的那次 + 是否需要补跑一次
  Future<void>? _userProbeInFlight;
  bool _userProbePending = false;

  /// 已释放标记：探测可能在释放后才返回，避免对已 dispose 的 notifier 通知
  bool _disposed = false;

  /// 安全通知（释放后不再触发）
  void _notify() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// 类型 → 任务数组（UI 按类型分段渲染）
  ProjectTaskTable get taskTable => _taskTable;

  List<RunTask> get detectedTasks => List.unmodifiable(_taskTable.detectedTasks);
  List<RunTask> get customTasks => _taskTable.tasksOf(RunTaskType.user);
  RunTask? get lastRunTask => _lastRunTask;
  String? get lastRunTaskId => _lastRunTaskId;
  String? get currentProjectRoot => _currentProjectRoot;

  /// 探测是否进行中（含模块依赖检测与自动补全）
  bool get isDetecting => _activeProbe != null;

  @visibleForTesting
  ProjectProbe? get activeProbeForTest => _activeProbe;

  /// 当前探测进度（null 表示无进行中的探测）
  ValueListenable<ProbeProgress?>? get probeProgress => _activeProbe?.progress;

  /// 最近一次探测的结构化报告
  ProjectProbeReport? get lastProbeReport => _lastProbeReport;

  /// 正在探测/同步的模块 id（供"重新同步"按钮显示 loading）
  Set<String> get syncingModules {
    final probe = _activeProbe;
    if (probe == null) return const <String>{};
    final only = probe.onlyModuleId;
    if (only != null) return {only};
    return {for (final m in probe.progress.value?.queue ?? const []) m.id};
  }

  bool isModuleSyncing(String moduleId) => syncingModules.contains(moduleId);

  /// 需要跑真实构建工具自省、因而支持"重新同步真实任务"的模块 id
  List<String> get resyncableModuleIds =>
      [for (final m in _dispatcher.modules) if (m.supportsResync) m.id];

  /// 模块展示名（用于 UI 文案插值；找不到时回退为 id）
  String moduleDisplayName(String moduleId) => _moduleDisplayName(moduleId);

  /// 获取当前合并后的所有可用任务列表（自定义任务置顶，随后为各类型探测任务）
  List<RunTask> get allTasks => [...customTasks, ..._taskTable.detectedTasks];

  /// 内部方法：尝试从现有任务列表中匹配 lastRunTaskId
  void _resolveLastRunTask() {
    _lastRunTask = null;
    if (_lastRunTaskId == null) return;
    for (final task in allTasks) {
      if (task.id == _lastRunTaskId) {
        _lastRunTask = task;
        return;
      }
    }
  }

  /// 记录最近一次执行的任务（"上一次执行任务"与用户任务一样持久化在 JSON 中）
  Future<void> setLastRunTask(RunTask task) async {
    _lastRunTask = task;
    _lastRunTaskId = task.id;
    _notify();

    final root = _currentProjectRoot;
    if (root != null) {
      // 只更新 lastRunTaskId，保留磁盘上已有的用户任务（内存可能尚未加载完）
      await _storageService.saveLastRunTaskId(
        projectRoot: root,
        lastRunTaskId: _lastRunTaskId,
      );
    }

    // 与用户任务同样的处理：写盘后用用户探测把内存态从磁盘校准一次（含并发合并）
    await probeUser(projectRoot: root);
  }

  /// 当打开或切换工程时初始化任务（进入项目即自动探测）
  ///
  /// [systemName] 必须传入当前真实选中的系统；为空时**只做用户探测**（系统探测会因无系统被跳过），
  /// 等系统就绪后由入口处的去重逻辑自动补一次。
  Future<void> onProjectOpened(String projectRoot, {String? activeFilePath, String? systemName}) async {
    _currentProjectRoot = projectRoot;
    _lastActiveFilePath = activeFilePath;
    await probeProject(
      projectRoot: projectRoot,
      currentFilePath: activeFilePath,
      systemName: systemName,
    );
  }

  /// 关闭工程时清理状态
  void onProjectClosed() {
    cancelActiveProbe();
    _currentProjectRoot = null;
    _lastActiveFilePath = null;
    _taskTable.clear();
    _lastRunTaskId = null;
    _lastRunTask = null;
    _lastProbeReport = null;
    _notify();
  }

  /// ===================== 探测层（三个函数） =====================

  /// 探测函数（总入口）：**终止正在运行的模块 + 清空内存任务表**，然后依次执行
  /// [probeUser]（用户探测：磁盘 → 内存）与 [probeSystem]（系统探测：模块队列 → 内存）。
  ///
  /// 进入项目、切换工程、手动"项目探测"都走它。
  Future<void> probeProject({
    required String projectRoot,
    String? currentFilePath,
    String? systemName,
  }) async {
    // 1. 终止进行中的模块（取消会话：容器内子进程会被立即杀掉）
    cancelActiveProbe();

    if (_currentProjectRoot != projectRoot) {
      _currentProjectRoot = projectRoot;
    }

    // 2. 清空内存任务表（系统任务只存在于内存，用户任务随后由用户探测重新载入）
    _taskTable.clear();
    _lastRunTask = null;
    _notify();

    // 3. 用户探测（快：读磁盘 → 覆盖内存 user 格与"上次执行任务"）
    await probeUser(projectRoot: projectRoot);

    // 4. 当前文件任务（快：本地重算，0ms 立即展现，不需等耗时的容器探测）
    final activeFile = currentFilePath ?? _lastActiveFilePath;
    if (activeFile != null && activeFile.isNotEmpty) {
      _applySingleFileTask(projectRoot, activeFile);
      _notify();
    }

    // 5. 系统探测（慢：模块队列线性执行 → 写入各自的类型格）
    await probeSystem(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
    );
  }

  /// 用户主动点击"项目探测"：若已有探测在进行则拒绝，由 UI 弹出 toast 提示。
  /// 返回 true 表示已开始探测。
  Future<bool> requestProjectProbe({
    required String projectRoot,
    String? currentFilePath,
    String? systemName,
  }) async {
    if (isDetecting) return false;
    await probeProject(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
    );
    return true;
  }

  /// 用户探测：从磁盘载入用户自定义任务与"上一次执行任务"，并**覆盖**内存中的用户类型格。
  ///
  /// 并发合并：短时间内被连续触发（例如用户连续编辑几十次任务）时，正在执行的那次结束后
  /// 最多再补跑一次，保证"最后一次编辑一定生效"，同时不会放大磁盘 IO。
  Future<void> probeUser({String? projectRoot}) async {
    final root = projectRoot ?? _currentProjectRoot;
    if (root == null) return;

    // 同步绑定工程根：这样"期间切换了工程"能被下面的守卫准确识别并丢弃结果
    _currentProjectRoot ??= root;

    final inFlight = _userProbeInFlight;
    if (inFlight != null) {
      _userProbePending = true;
      return inFlight;
    }

    final completer = Completer<void>();
    _userProbeInFlight = completer.future;
    try {
      await _loadUserState(root);
    } catch (e) {
      debugPrint('[RunProvider] 用户探测失败: $e');
    } finally {
      _userProbeInFlight = null;
      completer.complete();
      if (_userProbePending) {
        _userProbePending = false;
        unawaited(probeUser(projectRoot: root));
      }
    }
  }

  Future<void> _loadUserState(String projectRoot) async {
    final config = await _storageService.loadConfig(projectRoot);
    if (_currentProjectRoot != projectRoot) return;

    // 覆盖内存中的用户任务（而不是合并），并同步"上次执行任务"
    _taskTable.setUserTasks(config.tasks);
    _lastRunTaskId = config.lastRunTaskId;
    _resolveLastRunTask();
    _notify();
  }

  /// 系统探测：模块发现 → 入队 → 线性执行三动作，结果逐模块写入内存任务表。
  Future<void> probeSystem({
    required String projectRoot,
    String? currentFilePath,
    String? systemName,
    String? onlyModuleId,
  }) async {
    // 单模块同步时只清该模块类型；整轮探测时清空全部构建模块类型（用户任务格与当前文件格不动）
    if (onlyModuleId == null) {
      for (final type in RunTaskType.values) {
        if (type == RunTaskType.user || type == RunTaskType.singleFile) continue;
        _taskTable.replaceType(type, const <RunTask>[]);
      }
    } else {
      final type = RunTaskType.fromModuleId(onlyModuleId);
      if (type != null) _taskTable.replaceType(type, const <RunTask>[]);
    }
    _notify();

    // 终止可能仍在后台执行的旧探测会话，防止与新会话并发争抢包管理器锁与资源
    if (_activeProbe != null) {
      _activeProbe?.cancel();
      _activeProbe = null;
    }

    // 清理上一轮遗留的探测通知，避免新探测的进度更新到正在退场的卡片上
    _clearProbeNotices();

    final probe = _dispatcher.createProbe(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
      distroManager: _distroManager,
      onlyModuleId: onlyModuleId,
      budget: _probeBudget,
    );
    _activeProbe = probe;

    // 进度 -> 通知（队列中每个模块一条；当前模块显示三动作阶段，其余显示排队）
    void onProgress() {
      if (!identical(_activeProbe, probe)) return;
      final progress = probe.progress.value;
      if (progress == null || _noticeCenter == null) return;
      _syncProbeNotices(progress, probe);
      _notify();
    }

    probe.progress.addListener(onProgress);

    // 结果 -> 立即写入类型表 + 结算该模块弹窗（无需等整轮探测结束）
    void onModuleResult(ProjectModule module, ModuleProbeResult result) {
      // 边界：探测已被取消 / 已被新的探测取代 / 工程已切换时，结果必须丢弃，
      // 否则会把上一个工程（或已被取消的会话）的任务写进当前工程的内存表。
      if (!identical(_activeProbe, probe) || probe.isCancelled) return;
      if (_currentProjectRoot != projectRoot) return;
      _applyModuleResult(module, result);
      _notify();
    }

    ProjectProbeReport report;
    try {
      report = await _dispatcher.run(probe, onModuleResult: onModuleResult);
    } catch (e) {
      debugPrint('[RunProvider] 系统探测失败: $e');
      report = ProjectProbeReport.empty(systemName ?? '');
    } finally {
      probe.progress.removeListener(onProgress);
    }

    if (!identical(_activeProbe, probe)) {
      // 期间被取消或已被新的探测取代：会话由这里释放，结果一律丢弃
      probe.dispose();
      return;
    }
    _activeProbe = null;

    // 仅当"仍是同一个工程"且"本次是整轮探测"时才收尾（单模块同步不动当前文件格）
    if (_currentProjectRoot == projectRoot && !probe.isCancelled) {
      _lastProbeReport = report;
      if (onlyModuleId == null) {
        final activeFile = currentFilePath ?? _lastActiveFilePath;
        if (activeFile != null && activeFile.isNotEmpty) {
          _applySingleFileTask(projectRoot, activeFile);
        }
      }
      _resolveLastRunTask();
    }

    _finishProbeNotices(report, cancelled: probe.isCancelled);

    // 预算中止：补一条可关闭的说明（× 保留，用户可自行关闭或稍后重新探测）
    if (!probe.isCancelled && report.abortedByBudget && !_disposed) {
      _noticeCenter?.push(NoticeItem(
        id: 'probe:budget',
        kind: NoticeKind.failure,
        text: ProbeBudgetExceededText(
          completed: report.completedModules,
          total: report.totalModules,
        ),
        sticky: true,
      ));
    }

    probe.dispose();
    _notify();
  }

  /// 把"当前打开文件"的任务写入 singleFile（当前文件）类型格。
  ///
  /// 边界：本地重算而不是从报告里挑——即使工程没有任何模块被激活（报告为空），
  /// 当前文件任务也必须照常出现。
  void _applySingleFileTask(String projectRoot, String? currentFilePath) {
    if (_disposed) return;
    if (currentFilePath != null && currentFilePath.isNotEmpty) {
      _lastActiveFilePath = currentFilePath;
    }
    final effectivePath = currentFilePath ?? _lastActiveFilePath;
    final single = (effectivePath == null || effectivePath.isEmpty)
        ? null
        : ProjectTaskDispatcher.detectSingleFileTask(projectRoot, effectivePath);
    _taskTable.replaceType(
      RunTaskType.singleFile,
      single == null ? const <RunTask>[] : <RunTask>[single],
    );
  }

  /// 当前打开文件变化时本地重算当前文件任务（不跑容器、不触发系统探测）
  ///
  /// 边界：当前文件任务与"当前打开的文件"强相关，切标签页后必须立即更新，
  /// 否则列表里会残留上一个文件的运行项。
  void refreshSingleFileTask({String? currentFilePath}) {
    final root = _currentProjectRoot;
    if (root == null) return;
    if (currentFilePath != null && currentFilePath.isNotEmpty) {
      _lastActiveFilePath = currentFilePath;
    }
    _applySingleFileTask(root, currentFilePath ?? _lastActiveFilePath);
    _resolveLastRunTask();
    _notify();
  }

  /// 单模块强制重新同步（系统探测的一个特例）
  Future<void> syncModuleTasks(
    String moduleId, {
    String? systemName,
    String? currentFilePath,
  }) async {
    final projectRoot = _currentProjectRoot;
    if (projectRoot == null) return;
    if (isModuleSyncing(moduleId)) return;

    await probeSystem(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
      onlyModuleId: moduleId,
    );
  }

  /// 取消当前探测（切换工程 / 用户关闭提示 / 关闭弹窗时调用）
  void cancelActiveProbe() {
    final probe = _activeProbe;
    if (probe == null) return;
    probe.cancel();
    _clearProbeNotices();
    _activeProbe = null;
    _notify();
  }

  /// 单个模块探测结束：写入它自己类型的那一格 + 结算它的弹窗
  void _applyModuleResult(ProjectModule module, ModuleProbeResult result) {
    // 边界：运行时注册的自定义模块没有内置类型映射 -> 归入 other（不能丢任务）
    final type = RunTaskType.fromModuleId(module.id) ?? RunTaskType.other;
    _taskTable.replaceType(
      type,
      result.status == ModuleProbeStatus.ok ? result.tasks : const <RunTask>[],
    );
    if (_currentProjectRoot != null) {
      _resolveLastRunTask();
    }

    final center = _noticeCenter;
    if (center == null) return;
    final noticeId = _noticeIdFor(module.id);
    _finishedProbeNoticeIds.add(noticeId);
    switch (result.status) {
      case ModuleProbeStatus.ok:
        center.complete(
          noticeId,
          kind: NoticeKind.success,
          text: ModuleDoneText(module.displayName, taskCount: result.tasks.length),
          autoCloseAfter: const Duration(milliseconds: 1500),
          // 模块已结束：关闭这张卡片不再具有破坏性，无需再二次确认
          confirmBeforeDismiss: false,
        );
        break;
      case ModuleProbeStatus.failed:
        center.complete(
          noticeId,
          kind: NoticeKind.failure,
          text: ModuleFailureText(
            moduleDisplayName: module.displayName,
            failure: result.failure ?? NoticeFailure.executionFailed,
            detail: result.failureDetail,
          ),
          sticky: true,
          confirmBeforeDismiss: false,
        );
        break;
      case ModuleProbeStatus.cancelled:
      case ModuleProbeStatus.skippedByBudget:
        center.dismiss(noticeId);
        break;
    }
  }

  /// 依据队列进度为每个模块建立/更新通知条目
  ///
  /// 队列线性执行：当前模块显示它正在做的动作（依赖检测/自动补全/执行探测），
  /// 队列中其它模块统一显示"排队等待中"。
  void _syncProbeNotices(ProbeProgress progress, ProjectProbe probe) {
    final center = _noticeCenter;
    if (center == null) return;

    final currentPhase = switch (progress.phase) {
      ProbePhase.queued => ProbeNoticePhase.queued,
      ProbePhase.checkingDependency => ProbeNoticePhase.checkingDependency,
      ProbePhase.installingDependency => ProbeNoticePhase.installingDependency,
      ProbePhase.probing => ProbeNoticePhase.detecting,
      ProbePhase.finalizing => ProbeNoticePhase.finalizing,
    };
    final installDetail = probe.installLine.value;

    for (final module in progress.queue) {
      final noticeId = _noticeIdFor(module.id);
      // 已结算的模块不再改写：否则完成/失败卡片会被回写成"排队等待中…"
      if (_finishedProbeNoticeIds.contains(noticeId)) continue;

      final isCurrent = progress.current?.id == module.id;
      final phase = isCurrent ? currentPhase : ProbeNoticePhase.queued;
      final text = ModulePhaseText(
        moduleDisplayName: module.displayName,
        phase: phase,
        detail: isCurrent && phase == ProbeNoticePhase.installingDependency
            ? installDetail
            : null,
      );

      if (!_activeProbeNoticeIds.contains(noticeId)) {
        _activeProbeNoticeIds.add(noticeId);
        center.push(NoticeItem(
          id: noticeId,
          kind: NoticeKind.progress,
          text: text,
          // 进行中的通知被用户 × 掉 => 取消本次探测；这是破坏性操作，关闭前二次确认
          onUserDismiss: cancelActiveProbe,
          confirmBeforeDismiss: true,
        ));
      } else {
        center.update(noticeId, kind: NoticeKind.progress, text: text);
      }
    }
  }

  /// 整轮探测收尾：把仍未结算的进度条目关掉（结果已由 [_applyModuleResult] 逐模块结算）
  void _finishProbeNotices(ProjectProbeReport report, {required bool cancelled}) {
    final center = _noticeCenter;
    if (center == null) {
      _activeProbeNoticeIds.clear();
      _finishedProbeNoticeIds.clear();
      return;
    }

    if (cancelled) {
      _clearProbeNotices();
      return;
    }

    final resolved = {for (final id in report.moduleResults.keys) _noticeIdFor(id)};
    for (final noticeId in List<String>.from(_activeProbeNoticeIds)) {
      if (!resolved.contains(noticeId)) {
        center.dismiss(noticeId);
      }
    }
    _activeProbeNoticeIds
      ..clear()
      ..addAll(resolved);
    _finishedProbeNoticeIds.clear();
  }

  void _clearProbeNotices() {
    final center = _noticeCenter;
    if (center == null) {
      _activeProbeNoticeIds.clear();
      _finishedProbeNoticeIds.clear();
      return;
    }
    for (final noticeId in _activeProbeNoticeIds) {
      center.dismiss(noticeId);
    }
    _activeProbeNoticeIds.clear();
    _finishedProbeNoticeIds.clear();
  }

  String _noticeIdFor(String moduleId) => 'probe:$moduleId';

  String _moduleDisplayName(String moduleId) =>
      _dispatcher.getModule(moduleId)?.displayName ?? moduleId;

  /// 保存用户自定义任务：**先写盘，再调用用户探测**从磁盘覆盖内存中的用户任务格。
  ///
  /// 用户连续编辑时，[probeUser] 会把并发调用合并成"正在跑的那次 + 最多补跑一次"，
  /// 既保证最后一次编辑生效，又不会把磁盘 IO 放大几十倍。
  Future<void> updateCustomTasks(List<RunTask> updatedTasks) async {
    final root = _currentProjectRoot;
    if (root == null) return;

    await _storageService.saveConfig(
      projectRoot: root,
      tasks: updatedTasks,
      lastRunTaskId: _lastRunTaskId,
    );

    await probeUser(projectRoot: root);
  }

  /// 添加单个自定义任务（以**磁盘**为基准做读改写，避免内存未加载完时丢失已有任务）
  Future<void> addCustomTask(RunTask task) {
    return _mutateCustomTasks((list) => [...list, task]);
  }

  /// 删除单个自定义任务（以磁盘为基准）
  Future<void> removeCustomTask(String taskId) {
    return _mutateCustomTasks((list) => list.where((t) => t.id != taskId).toList());
  }

  /// 修改单个自定义任务（以磁盘为基准；磁盘上不存在则追加）
  Future<void> editCustomTask(RunTask task) {
    return _mutateCustomTasks((list) {
      final index = list.indexWhere((t) => t.id == task.id);
      if (index == -1) return [...list, task];
      final next = List<RunTask>.from(list);
      next[index] = task;
      return next;
    });
  }

  /// 读改写用户任务：先读磁盘上的当前列表，应用 [mutate] 后再写回，
  /// 最后用用户探测把内存态从磁盘覆盖一次（含并发合并）。
  Future<void> _mutateCustomTasks(List<RunTask> Function(List<RunTask> current) mutate) async {
    final root = _currentProjectRoot;
    if (root == null) return;

    final existing = (await _storageService.loadConfig(root)).tasks;
    await _storageService.saveConfig(
      projectRoot: root,
      tasks: mutate(existing),
      lastRunTaskId: _lastRunTaskId,
    );

    await probeUser(projectRoot: root);
  }

  @override
  void dispose() {
    // 只取消，不释放会话：探测协程仍在运行，会在自己的收尾分支里 dispose，
    // 这里提前 dispose 会造成"取消后写入已释放 notifier"的 use-after-dispose。
    _disposed = true;
    _activeProbe?.cancel();
    _activeProbe = null;
    _userProbePending = false;
    super.dispose();
  }
}
