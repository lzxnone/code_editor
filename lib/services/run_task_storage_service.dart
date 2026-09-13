import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/run_task.dart';

/// 负责工程目录下 `.code_editor/run_tasks.json` 的读写与持久化管理
class RunTaskStorageService {
  static const String configDirName = '.code_editor';
  static const String configFileName = 'run_tasks.json';

  /// 获取配置文件的绝对 File 对象
  File getConfigFile(String projectRoot) {
    return File(p.join(projectRoot, configDirName, configFileName));
  }

  /// 从工程的 `.code_editor/run_tasks.json` 中读取持久化的配置（包括自定义任务与最近运行任务ID）
  Future<({List<RunTask> tasks, String? lastRunTaskId})> loadConfig(String projectRoot) async {
    try {
      final file = getConfigFile(projectRoot);
      if (!await file.exists()) {
        return (tasks: <RunTask>[], lastRunTaskId: null);
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return (tasks: <RunTask>[], lastRunTaskId: null);
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final lastId = decoded['lastRunTaskId'] as String?;
        final tasksRaw = decoded['tasks'];
        List<RunTask> list = [];
        if (tasksRaw is List) {
          list = tasksRaw
              .whereType<Map<String, dynamic>>()
              .map((item) => RunTask.fromJson(item))
              .toList();
        }
        return (tasks: list, lastRunTaskId: lastId);
      } else if (decoded is List) {
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => RunTask.fromJson(item))
            .toList();
        return (tasks: list, lastRunTaskId: null);
      }
      return (tasks: <RunTask>[], lastRunTaskId: null);
    } catch (e) {
      debugPrint('[RunTaskStorageService] 读取 run_tasks.json 失败: $e');
      return (tasks: <RunTask>[], lastRunTaskId: null);
    }
  }

  /// 兼容旧方法：直接返回 tasks
  Future<List<RunTask>> loadTasks(String projectRoot) async {
    final result = await loadConfig(projectRoot);
    return result.tasks;
  }

  /// 将自定义任务列表与最近运行的任务ID持久化保存到 `.code_editor/run_tasks.json`
  Future<void> saveConfig({
    required String projectRoot,
    required List<RunTask> tasks,
    String? lastRunTaskId,
  }) async {
    try {
      final file = getConfigFile(projectRoot);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final data = {
        'version': '1.0',
        if (lastRunTaskId != null && lastRunTaskId.isNotEmpty) 'lastRunTaskId': lastRunTaskId,
        'tasks': tasks
            .where((t) => t.source == TaskSource.custom)
            .map((t) => t.toJson())
            .toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(data);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[RunTaskStorageService] 保存 run_tasks.json 失败: $e');
      rethrow;
    }
  }

  /// 兼容旧方法
  Future<void> saveTasks(String projectRoot, List<RunTask> tasks) async {
    await saveConfig(projectRoot: projectRoot, tasks: tasks);
  }
}
