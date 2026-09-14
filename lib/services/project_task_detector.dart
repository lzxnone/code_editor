import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/run_task.dart';

/// 负责根据工程文件和当前打开的文件，在内存中动态推导可用的运行任务
class ProjectTaskDetector {
  /// 核心探测入口
  /// [projectRoot]: 工程根目录（宿主绝对路径）
  /// [currentFilePath]: 当前编辑器激活打开的文件（宿主绝对路径，可能为 null）
  static Future<List<RunTask>> detect({
    required String projectRoot,
    String? currentFilePath,
  }) async {
    final List<RunTask> tasks = [];
    final projectDir = Directory(projectRoot);
    if (!projectDir.existsSync()) {
      return tasks;
    }

    // 1. 工程级特征文件检测
    tasks.addAll(await _detectProjectBuildTasks(projectRoot));

    // 2. 当前活跃文件（单文件运行）检测
    if (currentFilePath != null && currentFilePath.isNotEmpty) {
      final singleTask = _detectSingleFileTask(projectRoot, currentFilePath);
      if (singleTask != null) {
        // 单文件即时运行置于首位，方便用户直接点击运行
        tasks.insert(0, singleTask);
      }
    }

    return tasks;
  }

  /// 探测构建工程任务（CMake / Gradle / Makefile / npm / Cargo / Dart 等）
  static Future<List<RunTask>> _detectProjectBuildTasks(String projectRoot) async {
    final List<RunTask> buildTasks = [];

    // 1. CMakeLists.txt
    final cmakeFile = File(p.join(projectRoot, 'CMakeLists.txt'));
    if (cmakeFile.existsSync()) {
      final projectName = p.basename(projectRoot);
      buildTasks.addAll([
        RunTask(
          id: 'detected_cmake_build_run',
          name: 'CMake: Build & Run',
          command: 'cmake -B build && cmake --build build && ./build/$projectName',
          source: TaskSource.detected,
          description: 'Configure, build, and try launching the target executable',
          icon: Icons.play_circle_outline,
        ),
        RunTask(
          id: 'detected_cmake_build',
          name: 'CMake: Build Only',
          command: 'cmake -B build && cmake --build build',
          source: TaskSource.detected,
          description: 'Only execute cmake generation and build',
          icon: Icons.build_outlined,
        ),
        RunTask(
          id: 'detected_cmake_clean',
          name: 'CMake: Clean',
          command: 'rm -rf build',
          source: TaskSource.detected,
          description: 'Clean build cache directory',
          icon: Icons.cleaning_services_outlined,
        ),
      ]);
    }

    // 2. Gradle (build.gradle / gradlew)
    final gradlewFile = File(p.join(projectRoot, 'gradlew'));
    final gradleFile = File(p.join(projectRoot, 'build.gradle'));
    final gradleKtsFile = File(p.join(projectRoot, 'build.gradle.kts'));
    if (gradlewFile.existsSync() || gradleFile.existsSync() || gradleKtsFile.existsSync()) {
      final exec = gradlewFile.existsSync() ? 'sh ./gradlew' : 'gradle';
      buildTasks.addAll([
        RunTask(
          id: 'detected_gradle_run',
          name: 'Gradle: Run',
          command: '$exec run',
          source: TaskSource.detected,
          description: 'Execute application main entrypoint',
          icon: Icons.play_circle_outline,
        ),
        RunTask(
          id: 'detected_gradle_assemble',
          name: 'Gradle: Assemble Debug',
          command: '$exec assembleDebug',
          source: TaskSource.detected,
          description: 'Build debug output package',
          icon: Icons.build_outlined,
        ),
        RunTask(
          id: 'detected_gradle_build',
          name: 'Gradle: Build',
          command: '$exec build',
          source: TaskSource.detected,
          description: 'Execute full build and tests',
          icon: Icons.done_all_outlined,
        ),
      ]);
    }

    // 3. Makefile
    final makeFile = File(p.join(projectRoot, 'Makefile'));
    if (makeFile.existsSync()) {
      buildTasks.add(
        const RunTask(
          id: 'detected_make_default',
          name: 'Make: Default',
          command: 'make',
          source: TaskSource.detected,
          description: 'Execute default Makefile build target',
          icon: Icons.build_circle_outlined,
        ),
      );
    }

    // 4. package.json (Node/Web)
    final packageJsonFile = File(p.join(projectRoot, 'package.json'));
    if (packageJsonFile.existsSync()) {
      buildTasks.addAll([
        const RunTask(
          id: 'detected_npm_start',
          name: 'NPM: Start',
          command: 'npm start',
          source: TaskSource.detected,
          description: 'Start Node service or frontend development environment',
          icon: Icons.rocket_launch_outlined,
        ),
        const RunTask(
          id: 'detected_npm_test',
          name: 'NPM: Test',
          command: 'npm test',
          source: TaskSource.detected,
          description: 'Execute npm test suite',
          icon: Icons.checklist_outlined,
        ),
      ]);
    }

    // 5. Cargo.toml (Rust)
    final cargoFile = File(p.join(projectRoot, 'Cargo.toml'));
    if (cargoFile.existsSync()) {
      buildTasks.addAll([
        const RunTask(
          id: 'detected_cargo_run',
          name: 'Cargo: Run',
          command: 'cargo run',
          source: TaskSource.detected,
          description: 'Compile and run Rust project',
          icon: Icons.play_circle_outline,
        ),
        const RunTask(
          id: 'detected_cargo_build',
          name: 'Cargo: Build',
          command: 'cargo build',
          source: TaskSource.detected,
          description: 'Compile Rust project only',
          icon: Icons.build_outlined,
        ),
      ]);
    }

    // 6. pubspec.yaml (Dart)
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      buildTasks.add(
        const RunTask(
          id: 'detected_dart_run',
          name: 'Dart: Run',
          command: 'dart run',
          source: TaskSource.detected,
          description: 'Launch Dart application',
          icon: Icons.play_circle_outline,
        ),
      );
    }

    return buildTasks;
  }

  /// 探测单文件运行指令（基于当前打开的文件）
  static RunTask? _detectSingleFileTask(String projectRoot, String currentFilePath) {
    final file = File(currentFilePath);
    if (!file.existsSync()) return null;

    final fileName = p.basename(currentFilePath);
    final ext = p.extension(currentFilePath).toLowerCase();

    // 转换相对容器的路径（在容器内 /workspace 下执行）
    String relPath = p.relative(currentFilePath, from: projectRoot).replaceAll(r'\', '/');
    if (!relPath.startsWith('./') && !relPath.startsWith('/')) {
      relPath = './$relPath';
    }

    switch (ext) {
      case '.py':
        return RunTask(
          id: 'detected_single_python',
          name: 'Python: $fileName',
          command: 'python3 "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Python script',
          icon: Icons.code,
        );
      case '.c':
        return RunTask(
          id: 'detected_single_c',
          name: 'GCC: $fileName',
          command: 'gcc "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current C source file',
          icon: Icons.terminal,
        );
      case '.cpp':
      case '.cc':
      case '.cxx':
        return RunTask(
          id: 'detected_single_cpp',
          name: 'G++: $fileName',
          command: 'g++ "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current C++ source file',
          icon: Icons.terminal,
        );
      case '.sh':
      case '.bash':
        return RunTask(
          id: 'detected_single_sh',
          name: 'Shell: $fileName',
          command: 'sh "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Shell script',
          icon: Icons.terminal,
        );
      case '.dart':
        return RunTask(
          id: 'detected_single_dart',
          name: 'Dart: $fileName',
          command: 'dart run "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Dart file',
          icon: Icons.code,
        );
      case '.go':
        return RunTask(
          id: 'detected_single_go',
          name: 'Go: $fileName',
          command: 'go run "$relPath"',
          source: TaskSource.detected,
          description: 'Run current Go source file',
          icon: Icons.code,
        );
      case '.rs':
        return RunTask(
          id: 'detected_single_rust',
          name: 'Rust: $fileName',
          command: 'rustc "$relPath" -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          description: 'Compile and execute current Rust source file',
          icon: Icons.code,
        );
      case '.js':
        return RunTask(
          id: 'detected_single_js',
          name: 'Node: $fileName',
          command: 'node "$relPath"',
          source: TaskSource.detected,
          description: 'Run current JavaScript script',
          icon: Icons.javascript,
        );
      default:
        return null;
    }
  }
}
