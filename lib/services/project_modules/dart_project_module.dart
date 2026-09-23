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

  /// 检查是否为 Flutter 项目（依赖包含 flutter sdk 或 flutter 配置节点）
  static bool isFlutterProject(Directory projectDir) {
    final pubspec = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    try {
      final content = pubspec.readAsStringSync();
      return content.contains('sdk: flutter') ||
          content.contains('\nflutter:') ||
          content.contains('flutter:\r\n');
    } catch (_) {
      return false;
    }
  }

  /// Dart SDK 目前没有可用的发行版一键安装命令，因此不做自动补全。
  /// 对于 Flutter 项目，若容器内未安装 Flutter 工具链则优雅跳过，避免误报"未找到 dart 探测失败"。
  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);

    final isFlutter = isFlutterProject(probe.projectDir);
    if (isFlutter) {
      final hasFlutter = await probe.hasCommand('flutter');
      if (hasFlutter) {
        return ModuleProbeResult.ok(id, [
          RunTask(
            id: 'detected_flutter_run',
            name: 'Flutter: Run',
            command: 'flutter run',
            source: TaskSource.detected,
            group: 'application',
            moduleId: id,
            icon: Icons.play_circle_outline,
          ),
          RunTask(
            id: 'detected_flutter_test',
            name: 'Flutter: Test',
            command: 'flutter test',
            source: TaskSource.detected,
            group: 'verification',
            moduleId: id,
            icon: Icons.fact_check_outlined,
          ),
        ]);
      }
      // 移动端轻量 Linux 容器未配置 Flutter SDK 时，作为纯代码项目正常打开，不弹出报错打扰用户
      return ModuleProbeResult.ok(id, const []);
    }

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
