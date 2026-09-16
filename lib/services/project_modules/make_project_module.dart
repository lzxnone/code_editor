import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Makefile 工程模块：真实解析 Makefile 目标 + 工具链检查
class MakeProjectModule extends ProjectModule {
  @override
  String get id => 'make';

  @override
  String get displayName => 'Makefile';

  @override
  List<String> get triggerFiles => const ['Makefile'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'Makefile')).existsSync();

  @override
  List<String> get requiredToolchainKeys => const ['make'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    final targets = _readTargets(probe.projectDir);
    return ModuleProbeResult.ok(
      id,
      [
        RunTask(
          id: 'detected_make_default',
          name: 'Make: Default',
          command: 'make',
          source: TaskSource.detected,
          group: 'build',
          moduleId: id,
          icon: Icons.build_circle_outlined,
        ),
        for (final target in targets)
          RunTask(
            id: 'make_$target',
            name: 'make $target',
            command: 'make $target',
            source: TaskSource.detected,
            group: _groupForTarget(target),
            moduleId: id,
            icon: _iconForTarget(target),
          ),
      ],
    );
  }

  static String _groupForTarget(String target) {
    final lower = target.toLowerCase();
    if (lower.startsWith('test') || lower.startsWith('check') || lower.contains('lint')) {
      return 'verification';
    }
    return 'build';
  }

  static IconData _iconForTarget(String target) {
    final lower = target.toLowerCase();
    if (lower == 'clean') return Icons.cleaning_services_outlined;
    if (lower.startsWith('test') || lower.startsWith('check') || lower.contains('lint')) {
      return Icons.fact_check_outlined;
    }
    return Icons.build_outlined;
  }

  /// 解析 Makefile 中显式声明的目标名（跳过变量赋值与特殊目标）
  static List<String> _readTargets(Directory projectDir) {
    try {
      final file = File(p.join(projectDir.path, 'Makefile'));
      if (!file.existsSync()) return const [];
      final result = <String>[];
      final pattern = RegExp(r'^([A-Za-z0-9_][A-Za-z0-9_.\-]*)\s*:(?!=)');
      for (final rawLine in file.readAsLinesSync()) {
        if (rawLine.startsWith('\t') || rawLine.trimLeft().startsWith('#')) continue;
        final match = pattern.firstMatch(rawLine);
        if (match == null) continue;
        final target = match.group(1)!;
        if (target == 'default' || result.contains(target)) continue;
        result.add(target);
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
