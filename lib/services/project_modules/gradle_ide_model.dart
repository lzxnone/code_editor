import 'package:flutter/material.dart';

import '../../models/run_task.dart';

/// Gradle 结构化模型（由 init script 输出到 .code_editor/gradle_ide_model.json）
///
/// 这是"真正意义上搜索任务"的数据来源：任务名/路径/分组/描述/类型、
/// 以及 sourceSets、插件、配置名等后续做依赖导入所需要的信息，全部按字段读取，
/// 不再依赖任何人类可读文本输出与正则。
class GradleIdeModel {
  static const int schemaVersion = 1;

  final int schema;
  final String? gradleVersion;
  final String rootProject;
  final List<GradleIdeProject> projects;

  /// init script 内部异常时回填的错误信息（schema == 0）
  final String? error;

  const GradleIdeModel({
    required this.schema,
    required this.rootProject,
    required this.projects,
    this.gradleVersion,
    this.error,
  });

  /// 解析失败时抛 [FormatException]（调用方归类为 probeFailureUnparsable）
  static GradleIdeModel fromJson(Map<String, dynamic> json) {
    final schema = _asInt(json['schema']) ?? 0;
    if (schema == 0 && json.containsKey('error')) {
      throw FormatException(json['error']?.toString() ?? 'unexpected gradle ide model schema: 0');
    }
    if (schema != schemaVersion) {
      throw FormatException('unexpected gradle ide model schema: $schema');
    }
    final rawProjects = json['projects'];
    final projects = <GradleIdeProject>[];
    if (rawProjects is List) {
      for (final item in rawProjects) {
        if (item is Map) {
          projects.add(GradleIdeProject.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return GradleIdeModel(
      schema: schema,
      gradleVersion: json['gradleVersion']?.toString(),
      rootProject: json['rootProject']?.toString() ?? '',
      projects: projects,
      error: json['error']?.toString(),
    );
  }

  /// 转换为可执行任务列表
  List<RunTask> toRunTasks(String execCmd) {
    final tasks = <RunTask>[];
    final seen = <String>{};

    for (final project in projects) {
      final isRoot = project.path == ':' || project.path.isEmpty;
      for (final task in project.tasks) {
        // 根工程的 task.path 形如 ':assemble'，展示与 id 均沿用旧的命名习惯，
        // 保证既有用户数据（最近运行记录等）不失效。
        final fullName = isRoot ? task.name : (task.path.isNotEmpty ? task.path : ':${task.name}');
        if (!seen.add(fullName)) continue;

        final group = _normalizeGroup(task.group, fullName);
        tasks.add(RunTask(
          id: 'gradle_${fullName.replaceAll(':', '_')}',
          name: fullName,
          command: '$execCmd $fullName',
          source: TaskSource.detected,
          description: task.description,
          group: group,
          moduleId: 'gradle',
          icon: _selectIconForTask(fullName, group),
        ));
      }
    }

    tasks.sort((a, b) {
      final rankA = _groupPriority(a.group ?? '');
      final rankB = _groupPriority(b.group ?? '');
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.name.compareTo(b.name);
    });
    return tasks;
  }

  static String _normalizeGroup(String? group, String taskName) {
    final g = (group ?? '').trim().toLowerCase();
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
    if (group == 'build' ||
        lower.contains('assemble') ||
        lower.contains('bundle') ||
        lower.contains('build') ||
        lower.contains('compile')) {
      return Icons.build_outlined;
    }
    if (group == 'help' || lower.contains('help') || lower.contains('info')) {
      return Icons.help_outline;
    }
    return Icons.terminal_outlined;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 单个 Gradle 工程（含子模块）
class GradleIdeProject {
  final String path;
  final String name;
  final String? description;
  final String? buildFile;
  final List<String> plugins;
  final List<String> sourceSets;
  final List<String> configurations;
  final String? javaVersion;
  final List<GradleIdeTask> tasks;

  const GradleIdeProject({
    required this.path,
    required this.name,
    this.description,
    this.buildFile,
    this.plugins = const [],
    this.sourceSets = const [],
    this.configurations = const [],
    this.javaVersion,
    this.tasks = const [],
  });

  static GradleIdeProject fromJson(Map<String, dynamic> json) {
    return GradleIdeProject(
      path: json['path']?.toString() ?? ':',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      buildFile: json['buildFile']?.toString(),
      plugins: _stringList(json['plugins']),
      sourceSets: _stringList(json['sourceSets']),
      configurations: _stringList(json['configurations']),
      javaVersion: json['javaVersion']?.toString(),
      tasks: [
        for (final item in (json['tasks'] as List? ?? const []))
          if (item is Map) GradleIdeTask.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) item.toString()];
  }
}

/// 单个 Gradle 任务
class GradleIdeTask {
  final String name;
  final String path;
  final String? group;
  final String? description;
  final String? type;

  const GradleIdeTask({
    required this.name,
    required this.path,
    this.group,
    this.description,
    this.type,
  });

  static GradleIdeTask fromJson(Map<String, dynamic> json) {
    return GradleIdeTask(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      group: json['group']?.toString(),
      description: json['description']?.toString(),
      type: json['type']?.toString(),
    );
  }
}
