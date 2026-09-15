import 'package:flutter/material.dart';
import '../models/run_task.dart';
import '../services/distro_manager.dart';
import '../services/project_task_dispatcher.dart';
import '../services/run_task_storage_service.dart';

/// 运行任务状态管理 Provider
class RunProvider extends ChangeNotifier {
  final RunTaskStorageService _storageService;
  final ProjectTaskDispatcher _dispatcher;
  final DistroManager _distroManager;

  RunProvider({
    RunTaskStorageService? storageService,
    ProjectTaskDispatcher? dispatcher,
    DistroManager? distroManager,
  })  : _storageService = storageService ?? RunTaskStorageService(),
        _dispatcher = dispatcher ?? ProjectTaskDispatcher.instance,
        _distroManager = distroManager ?? DistroManager();

  /// 内存中保存的系统动态探测任务列表（不落盘）
  List<RunTask> _detectedTasks = [];

  /// 用户持久化配置的自定义任务列表（存放在 .code_editor/run_tasks.json）
  List<RunTask> _customTasks = [];

  /// 最近一次运行的任务ID（持久化保存）
  String? _lastRunTaskId;

  /// 最近一次运行的任务（如果有）
  RunTask? _lastRunTask;

  /// 是否正在总体探测中（探测期间互斥，防止并发与按钮连点）
  bool _isDetecting = false;

  /// 当前绑定的工程根路径
  String? _currentProjectRoot;

  /// 正在后台执行深度同步自省的模块集合（如 'gradle'）
  final Set<String> _syncingModules = {};

  List<RunTask> get detectedTasks => List.unmodifiable(_detectedTasks);
  List<RunTask> get customTasks => List.unmodifiable(_customTasks);
  RunTask? get lastRunTask => _lastRunTask;
  String? get lastRunTaskId => _lastRunTaskId;
  bool get isDetecting => _isDetecting;
  String? get currentProjectRoot => _currentProjectRoot;
  Set<String> get syncingModules => Set.unmodifiable(_syncingModules);

  bool isModuleSyncing(String moduleId) => _syncingModules.contains(moduleId);
  bool get isAnyModuleSyncing => _syncingModules.isNotEmpty;

  /// 获取当前合并后的所有可用任务列表（自定义任务置顶，随后为探测任务）
  List<RunTask> get allTasks => [..._customTasks, ..._detectedTasks];

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

  /// 记录最近一次执行的任务并持久化
  Future<void> setLastRunTask(RunTask task) async {
    _lastRunTask = task;
    _lastRunTaskId = task.id;
    notifyListeners();

    if (_currentProjectRoot != null) {
      await _storageService.saveConfig(
        projectRoot: _currentProjectRoot!,
        tasks: _customTasks,
        lastRunTaskId: _lastRunTaskId,
      );
    }
  }

  /// 当打开或切换工程时初始化任务（读取持久化任务 + 首次自动探测系统任务）
  Future<void> onProjectOpened(String projectRoot, {String? activeFilePath, String systemName = 'ubuntu'}) async {
    _currentProjectRoot = projectRoot;
    // 切换工程时首先立即清空上一工程的内存任务状态，防止跨项目污染
    _detectedTasks = [];
    _customTasks = [];
    _lastRunTaskId = null;
    _lastRunTask = null;
    _syncingModules.clear();
    notifyListeners();

    // 1. 加载持久化的自定义任务与最近运行任务ID
    final config = await _storageService.loadConfig(projectRoot);
    if (_currentProjectRoot != projectRoot) return;

    _customTasks = config.tasks;
    _lastRunTaskId = config.lastRunTaskId;
    _resolveLastRunTask();
    notifyListeners();

    // 2. 自动触发一次系统探测（优先读模块本地持久化缓存，秒开无感）
    await detectTasks(
      projectRoot: projectRoot,
      currentFilePath: activeFilePath,
      systemName: systemName,
    );
  }

  /// 关闭工程时清理状态
  void onProjectClosed() {
    _currentProjectRoot = null;
    _detectedTasks = [];
    _customTasks = [];
    _lastRunTaskId = null;
    _lastRunTask = null;
    _isDetecting = false;
    _syncingModules.clear();
    notifyListeners();
  }

  /// 手动或自动触发项目探测
  /// [projectRoot] 目标工程路径
  /// [currentFilePath] 当前激活的编辑器文件路径
  /// [forceRefresh] 是否强制重新自省探测
  Future<void> detectTasks({
    required String projectRoot,
    String? currentFilePath,
    String systemName = 'ubuntu',
    bool forceRefresh = false,
  }) async {
    if (_isDetecting) return;

    _isDetecting = true;
    _detectedTasks = [];
    _resolveLastRunTask();
    notifyListeners();

    try {
      final detected = await _dispatcher.detect(
        projectRoot: projectRoot,
        currentFilePath: currentFilePath,
        systemName: systemName,
        storageService: _storageService,
        distroManager: _distroManager,
        forceRefresh: forceRefresh,
      );
      if (_currentProjectRoot == projectRoot) {
        _detectedTasks = detected;
        _resolveLastRunTask();
      }
    } catch (e) {
      debugPrint('[RunProvider] 项目探测失败: $e');
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  /// 异步重新同步/深度自省某个特定模块的任务（如 Gradle）
  /// 在后台静默运行，并无缝将结果合并入当前 detectedTasks
  Future<void> syncModuleTasks(
    String moduleId, {
    String systemName = 'ubuntu',
  }) async {
    if (_currentProjectRoot == null) return;
    if (_syncingModules.contains(moduleId)) return;

    final projectRoot = _currentProjectRoot!;
    _syncingModules.add(moduleId);
    notifyListeners();

    try {
      final moduleTasks = await _dispatcher.syncModule(
        moduleId: moduleId,
        projectRoot: projectRoot,
        systemName: systemName,
        storageService: _storageService,
        distroManager: _distroManager,
      );

      if (_currentProjectRoot == projectRoot && moduleTasks.isNotEmpty) {
        _detectedTasks = _mergeModuleTasks(_detectedTasks, moduleId, moduleTasks);
        _resolveLastRunTask();
      }
    } catch (e) {
      debugPrint('[RunProvider] 模块 $moduleId 深度自省失败: $e');
    } finally {
      _syncingModules.remove(moduleId);
      notifyListeners();
    }
  }

  /// 合并替换指定模块在 detectedTasks 中的条目，保持原有相对排布
  List<RunTask> _mergeModuleTasks(List<RunTask> current, String moduleId, List<RunTask> updated) {
    final result = <RunTask>[];
    bool inserted = false;

    for (final task in current) {
      final isThisModule = task.moduleId == moduleId ||
          task.id.startsWith('${moduleId}_') ||
          task.id.startsWith('detected_${moduleId}_');

      if (isThisModule) {
        if (!inserted) {
          result.addAll(updated);
          inserted = true;
        }
      } else {
        result.add(task);
      }
    }

    if (!inserted) {
      result.addAll(updated);
    }

    return result;
  }

  /// 保存并更新用户自定义任务
  Future<void> updateCustomTasks(List<RunTask> updatedTasks) async {
    if (_currentProjectRoot == null) return;

    _customTasks = List.from(updatedTasks);
    _resolveLastRunTask();
    notifyListeners();

    await _storageService.saveConfig(
      projectRoot: _currentProjectRoot!,
      tasks: _customTasks,
      lastRunTaskId: _lastRunTaskId,
    );
  }

  /// 添加单个自定义任务
  Future<void> addCustomTask(RunTask task) async {
    final list = List<RunTask>.from(_customTasks);
    list.add(task);
    await updateCustomTasks(list);
  }

  /// 删除单个自定义任务
  Future<void> removeCustomTask(String taskId) async {
    final list = _customTasks.where((t) => t.id != taskId).toList();
    await updateCustomTasks(list);
  }

  /// 修改单个自定义任务
  Future<void> editCustomTask(RunTask task) async {
    final index = _customTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final list = List<RunTask>.from(_customTasks);
      list[index] = task;
      await updateCustomTasks(list);
    }
  }
}
