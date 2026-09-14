import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
    final rawClear = json['clearBeforeRun'];
    final bool clearVal = (rawClear is bool)
        ? rawClear
        : (rawClear is num ? rawClear != 0 : (rawClear?.toString().toLowerCase() == 'true'));

    return RunTask(
      id: json['id']?.toString() ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name']?.toString() ?? '未命名任务',
      command: json['command']?.toString() ?? '',
      source: TaskSource.custom,
      description: json['description']?.toString(),
      workingDir: json['workingDir']?.toString(),
      clearBeforeRun: clearVal,
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

  /// 获取多语言本地化的任务描述/小字（自动根据系统探测任务 ID 映射，未匹配或自定义任务返回原本的 description）
  String getLocalizedDescription(AppLocalizations l10n) {
    switch (id) {
      case 'detected_cmake_build_run':
        return l10n.detectedTaskCmakeBuildRunDesc;
      case 'detected_cmake_build':
        return l10n.detectedTaskCmakeBuildDesc;
      case 'detected_cmake_clean':
        return l10n.detectedTaskCmakeCleanDesc;
      case 'detected_gradle_run':
        return l10n.detectedTaskGradleRunDesc;
      case 'detected_gradle_assemble':
        return l10n.detectedTaskGradleAssembleDesc;
      case 'detected_gradle_build':
        return l10n.detectedTaskGradleBuildDesc;
      case 'detected_make_default':
        return l10n.detectedTaskMakeDefaultDesc;
      case 'detected_npm_start':
        return l10n.detectedTaskNpmStartDesc;
      case 'detected_npm_test':
        return l10n.detectedTaskNpmTestDesc;
      case 'detected_cargo_run':
        return l10n.detectedTaskCargoRunDesc;
      case 'detected_cargo_build':
        return l10n.detectedTaskCargoBuildDesc;
      case 'detected_dart_run':
        return l10n.detectedTaskDartRunDesc;
      case 'detected_single_python':
        return l10n.detectedTaskSinglePythonDesc;
      case 'detected_single_c':
        return l10n.detectedTaskSingleCDesc;
      case 'detected_single_cpp':
        return l10n.detectedTaskSingleCppDesc;
      case 'detected_single_sh':
        return l10n.detectedTaskSingleShDesc;
      case 'detected_single_dart':
        return l10n.detectedTaskSingleDartDesc;
      case 'detected_single_go':
        return l10n.detectedTaskSingleGoDesc;
      case 'detected_single_rust':
        return l10n.detectedTaskSingleRustDesc;
      case 'detected_single_js':
        return l10n.detectedTaskSingleJsDesc;
      default:
        return description ?? '';
    }
  }

  /// 获取多语言本地化的任务名称（自定义且为默认名时返回对应语言的“未命名任务”）
  String getLocalizedName(AppLocalizations l10n) {
    if (name == '未命名任务' || name == 'Unnamed Task') {
      return l10n.unnamedTask;
    }
    return name;
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
