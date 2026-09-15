import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';

/// 专门负责 Gradle 项目全自动深度自省与任务构建的模块
class GradleProjectModule extends ProjectModule {
  @override
  String get id => 'gradle';

  @override
  String get displayName => 'Gradle';

  @override
  List<String> get triggerFiles => const [
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    'gradlew',
  ];

  @override
  bool shouldActivate(Directory projectDir) {
    return triggerFiles.any((f) => File(p.join(projectDir.path, f)).existsSync());
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    final projectDir = context.projectDir;
    final currentHash = computeBuildScriptHash(projectDir);

    // 1. 优先读取持久化缓存
    if (!forceRefresh) {
      final cached = await context.storageService.loadModuleTasks(projectDir.path, id);
      if (cached.tasks.isNotEmpty && cached.hash == currentHash) {
        debugPrint('[GradleProjectModule] 命中 ${projectDir.path} 真实任务缓存 (共 ${cached.tasks.length} 项)');
        return cached.tasks;
      }
    }

    // 2. 发起真实容器静默探测
    final execCmd = File(p.join(projectDir.path, 'gradlew')).existsSync() ? 'sh ./gradlew' : 'gradle';
    try {
      debugPrint('[GradleProjectModule] 开始在容器后台执行真实 Gradle Task 自省...');
      final result = await context.runHeadless(
        '$execCmd tasks --all --console=plain -q',
        timeout: const Duration(seconds: 90),
      );

      if (result != null && result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final tasks = parseGradleTasksOutput(result.stdout.toString(), execCmd);
        if (tasks.isNotEmpty) {
          debugPrint('[GradleProjectModule] 成功解析到 ${tasks.length} 个真实 Gradle 任务，正在持久化写入缓存...');
          await context.storageService.saveModuleTasks(
            projectRoot: projectDir.path,
            moduleName: id,
            tasks: tasks,
            hash: currentHash,
          );
          return tasks;
        }
      } else {
        debugPrint('[GradleProjectModule] 静默自省退出码非0或无输出: exitCode=${result?.exitCode}, stderr=${result?.stderr}');
      }
    } catch (e) {
      debugPrint('[GradleProjectModule] 静默自省异常: $e');
    }

    // 3. 兜底保障：若未生成缓存且静默执行暂不可用（如离线或环境未准备好），回退至预置核心常用任务
    return fallbackDefaultTasks(projectDir, execCmd);
  }

  /// 计算构建脚本的综合指纹哈希（用于智能感知构建文件变更并使缓存失效）
  static String computeBuildScriptHash(Directory projectDir) {
    final buffer = StringBuffer();
    final candidateFiles = [
      'build.gradle',
      'build.gradle.kts',
      'settings.gradle',
      'settings.gradle.kts',
      'gradle.properties',
    ];

    for (final fileName in candidateFiles) {
      final file = File(p.join(projectDir.path, fileName));
      if (file.existsSync()) {
        try {
          final stat = file.statSync();
          buffer.write('$fileName:${stat.size}:${stat.modified.millisecondsSinceEpoch};');
        } catch (_) {}
      }
    }

    return buffer.toString();
  }

  /// 解析 `./gradlew tasks --all --console=plain -q` 的纯文本输出
  static List<RunTask> parseGradleTasksOutput(String output, String execCmd) {
    final List<RunTask> tasks = [];
    final lines = LineSplitter.split(output).toList();

    String currentProjectPrefix = '';
    String currentGroup = 'other';
    bool inTasksSection = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 匹配项目标题行，形如：
      // "Tasks runnable from root project 'demo'" 或 "Tasks runnable from project ':app'"
      final projectMatch = RegExp(r"Tasks runnable from (?:root )?project '([^']+)'").firstMatch(line);
      if (projectMatch != null) {
        final proj = projectMatch.group(1)!;
        if (proj.startsWith(':')) {
          currentProjectPrefix = '$proj:';
        } else {
          currentProjectPrefix = '';
        }
        inTasksSection = true;
        continue;
      }

      // 遇到 Rules 或非任务分段时跳过
      if (line == 'Rules' || line.startsWith('Pattern:')) {
        inTasksSection = false;
        continue;
      }

      // 忽略单纯的分割线 (如 ------------------------------------------------------------)
      if (RegExp(r'^[-=]{3,}$').hasMatch(line)) {
        continue;
      }

      // 匹配分组名称与下划线分割，例如：
      // Build tasks
      // -----------
      if (i + 1 < lines.length && RegExp(r'^-{3,}$').hasMatch(lines[i + 1].trim())) {
        final groupMatch = RegExp(r'^([a-zA-Z0-9_\s]+)\s+tasks$', caseSensitive: false).firstMatch(line);
        if (groupMatch != null) {
          currentGroup = groupMatch.group(1)!.trim().toLowerCase();
          inTasksSection = true;
          i++; // 跳过下划线行
          continue;
        }
      }

      if (!inTasksSection) continue;

      // 匹配单个任务定义，例如：
      // assemble - Assembles the outputs of this project.
      // 或没有描述的任务：myCustomTask (任务名必须以字母/数字/冒号开头)
      final taskMatch = RegExp(r'^([a-zA-Z0-9:][a-zA-Z0-9_:\-]*)(?:\s+-\s+(.*))?$').firstMatch(line);
      if (taskMatch != null) {
        final rawTaskName = taskMatch.group(1)!;
        final description = taskMatch.group(2)?.trim();

        // 避免重复解析分组标题
        if (rawTaskName.toLowerCase().endsWith('tasks')) continue;

        final fullTaskName = rawTaskName.startsWith(':')
            ? rawTaskName
            : (currentProjectPrefix.isNotEmpty ? '$currentProjectPrefix$rawTaskName' : rawTaskName);

        final taskId = 'gradle_${fullTaskName.replaceAll(':', '_')}';
        final taskGroup = _normalizeGroup(currentGroup, fullTaskName);
        final icon = _selectIconForTask(fullTaskName, taskGroup);

        tasks.add(RunTask(
          id: taskId,
          name: fullTaskName,
          command: '$execCmd $fullTaskName',
          source: TaskSource.detected,
          description: description ?? 'Gradle task: $fullTaskName',
          group: taskGroup,
          moduleId: 'gradle',
          icon: icon,
        ));
      }
    }

    // 按任务分组与名称进行合理排序（常用 Build / Application / Verification 优先展示）
    tasks.sort((a, b) {
      final rankA = _groupPriority(a.group ?? '');
      final rankB = _groupPriority(b.group ?? '');
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.name.compareTo(b.name);
    });

    return tasks;
  }

  /// 兜底默认任务集（在未联网同步真实任务前呈现）
  static List<RunTask> fallbackDefaultTasks(Directory projectDir, String execCmd) {
    return [
      RunTask(
        id: 'detected_gradle_run',
        name: 'run',
        command: '$execCmd run',
        source: TaskSource.detected,
        description: 'Execute application main entrypoint',
        group: 'application',
        moduleId: 'gradle',
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'detected_gradle_assemble',
        name: 'assembleDebug',
        command: '$execCmd assembleDebug',
        source: TaskSource.detected,
        description: 'Build debug output package',
        group: 'build',
        moduleId: 'gradle',
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'detected_gradle_build',
        name: 'build',
        command: '$execCmd build',
        source: TaskSource.detected,
        description: 'Execute full build and tests',
        group: 'build',
        moduleId: 'gradle',
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'detected_gradle_clean',
        name: 'clean',
        command: '$execCmd clean',
        source: TaskSource.detected,
        description: 'Clean project build outputs',
        group: 'build',
        moduleId: 'gradle',
        icon: Icons.cleaning_services_outlined,
      ),
    ];
  }

  static String _normalizeGroup(String group, String taskName) {
    final g = group.trim().toLowerCase();
    if (g.contains('build')) return 'build';
    if (g.contains('application') || g.contains('run')) return 'application';
    if (g.contains('verification') || g.contains('test') || g.contains('check')) return 'verification';
    if (g.contains('documentation') || g.contains('doc')) return 'documentation';
    if (g.contains('help')) return 'help';
    if (g.contains('android')) return 'android';
    return g.isEmpty ? 'other' : g;
  }

  static int _groupPriority(String group) {
    switch (group) {
      case 'application':
        return 1;
      case 'build':
        return 2;
      case 'android':
        return 3;
      case 'verification':
        return 4;
      case 'documentation':
        return 5;
      case 'other':
        return 6;
      case 'help':
        return 7;
      default:
        return 8;
    }
  }

  static IconData _selectIconForTask(String taskName, String group) {
    final lower = taskName.toLowerCase();
    if (lower.contains('run') || lower.contains('start')) {
      return Icons.play_circle_outline;
    }
    if (lower.contains('clean')) {
      return Icons.cleaning_services_outlined;
    }
    if (lower.contains('test') || lower.contains('check') || lower.contains('lint')) {
      return Icons.fact_check_outlined;
    }
    if (group == 'build' || lower.contains('assemble') || lower.contains('bundle') || lower.contains('build') || lower.contains('compile')) {
      return Icons.build_outlined;
    }
    if (group == 'help' || lower.contains('help') || lower.contains('info')) {
      return Icons.help_outline;
    }
    return Icons.terminal_outlined;
  }
}
