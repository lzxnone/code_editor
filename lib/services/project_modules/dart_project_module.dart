import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/notice_item.dart';
import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Dart (pubspec.yaml) 工程模块
class DartProjectModule extends ProjectModule {
  @override
  String get id => 'dart';

  @override
  String get displayName => 'Dart';

  @override
  List<String> get triggerFiles => const ['pubspec.yaml'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'pubspec.yaml')).existsSync();

  /// Dart SDK 目前没有可用的发行版一键安装命令，因此不做自动补全，
  /// 仅在探测阶段如实报告"未找到 dart"。
  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    final available = await probe.hasCommand('dart');
    if (!available) {
      return const ModuleProbeResult.failed(
        'dart',
        failure: NoticeFailure.toolchainMissing,
        detail: 'dart',
      );
    }
    return ModuleProbeResult.ok(id, [
      RunTask(
        id: 'detected_dart_run',
        name: 'Dart: Run',
        command: 'dart run',
        source: TaskSource.detected,
        group: 'application',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'dart_test',
        name: 'Dart: Test',
        command: 'dart test',
        source: TaskSource.detected,
        group: 'verification',
        moduleId: id,
        icon: Icons.fact_check_outlined,
      ),
    ]);
  }
}
