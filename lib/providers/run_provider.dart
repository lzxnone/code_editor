import 'package:flutter/material.dart';
import '../models/run_task.dart';
import '../services/project_task_detector.dart';
import '../services/run_task_storage_service.dart';

/// 运行任务状态管理 Provider
class RunProvider extends ChangeNotifier {
  final RunTaskStorageService _storageService;

  RunProvider({RunTaskStorageService? storageService})
      : _storageService = storageService ?? RunTaskStorageService();

  /// 内存中保存的系统动态探测任务列表（不落盘）
  List<RunTask> _detectedTasks = [];

  /// 用户持久化配置的自定义任务列表（存放在 .code_editor/run_tasks.json）
  List<RunTask> _customTasks = [];

  /// 最近一次运行的任务ID（持久化保存）
  String? _lastRunTaskId;

  /// 最近一次运行的任务（如果有）
  RunTask? _lastRunTask;

  /// 是否正在探测中（探测期间互斥，防止并发与按钮连点）
  bool _isDetecting = false;

  /// 当前绑定的工程根路径
  String? _currentProjectRoot;

  List<RunTask> get detectedTasks => List.unmodifiable(_detectedTasks);
  List<RunTask> get customTasks => List.unmodifiable(_customTasks);
  RunTask? get lastRunTask => _lastRunTask;
  String? get lastRunTaskId => _lastRunTaskId;
  bool get isDetecting => _isDetecting;
  String? get currentProjectRoot => _currentProjectRoot;

  /// 获取当前合并后的所有可用任务列表（自定义任务置顶，随后为探测任务）
  List<RunTask> get allTasks => [..._customTasks, ..._detectedTasks];

  /// 内部方法：尝试从现有任务列表中匹配 lastRunTaskId
  void _resolveLastRunTask() {
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
  Future<void> onProjectOpened(String projectRoot, {String? activeFilePath}) async {
    _currentProjectRoot = projectRoot;
    // 1. 加载持久化的自定义任务与最近运行任务ID
    final config = await _storageService.loadConfig(projectRoot);
    _customTasks = config.tasks;
    _lastRunTaskId = config.lastRunTaskId;
    _resolveLastRunTask();
    notifyListeners();

    // 2. 自动触发一次系统探测
    await detectTasks(projectRoot: projectRoot, currentFilePath: activeFilePath);
  }

  /// 关闭工程时清理状态
  void onProjectClosed() {
    _currentProjectRoot = null;
    _detectedTasks = [];
    _customTasks = [];
    _lastRunTaskId = null;
    _lastRunTask = null;
    _isDetecting = false;
    notifyListeners();
  }

  /// 手动或自动触发项目探测
  /// [projectRoot] 目标工程路径
  /// [currentFilePath] 当前激活的编辑器文件路径
  Future<void> detectTasks({
    required String projectRoot,
    String? currentFilePath,
  }) async {
    if (_isDetecting) return;

    _isDetecting = true;
    // 清空内存中的旧探测结果
    _detectedTasks = [];
    notifyListeners();

    try {
      final detected = await ProjectTaskDetector.detect(
        projectRoot: projectRoot,
        currentFilePath: currentFilePath,
      );
      _detectedTasks = detected;
      _resolveLastRunTask();
    } catch (e) {
      debugPrint('[RunProvider] 项目探测失败: $e');
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
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
