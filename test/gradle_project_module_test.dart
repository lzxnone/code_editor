import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/services/project_modules/gradle_project_module.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';
import 'package:code_editor/services/run_task_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GradleProjectModule Parser Tests', () {
    test('parseGradleTasksOutput parses single project tasks, groups, and descriptions', () {
      const output = '''
------------------------------------------------------------
Tasks runnable from root project 'my-app'
------------------------------------------------------------

Application tasks
-----------------
run - Runs this project as a JVM application

Build tasks
-----------
assemble - Assembles the outputs of this project.
build - Assembles and tests this project.
clean - Deletes the build directory.

Verification tasks
------------------
check - Runs all checks.
test - Runs the test suite.

Other tasks
-----------
customTask - Executes a custom task
''';

      final tasks = GradleProjectModule.parseGradleTasksOutput(output, 'sh ./gradlew');
      expect(tasks, isNotEmpty);

      // 验证任务名称与命令
      final runTask = tasks.firstWhere((t) => t.name == 'run');
      expect(runTask.command, 'sh ./gradlew run');
      expect(runTask.group, 'application');
      expect(runTask.moduleId, 'gradle');
      expect(runTask.source, TaskSource.detected);
      expect(runTask.description, 'Runs this project as a JVM application');

      final assembleTask = tasks.firstWhere((t) => t.name == 'assemble');
      expect(assembleTask.command, 'sh ./gradlew assemble');
      expect(assembleTask.group, 'build');
      expect(assembleTask.moduleId, 'gradle');

      final buildTask = tasks.firstWhere((t) => t.name == 'build');
      expect(buildTask.command, 'sh ./gradlew build');
      expect(buildTask.group, 'build');

      final testTask = tasks.firstWhere((t) => t.name == 'test');
      expect(testTask.command, 'sh ./gradlew test');
      expect(testTask.group, 'verification');

      final customTask = tasks.firstWhere((t) => t.name == 'customTask');
      expect(customTask.command, 'sh ./gradlew customTask');
      expect(customTask.group, 'other');
      expect(customTask.description, 'Executes a custom task');

      // 优先级排序验证：application -> build -> verification -> other
      final groupsInOrder = tasks.map((t) => t.group).toList();
      final appIdx = groupsInOrder.indexOf('application');
      final buildIdx = groupsInOrder.indexOf('build');
      final verifIdx = groupsInOrder.indexOf('verification');
      final otherIdx = groupsInOrder.indexOf('other');

      expect(appIdx, lessThan(buildIdx));
      expect(buildIdx, lessThan(verifIdx));
      expect(verifIdx, lessThan(otherIdx));
    });

    test('parseGradleTasksOutput parses multi-module projects with prefixes (:app:xxx)', () {
      const output = '''
------------------------------------------------------------
Tasks runnable from project ':app'
------------------------------------------------------------

Build tasks
-----------
assembleDebug - Assembles all Debug builds.
assembleRelease - Assembles all Release builds.

Tasks runnable from project ':core'
------------------------------------------------------------

Build tasks
-----------
compileJava - Compiles Java sources.
''';

      final tasks = GradleProjectModule.parseGradleTasksOutput(output, 'sh ./gradlew');
      expect(tasks.length, 3);

      final assembleDebugTask = tasks.firstWhere((t) => t.name == ':app:assembleDebug');
      expect(assembleDebugTask.command, 'sh ./gradlew :app:assembleDebug');
      expect(assembleDebugTask.id, 'gradle__app_assembleDebug');
      expect(assembleDebugTask.group, 'build');
      expect(assembleDebugTask.moduleId, 'gradle');

      final compileJavaTask = tasks.firstWhere((t) => t.name == ':core:compileJava');
      expect(compileJavaTask.command, 'sh ./gradlew :core:compileJava');
      expect(compileJavaTask.id, 'gradle__core_compileJava');
    });
  });

  group('Gradle Module Cache & Storage Tests', () {
    late Directory tempDir;
    late RunTaskStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gradle_module_test_');
      storageService = RunTaskStorageService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveModuleTasks writes to .code_editor/gradle_tasks.json and loadModuleTasks reads it back', () async {
      final initial = await storageService.loadModuleTasks(tempDir.path, 'gradle');
      expect(initial.tasks, isEmpty);
      expect(initial.hash, isNull);

      const tasksToSave = [
        RunTask(
          id: 'gradle_assembleDebug',
          name: 'assembleDebug',
          command: 'sh ./gradlew assembleDebug',
          source: TaskSource.detected,
          group: 'build',
          moduleId: 'gradle',
          description: 'Build debug package',
        ),
        RunTask(
          id: 'gradle_run',
          name: 'run',
          command: 'sh ./gradlew run',
          source: TaskSource.detected,
          group: 'application',
          moduleId: 'gradle',
          description: 'Run project',
        ),
      ];

      await storageService.saveModuleTasks(
        projectRoot: tempDir.path,
        moduleName: 'gradle',
        tasks: tasksToSave,
        hash: 'test_hash_12345',
      );

      // 验证独立持久化文件存在：.code_editor/gradle_tasks.json
      final cacheFile = File('${tempDir.path}/.code_editor/gradle_tasks.json');
      expect(cacheFile.existsSync(), isTrue);

      // 读取并校验
      final loaded = await storageService.loadModuleTasks(tempDir.path, 'gradle');
      expect(loaded.hash, 'test_hash_12345');
      expect(loaded.tasks.length, 2);
      expect(loaded.tasks.first.name, 'assembleDebug');
      expect(loaded.tasks.first.group, 'build');
      expect(loaded.tasks.first.moduleId, 'gradle');
      expect(loaded.tasks.last.name, 'run');

      // 验证 run_tasks.json（用户任务）完全不受影响且相互隔离
      final userConfig = await storageService.loadConfig(tempDir.path);
      expect(userConfig.tasks, isEmpty);
    });

    test('computeBuildScriptHash changes when build.gradle is modified', () async {
      final buildGradle = File('${tempDir.path}/build.gradle');
      await buildGradle.writeAsString('plugins { id "java" }\n');

      final hash1 = GradleProjectModule.computeBuildScriptHash(tempDir);
      expect(hash1.isNotEmpty, isTrue);

      // 稍微休眠并修改内容
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await buildGradle.writeAsString('plugins { id "application" }\n');

      final hash2 = GradleProjectModule.computeBuildScriptHash(tempDir);
      expect(hash2, isNot(equals(hash1)));
    });
  });

  group('ProjectTaskDispatcher & RunProvider Modular Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dispatcher_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ProjectTaskDispatcher activates modules correctly', () async {
      final dispatcher = ProjectTaskDispatcher();

      // 空目录，不激活任何模块
      expect(dispatcher.getActiveModules(tempDir), isEmpty);

      // 写入 build.gradle
      await File('${tempDir.path}/build.gradle').writeAsString('// gradle build');
      final active = dispatcher.getActiveModules(tempDir);
      expect(active.length, 1);
      expect(active.first.id, 'gradle');

      // 再写入 CMakeLists.txt
      await File('${tempDir.path}/CMakeLists.txt').writeAsString('project(test)');
      final active2 = dispatcher.getActiveModules(tempDir);
      expect(active2.length, 2);
      expect(active2.any((m) => m.id == 'cmake'), isTrue);
      expect(active2.any((m) => m.id == 'gradle'), isTrue);
    });

    test('GradleProjectModule returns cached tasks when hash matches without executing command', () async {
      final buildGradle = File('${tempDir.path}/build.gradle');
      await buildGradle.writeAsString('plugins { id "java" }\n');

      final storageService = RunTaskStorageService();
      final currentHash = GradleProjectModule.computeBuildScriptHash(tempDir);

      const cachedTasks = [
        RunTask(
          id: 'gradle_cached_task',
          name: 'cachedTask',
          command: 'sh ./gradlew cachedTask',
          source: TaskSource.detected,
          group: 'build',
          moduleId: 'gradle',
        ),
      ];

      await storageService.saveModuleTasks(
        projectRoot: tempDir.path,
        moduleName: 'gradle',
        tasks: cachedTasks,
        hash: currentHash,
      );

      final dispatcher = ProjectTaskDispatcher();
      final tasks = await dispatcher.detect(
        projectRoot: tempDir.path,
        storageService: storageService,
      );

      expect(tasks.any((t) => t.id == 'gradle_cached_task'), isTrue);
      expect(tasks.firstWhere((t) => t.id == 'gradle_cached_task').name, 'cachedTask');
    });

    test('RunProvider integrates with modular task system and maintains customTasks', () async {
      final storageService = RunTaskStorageService();
      final runProvider = RunProvider(storageService: storageService);

      // 准备工程与一个已缓存的 Gradle 任务
      await File('${tempDir.path}/build.gradle').writeAsString('plugins { id "java" }\n');
      final currentHash = GradleProjectModule.computeBuildScriptHash(tempDir);
      const initialGradleTask = RunTask(
        id: 'gradle_assemble',
        name: 'assemble',
        command: 'sh ./gradlew assemble',
        source: TaskSource.detected,
        group: 'build',
        moduleId: 'gradle',
      );
      await storageService.saveModuleTasks(
        projectRoot: tempDir.path,
        moduleName: 'gradle',
        tasks: [initialGradleTask],
        hash: currentHash,
      );

      // 打开工程
      await runProvider.onProjectOpened(tempDir.path);
      expect(runProvider.detectedTasks.any((t) => t.id == 'gradle_assemble'), isTrue);

      // 添加用户自定义任务
      const customTask = RunTask(
        id: 'user_custom_1',
        name: 'My Custom Run',
        command: 'echo "custom"',
        source: TaskSource.custom,
      );
      await runProvider.addCustomTask(customTask);

      expect(runProvider.customTasks.length, 1);
      // allTasks 自定义置顶
      expect(runProvider.allTasks.first.id, 'user_custom_1');
      expect(runProvider.allTasks.any((t) => t.id == 'gradle_assemble'), isTrue);
    });
  });
}
