import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Cargo (Rust) 工程模块：真实读取 Cargo.toml 的 [[bin]] 定义
class CargoProjectModule extends ProjectModule {
  @override
  String get id => 'cargo';

  @override
  String get displayName => 'Cargo';

  @override
  List<String> get triggerFiles => const ['Cargo.toml'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'Cargo.toml')).existsSync();

  @override
  List<String> get requiredToolchainKeys => const ['cargo'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    final bins = _declaredBinaryNames(probe.projectDir);
    return ModuleProbeResult.ok(id, [
      // 显式声明的二进制目标优先展示（真实读取 [[bin]] name）
      for (final bin in bins)
        RunTask(
          id: 'cargo_run_$bin',
          name: 'Cargo: Run $bin',
          command: 'cargo run --bin $bin',
          source: TaskSource.detected,
          group: 'application',
          moduleId: id,
          icon: Icons.play_circle_outline,
        ),
      RunTask(
        id: 'detected_cargo_run',
        name: 'Cargo: Run',
        command: 'cargo run',
        source: TaskSource.detected,
        group: 'application',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'detected_cargo_build',
        name: 'Cargo: Build',
        command: 'cargo build',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'cargo_test',
        name: 'Cargo: Test',
        command: 'cargo test',
        source: TaskSource.detected,
        group: 'verification',
        moduleId: id,
        icon: Icons.fact_check_outlined,
      ),
    ]);
  }

  /// 从 Cargo.toml 提取 [[bin]] name（结构化读取）
  static List<String> _declaredBinaryNames(Directory projectDir) {
    try {
      final file = File(p.join(projectDir.path, 'Cargo.toml'));
      if (!file.existsSync()) return const [];
      final content = file.readAsStringSync();
      final names = <String>[];
      var inBinSection = false;
      for (final rawLine in content.split('\n')) {
        final commentIdx = rawLine.indexOf('#');
        final lineWithoutComment = commentIdx != -1 ? rawLine.substring(0, commentIdx) : rawLine;
        final line = lineWithoutComment.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('[')) {
          inBinSection = RegExp(r'^\[\[\s*bin\s*\]\]$').hasMatch(line);
          continue;
        }
        if (inBinSection && line.startsWith('name')) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            final value = parts[1].trim().replaceAll('"', '').replaceAll("'", '').trim();
            if (value.isNotEmpty && !names.contains(value)) names.add(value);
          }
        }
      }
      return names;
    } catch (_) {
      return const [];
    }
  }
}
