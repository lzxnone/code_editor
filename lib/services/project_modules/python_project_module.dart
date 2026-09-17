import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Python 工程模块：识别 requirements.txt、pyproject.toml 等特征
class PythonProjectModule extends ProjectModule {
  @override
  String get id => 'python';

  @override
  String get displayName => 'Python';

  @override
  List<String> get triggerFiles => const [
        'requirements.txt',
        'pyproject.toml',
        'setup.py',
        'Pipfile',
      ];

  @override
  bool shouldActivate(Directory projectDir) {
    return triggerFiles.any((f) => File(p.join(projectDir.path, f)).existsSync());
  }

  @override
  List<String> get requiredToolchainKeys => const ['python3'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);

    final tasks = <RunTask>[];
    final root = probe.projectDir;

    // 1. 依赖安装任务
    if (File(p.join(root.path, 'requirements.txt')).existsSync()) {
      tasks.add(
        RunTask(
          id: 'detected_python_pip_install',
          name: 'Pip: Install Requirements',
          command: 'pip3 install -r requirements.txt',
          source: TaskSource.detected,
          group: 'build',
          moduleId: id,
          icon: Icons.download_outlined,
        ),
      );
    }

    // 2. 主入口任务
    if (File(p.join(root.path, 'main.py')).existsSync()) {
      tasks.add(
        RunTask(
          id: 'detected_python_run_main',
          name: 'Python: Run main.py',
          command: 'python3 main.py',
          source: TaskSource.detected,
          group: 'application',
          moduleId: id,
          icon: Icons.play_circle_outline,
        ),
      );
    } else if (File(p.join(root.path, 'app.py')).existsSync()) {
      tasks.add(
        RunTask(
          id: 'detected_python_run_app',
          name: 'Python: Run app.py',
          command: 'python3 app.py',
          source: TaskSource.detected,
          group: 'application',
          moduleId: id,
          icon: Icons.play_circle_outline,
        ),
      );
    }

    // 3. 测试任务
    final hasTestsDir = Directory(p.join(root.path, 'tests')).existsSync() ||
        Directory(p.join(root.path, 'test')).existsSync();
    final hasPytestIni = File(p.join(root.path, 'pytest.ini')).existsSync();
    if (hasTestsDir || hasPytestIni) {
      tasks.add(
        RunTask(
          id: 'detected_python_pytest',
          name: 'Pytest: Run Tests',
          command: 'pytest',
          source: TaskSource.detected,
          group: 'verification',
          moduleId: id,
          icon: Icons.fact_check_outlined,
        ),
      );
    }

    return ModuleProbeResult.ok(id, tasks);
  }
}
