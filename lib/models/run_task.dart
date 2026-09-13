import 'package:flutter/material.dart';

/// 运行任务来源类型
enum TaskSource {
  /// 系统动态探测所得（保存在内存，随项目探测刷新）
  detected,

  /// 用户在 .code_editor/run_tasks.json 中持久化配置
  custom,
}

/// 运行任务实体模型
class RunTask {
  /// 任务唯一ID
  final String id;

  /// 任务展示名称
  final String name;

  /// 发送到终端执行的 Shell 命令（支持 &&、; 串联多条命令）
  final String command;

  /// 任务来源（探测/用户自定义）
  final TaskSource source;

  /// 任务补充描述/副标题（通常是命令预览或文件路径）
  final String? description;

  /// 容器内相对工作路径（为 null 时默认容器工作区 /workspace）
  final String? workingDir;

  /// 是否在执行该命令前清屏（发送 clear）
  final bool clearBeforeRun;

  /// UI 展示图标（可选）
  final IconData? icon;

  const RunTask({
    required this.id,
    required this.name,
    required this.command,
    required this.source,
    this.description,
    this.workingDir,
    this.clearBeforeRun = false,
    this.icon,
  });

  /// 从持久化的 JSON Map 构建自定义运行任务
  factory RunTask.fromJson(Map<String, dynamic> json) {
    return RunTask(
      id: json['id'] as String? ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? '未命名任务',
      command: json['command'] as String? ?? '',
      source: TaskSource.custom,
      description: json['description'] as String?,
      workingDir: json['workingDir'] as String?,
      clearBeforeRun: json['clearBeforeRun'] as bool? ?? false,
    );
  }

  /// 序列化为持久化 JSON Map（仅针对用户自定义任务保存）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'command': command,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (workingDir != null && workingDir!.isNotEmpty) 'workingDir': workingDir,
      'clearBeforeRun': clearBeforeRun,
    };
  }

  RunTask copyWith({
    String? id,
    String? name,
    String? command,
    TaskSource? source,
    String? description,
    String? workingDir,
    bool? clearBeforeRun,
    IconData? icon,
  }) {
    return RunTask(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      source: source ?? this.source,
      description: description ?? this.description,
      workingDir: workingDir ?? this.workingDir,
      clearBeforeRun: clearBeforeRun ?? this.clearBeforeRun,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunTask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          command == other.command &&
          source == other.source;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ command.hashCode ^ source.hashCode;
}
