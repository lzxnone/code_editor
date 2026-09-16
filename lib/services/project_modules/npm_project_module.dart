import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// NPM (Node / Web) 工程模块：真实读取 package.json 的 scripts
class NpmProjectModule extends ProjectModule {
  @override
  String get id => 'npm';

  @override
  String get displayName => 'NPM';

  @override
  List<String> get triggerFiles => const ['package.json'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'package.json')).existsSync();

  @override
  List<String> get requiredToolchainKeys => const ['npm'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    final scripts = _readScripts(probe.projectDir);
    if (scripts.isEmpty) {
      return ModuleProbeResult.ok(id, const <RunTask>[]);
    }
    return ModuleProbeResult.ok(
      id,
      [
        for (final name in scripts)
          RunTask(
            // start / test 沿用历史 id 以复用已有的多语言描述
            id: switch (name) {
              'start' => 'detected_npm_start',
              'test' => 'detected_npm_test',
              _ => 'npm_$name',
            },
            name: 'npm run $name',
            command: 'npm run $name',
            source: TaskSource.detected,
            group: _groupForScript(name),
            moduleId: id,
            icon: _iconForScript(name),
          ),
      ],
    );
  }

  /// 解析 package.json 的 scripts（结构化读取，不做文本解析）
  static List<String> _readScripts(Directory projectDir) {
    try {
      final file = File(p.join(projectDir.path, 'package.json'));
      if (!file.existsSync()) return const [];
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const [];
      final scripts = decoded['scripts'];
      if (scripts is! Map) return const [];
      return [for (final key in scripts.keys) key.toString()];
    } catch (_) {
      return const [];
    }
  }

  static String _groupForScript(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('test') || lower.contains('lint') || lower.contains('check')) {
      return 'verification';
    }
    if (lower.startsWith('build')) return 'build';
    return 'application';
  }

  static IconData _iconForScript(String name) {
    final group = _groupForScript(name);
    if (group == 'verification') return Icons.fact_check_outlined;
    if (group == 'build') return Icons.build_outlined;
    return Icons.play_circle_outline;
  }
}
