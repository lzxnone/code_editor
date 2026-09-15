import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/run_task.dart';
import 'project_module.dart';

/// CMake 工程探测模块
class CMakeProjectModule extends ProjectModule {
  @override
  String get id => 'cmake';

  @override
  String get displayName => 'CMake';

  @override
  List<String> get triggerFiles => const ['CMakeLists.txt'];

  @override
  bool shouldActivate(Directory projectDir) {
    return File(p.join(projectDir.path, 'CMakeLists.txt')).existsSync();
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    final projectName = p.basename(context.projectDir.path);
    return [
      RunTask(
        id: 'detected_cmake_build_run',
        name: 'CMake: Build & Run',
        command: 'cmake -B build && cmake --build build && ./build/$projectName',
        source: TaskSource.detected,
        description: 'Configure, build, and try launching the target executable',
        group: 'build',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'detected_cmake_build',
        name: 'CMake: Build Only',
        command: 'cmake -B build && cmake --build build',
        source: TaskSource.detected,
        description: 'Only execute cmake generation and build',
        group: 'build',
        moduleId: id,
        icon: Icons.build_outlined,
      ),
      RunTask(
        id: 'detected_cmake_clean',
        name: 'CMake: Clean',
        command: 'rm -rf build',
        source: TaskSource.detected,
        description: 'Clean build cache directory',
        group: 'build',
        moduleId: id,
        icon: Icons.cleaning_services_outlined,
      ),
    ];
  }
}

/// Cargo (Rust) 工程探测模块
class CargoProjectModule extends ProjectModule {
  @override
  String get id => 'cargo';

  @override
  String get displayName => 'Cargo';

  @override
  List<String> get triggerFiles => const ['Cargo.toml'];

  @override
  bool shouldActivate(Directory projectDir) {
    return File(p.join(projectDir.path, 'Cargo.toml')).existsSync();
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    return [
      RunTask(
        id: 'detected_cargo_run',
        name: 'Cargo: Run',
        command: 'cargo run',
        source: TaskSource.detected,
        description: 'Compile and run Rust project',
        group: 'application',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
      RunTask(
        id: 'detected_cargo_build',
        name: 'Cargo: Build',
        command: 'cargo build',
        source: TaskSource.detected,
        description: 'Compile Rust project only',
        group: 'build',
        moduleId: id,
        icon: Icons.build_outlined,
      ),
    ];
  }
}

/// NPM (Node / Web) 工程探测模块
class NpmProjectModule extends ProjectModule {
  @override
  String get id => 'npm';

  @override
  String get displayName => 'NPM';

  @override
  List<String> get triggerFiles => const ['package.json'];

  @override
  bool shouldActivate(Directory projectDir) {
    return File(p.join(projectDir.path, 'package.json')).existsSync();
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    return [
      RunTask(
        id: 'detected_npm_start',
        name: 'NPM: Start',
        command: 'npm start',
        source: TaskSource.detected,
        description: 'Start Node service or frontend development environment',
        group: 'application',
        moduleId: id,
        icon: Icons.rocket_launch_outlined,
      ),
      RunTask(
        id: 'detected_npm_test',
        name: 'NPM: Test',
        command: 'npm test',
        source: TaskSource.detected,
        description: 'Execute npm test suite',
        group: 'verification',
        moduleId: id,
        icon: Icons.checklist_outlined,
      ),
    ];
  }
}

/// Makefile 工程探测模块
class MakeProjectModule extends ProjectModule {
  @override
  String get id => 'make';

  @override
  String get displayName => 'Makefile';

  @override
  List<String> get triggerFiles => const ['Makefile'];

  @override
  bool shouldActivate(Directory projectDir) {
    return File(p.join(projectDir.path, 'Makefile')).existsSync();
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    return [
      RunTask(
        id: 'detected_make_default',
        name: 'Make: Default',
        command: 'make',
        source: TaskSource.detected,
        description: 'Execute default Makefile build target',
        group: 'build',
        moduleId: id,
        icon: Icons.build_circle_outlined,
      ),
    ];
  }
}

/// Dart (pubspec.yaml) 工程探测模块
class DartProjectModule extends ProjectModule {
  @override
  String get id => 'dart';

  @override
  String get displayName => 'Dart';

  @override
  List<String> get triggerFiles => const ['pubspec.yaml'];

  @override
  bool shouldActivate(Directory projectDir) {
    return File(p.join(projectDir.path, 'pubspec.yaml')).existsSync();
  }

  @override
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false}) async {
    return [
      RunTask(
        id: 'detected_dart_run',
        name: 'Dart: Run',
        command: 'dart run',
        source: TaskSource.detected,
        description: 'Launch Dart application',
        group: 'application',
        moduleId: id,
        icon: Icons.play_circle_outline,
      ),
    ];
  }
}
