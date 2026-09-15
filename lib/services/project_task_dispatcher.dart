import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/run_task.dart';
import 'distro_manager.dart';
import 'project_modules/gradle_project_module.dart';
import 'project_modules/project_module.dart';
import 'project_modules/standard_project_modules.dart';
import 'run_task_storage_service.dart';

/// 项目任务总调度与路由器（对标 VS Code Task Service）
/// 统一管理各项目模块注册、条件匹配激活、并发/缓存调度与单文件即时任务生成
class ProjectTaskDispatcher {
  static final ProjectTaskDispatcher instance = ProjectTaskDispatcher();

  final List<ProjectModule> _modules = [];

  ProjectTaskDispatcher({List<ProjectModule>? customModules}) {
    if (customModules != null) {
      _modules.addAll(customModules);
    } else {
      _registerDefaultModules();
    }
  }

  void _registerDefaultModules() {
    _modules.addAll([
      GradleProjectModule(),
      CMakeProjectModule(),
      CargoProjectModule(),
      NpmProjectModule(),
      MakeProjectModule(),
      DartProjectModule(),
    ]);
  }

  List<ProjectModule> get modules => List.unmodifiable(_modules);

  void registerModule(ProjectModule module) {
    _modules.removeWhere((m) => m.id == module.id);
    _modules.add(module);
  }

  ProjectModule? getModule(String id) {
    try {
      return _modules.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取当前项目中所有被激活的模块
  List<ProjectModule> getActiveModules(Directory projectDir) {
    return _modules.where((m) => m.shouldActivate(projectDir)).toList();
  }

  /// 核心任务探测与分发
  /// [projectRoot]: 工程根目录（宿主绝对路径）
  /// [currentFilePath]: 当前编辑器激活打开的文件（宿主绝对路径，可能为 null）
  /// [systemName]: 容器实例名称
  /// [forceRefresh]: 是否忽略缓存，强制重新请求真实探测
  /// [onlyModuleId]: 可选，仅执行指定的模块探测
  Future<List<RunTask>> detect({
    required String projectRoot,
    String? currentFilePath,
    String systemName = 'ubuntu',
    RunTaskStorageService? storageService,
    DistroManager? distroManager,
    bool forceRefresh = false,
    String? onlyModuleId,
  }) async {
    final List<RunTask> tasks = [];
    final projectDir = Directory(projectRoot);
    if (!projectDir.existsSync()) {
      return tasks;
    }

    final context = ProjectModuleContext(
      projectDir: projectDir,
      currentFilePath: currentFilePath,
      systemName: systemName,
      storageService: storageService ?? RunTaskStorageService(),
      distroManager: distroManager ?? DistroManager(),
    );

    // 1. 如果指定只探测某一模块
    if (onlyModuleId != null) {
      final module = getModule(onlyModuleId);
      if (module != null && module.shouldActivate(projectDir)) {
        try {
          final moduleTasks = await module.detect(context, forceRefresh: forceRefresh);
          tasks.addAll(moduleTasks);
        } catch (e, stack) {
          debugPrint('[ProjectTaskDispatcher] Module $onlyModuleId detect error: $e\n$stack');
        }
      }
      return tasks;
    }

    // 2. 并行调度所有命中的项目模块
    final activeModules = getActiveModules(projectDir);
    final results = await Future.wait(
      activeModules.map((m) async {
        try {
          return await m.detect(context, forceRefresh: forceRefresh);
        } catch (e, stack) {
          debugPrint('[ProjectTaskDispatcher] Module ${m.id} detect error: $e\n$stack');
          return <RunTask>[];
        }
      }),
    );

    for (final moduleTasks in results) {
      tasks.addAll(moduleTasks);
    }

    // 3. 当前活跃文件（单文件运行）检测并置顶
    if (currentFilePath != null && currentFilePath.isNotEmpty) {
      final singleTask = detectSingleFileTask(projectRoot, currentFilePath);
      if (singleTask != null) {
        tasks.insert(0, singleTask);
      }
    }

    return tasks;
  }

  /// 针对单个模块执行显式重新同步
  Future<List<RunTask>> syncModule({
    required String moduleId,
    required String projectRoot,
    String? currentFilePath,
    String systemName = 'ubuntu',
    RunTaskStorageService? storageService,
    DistroManager? distroManager,
  }) async {
    final module = getModule(moduleId);
    if (module == null) return [];

    final projectDir = Directory(projectRoot);
    if (!projectDir.existsSync()) return [];

    final context = ProjectModuleContext(
      projectDir: projectDir,
      currentFilePath: currentFilePath,
      systemName: systemName,
      storageService: storageService ?? RunTaskStorageService(),
      distroManager: distroManager ?? DistroManager(),
    );

    return module.detect(context, forceRefresh: true);
  }

  /// 探测单文件运行指令（基于当前打开的文件）
  static RunTask? detectSingleFileTask(String projectRoot, String currentFilePath) {
    final file = File(currentFilePath);
    if (!file.existsSync()) return null;

    final fileName = p.basename(currentFilePath);
    final ext = p.extension(currentFilePath).toLowerCase();

    // 转换相对容器的路径（在容器内 /workspace 下执行）
    String relPath = p.relative(currentFilePath, from: projectRoot).replaceAll(r'\', '/');
    if (!relPath.startsWith('./') && !relPath.startsWith('/')) {
      relPath = './$relPath';
    }

    switch (ext) {
      case '.py':
        return RunTask(
          id: 'detected_single_python',
          name: 'Python: $fileName',
          command: 'python3 "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Python script',
          group: 'single_file',
          icon: Icons.code,
        );
      case '.c':
        return RunTask(
          id: 'detected_single_c',
          name: 'GCC: $fileName',
          command: 'gcc "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current C source file',
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.cpp':
      case '.cc':
      case '.cxx':
        return RunTask(
          id: 'detected_single_cpp',
          name: 'G++: $fileName',
          command: 'g++ "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current C++ source file',
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.sh':
      case '.bash':
        return RunTask(
          id: 'detected_single_sh',
          name: 'Shell: $fileName',
          command: 'sh "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Shell script',
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.dart':
        return RunTask(
          id: 'detected_single_dart',
          name: 'Dart: $fileName',
          command: 'dart run "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Dart file',
          group: 'single_file',
          icon: Icons.code,
        );
      case '.go':
        return RunTask(
          id: 'detected_single_go',
          name: 'Go: $fileName',
          command: 'go run "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Go source file',
          group: 'single_file',
          icon: Icons.code,
        );
      case '.rs':
        return RunTask(
          id: 'detected_single_rust',
          name: 'Rust: $fileName',
          command: 'rustc "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current Rust source file',
          group: 'single_file',
          icon: Icons.code,
        );
      case '.js':
        return RunTask(
          id: 'detected_single_js',
          name: 'Node: $fileName',
          command: 'node "$relPath"',
          source: TaskSource.detected,
          description: 'Run current JavaScript script',
          group: 'single_file',
          icon: Icons.javascript,
        );
      default:
        return null;
    }
  }
}
