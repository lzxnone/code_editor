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
      if (decoded is Map) {
        final lastId = decoded['lastRunTaskId']?.toString();
        final tasksRaw = decoded['tasks'];
        List<RunTask> list = [];
        if (tasksRaw is List) {
          for (final item in tasksRaw) {
            if (item is Map) {
              list.add(RunTask.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        return (tasks: list, lastRunTaskId: lastId);
      } else if (decoded is List) {
        List<RunTask> list = [];
        for (final item in decoded) {
          if (item is Map) {
            list.add(RunTask.fromJson(Map<String, dynamic>.from(item)));
          }
        }
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

  /// 获取特定模块的独立任务缓存配置文件（例如 `.code_editor/gradle_tasks.json`）
  File getModuleConfigFile(String projectRoot, String moduleName) {
    return File(p.join(projectRoot, configDirName, '${moduleName}_tasks.json'));
  }

  /// 从工程的 `.code_editor/<module>_tasks.json` 中读取模块探测出的任务与缓存元信息
  Future<({List<RunTask> tasks, String? hash, DateTime? updatedAt})> loadModuleTasks(
    String projectRoot,
    String moduleName,
  ) async {
    try {
      final file = getModuleConfigFile(projectRoot, moduleName);
      if (!await file.exists()) {
        return (tasks: <RunTask>[], hash: null, updatedAt: null);
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return (tasks: <RunTask>[], hash: null, updatedAt: null);
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map) {
        final hash = decoded['buildScriptHash']?.toString();
        final rawUpdated = decoded['updatedAt']?.toString();
        final updatedAt = rawUpdated != null ? DateTime.tryParse(rawUpdated) : null;
        final tasksRaw = decoded['tasks'];
        final List<RunTask> list = [];
        if (tasksRaw is List) {
          for (final item in tasksRaw) {
            if (item is Map) {
              list.add(RunTask.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        return (tasks: list, hash: hash, updatedAt: updatedAt);
      }
      return (tasks: <RunTask>[], hash: null, updatedAt: null);
    } catch (e) {
      debugPrint('[RunTaskStorageService] 读取 ${moduleName}_tasks.json 失败: $e');
      return (tasks: <RunTask>[], hash: null, updatedAt: null);
    }
  }

  /// 将特定模块探测所得任务与缓存哈希持久化保存到 `.code_editor/<module>_tasks.json`
  Future<void> saveModuleTasks({
    required String projectRoot,
    required String moduleName,
    required List<RunTask> tasks,
    String? hash,
  }) async {
    try {
      final file = getModuleConfigFile(projectRoot, moduleName);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final data = {
        'version': '1.0',
        'module': moduleName,
        'updatedAt': DateTime.now().toIso8601String(),
        if (hash != null && hash.isNotEmpty) 'buildScriptHash': hash,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(data);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[RunTaskStorageService] 保存 ${moduleName}_tasks.json 失败: $e');
    }
  }
}
