import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/services/run_task_storage_service.dart';
import 'package:code_editor/services/project_task_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunTask & RunTaskStorageService Tests', () {
    late Directory tempDir;
    late RunTaskStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('run_task_test_');
      storageService = RunTaskStorageService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('save and load custom tasks', () async {
      final initialTasks = await storageService.loadTasks(tempDir.path);
      expect(initialTasks, isEmpty);

      final customTask = const RunTask(
        id: 'task_1',
        name: 'Debug Build',
        command: 'cmake -B build && cmake --build build',
        source: TaskSource.custom,
        description: 'Test description',
        clearBeforeRun: true,
      );

      await storageService.saveTasks(tempDir.path, [customTask]);

      final loadedTasks = await storageService.loadTasks(tempDir.path);
      expect(loadedTasks.length, 1);
      expect(loadedTasks.first.id, 'task_1');
      expect(loadedTasks.first.name, 'Debug Build');
      expect(loadedTasks.first.command, 'cmake -B build && cmake --build build');
      expect(loadedTasks.first.source, TaskSource.custom);

      // 测试 lastRunTaskId 持久化与读取
      await storageService.saveConfig(
        projectRoot: tempDir.path,
        tasks: [customTask],
        lastRunTaskId: 'task_1',
      );
      final config = await storageService.loadConfig(tempDir.path);
      expect(config.lastRunTaskId, 'task_1');
      expect(config.tasks.length, 1);
    });

    test('ProjectTaskDetector detects CMake and single file', () async {
      // 模拟 CMakeLists.txt
      final cmakeFile = File('${tempDir.path}/CMakeLists.txt');
      await cmakeFile.writeAsString('cmake_minimum_required(VERSION 3.10)');

      // 模拟 main.py
      final pyFile = File('${tempDir.path}/main.py');
      await pyFile.writeAsString('print("hello")');

      final tasks = await ProjectTaskDetector.detect(
        projectRoot: tempDir.path,
        currentFilePath: pyFile.path,
      );

      expect(tasks.isNotEmpty, isTrue);
      // 首项为当前打开的 Python 文件单文件任务
      expect(tasks.first.id, 'detected_single_python');
      expect(tasks.first.command, contains('python3'));

      // 包含 CMake 相关构建任务
      expect(tasks.any((t) => t.id == 'detected_cmake_build_run'), isTrue);
      expect(tasks.any((t) => t.id == 'detected_cmake_clean'), isTrue);
    });
  });
}
