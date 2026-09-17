import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Maven (Java) 工程模块：识别 pom.xml 或 mvnw 包装脚本
class MavenProjectModule extends ProjectModule {
  @override
  String get id => 'maven';

  @override
  String get displayName => 'Maven';

  @override
  List<String> get triggerFiles => const ['pom.xml', 'mvnw'];

  @override
  bool shouldActivate(Directory projectDir) {
    return triggerFiles.any((f) => File(p.join(projectDir.path, f)).existsSync());
  }

  @override
  List<String> get requiredToolchainKeys => const ['maven'];

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);

    final root = probe.projectDir;
    final hasWrapper = File(p.join(root.path, 'mvnw')).existsSync();
    final cmdPrefix = hasWrapper ? './mvnw' : 'mvn';

    return ModuleProbeResult.ok(id, [
      RunTask(
        id: 'detected_maven_package',
        name: 'Maven: Package',
        command: '$cmdPrefix package',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.inventory_2_outlined,
      ),
      RunTask(
        id: 'detected_maven_compile',
        name: 'Maven: Compile',
        command: '$cmdPrefix compile',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'detected_maven_test',
        name: 'Maven: Test',
        command: '$cmdPrefix test',
        source: TaskSource.detected,
        group: 'verification',
        moduleId: id,
        icon: Icons.fact_check_outlined,
      ),
      RunTask(
        id: 'detected_maven_clean',
        name: 'Maven: Clean',
        command: '$cmdPrefix clean',
        source: TaskSource.detected,
        group: 'build',
        moduleId: id,
        icon: Icons.cleaning_services_outlined,
      ),
    ]);
  }
}
