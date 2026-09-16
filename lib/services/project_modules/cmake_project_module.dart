import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// CMake 工程模块：工具链在目标系统内可用时才产出任务
class CMakeProjectModule extends ProjectModule {
  @override
  String get id => 'cmake';

  @override
  String get displayName => 'CMake';

  @override
  List<String> get triggerFiles => const ['CMakeLists.txt'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'CMakeLists.txt')).existsSync();

  @override
  List<String> get requiredToolchainKeys => const ['cmake'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    final targetName = _detectExecutableTarget(probe.projectDir) ?? p.basename(probe.projectDir.path);
    final safeTarget = targetName.replaceAll("'", r"'\''");
    return ModuleProbeResult.ok(id, [
      RunTask(
        id: 'detected_cmake_build_run',
        name: 'CMake: Build & Run',
        command: "cmake -B build && cmake --build build && './build/$safeTarget'",
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'detected_cmake_build',
        name: 'CMake: Build Only',
        command: 'cmake -B build && cmake --build build',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'detected_cmake_clean',
        name: 'CMake: Clean',
        command: 'rm -rf build',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.cleaning_services_outlined,
      ),
    ]);
  }

  /// 从 CMakeLists.txt 尝试提取首个 add_executable(target ...) 目标名
  static String? _detectExecutableTarget(Directory projectDir) {
    try {
      final cmakeFile = File(p.join(projectDir.path, 'CMakeLists.txt'));
      if (!cmakeFile.existsSync()) return null;
      final content = cmakeFile.readAsStringSync();
      final match = RegExp(
        r'add_executable\s*\(\s*([A-Za-z0-9_.\-]+)',
        caseSensitive: false,
      ).firstMatch(content);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }
}
