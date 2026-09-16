import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/models/run_task_type.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/project_modules/project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';

/// 单测用假系统名：探测必须基于"真实可用系统"，单测用假 rootfs 代替真容器
const String kTestSystemName = 'test_sys';

/// 固定返回一组任务的假模块（用于验证类型表写入 / RunProvider 集成）
class _StubGradleModule extends ProjectModule {
  @override
  String get id => 'gradle';

  @override
  String get displayName => 'Gradle';

  @override
  List<String> get triggerFiles => const ['build.gradle'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'build.gradle')).existsSync();

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async => ModuleProbeResult.ok(id, [
        const RunTask(
          id: 'gradle_assemble',
          name: 'assemble',
          command: 'sh ./gradlew assemble',
          source: TaskSource.detected,
          moduleId: 'gradle',
          group: 'build',
        ),
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectTaskDispatcher & RunProvider Modular Tests', () {
    late Directory tempDir;
    late Directory distroBaseDir;
    late DistroManager distroManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dispatcher_test_');

      // 假系统：rootfs/{etc,bin,usr/bin/java}（依赖检测走宿主 rootfs 快速判定）
      distroBaseDir = await Directory.systemTemp.createTemp('dispatcher_distro_');
      final rootfs = Directory(p.join(distroBaseDir.path, kTestSystemName, 'rootfs'));
      Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
      Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
      final usrBin = Directory(p.join(rootfs.path, 'usr', 'bin'))..createSync(recursive: true);
      File(p.join(usrBin.path, 'java')).writeAsStringSync('#!/bin/sh\n');
      distroManager = DistroManager()..customBaseDir = distroBaseDir;
    });

    tearDown(() async {
      DistroManager().customBaseDir = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await distroBaseDir.exists()) {
        await distroBaseDir.delete(recursive: true);
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

    test('未安装指定系统时既不探测，也绝不创建任何系统目录', () async {
      final emptyBase = await Directory.systemTemp.createTemp('dispatcher_no_sys_');
      addTearDown(() async {
        if (await emptyBase.exists()) await emptyBase.delete(recursive: true);
      });
      DistroManager().customBaseDir = emptyBase;

      await File('${tempDir.path}/build.gradle').writeAsString('plugins { id "java" }\n');

      final tasks = await ProjectTaskDispatcher().detect(
        projectRoot: tempDir.path,
        systemName: 'ubuntu',
        distroManager: DistroManager(),
      );

      expect(tasks, isEmpty);
      // 绝不能凭空造出 distros/ubuntu（历史缺陷会在这里 recursive 创建 rootfs/etc）
      expect(Directory(p.join(emptyBase.path, 'ubuntu')).existsSync(), isFalse);
    });

    test('未传入系统名时不做任何探测（连纯静态模块任务也不产出）', () async {
      await File('${tempDir.path}/Makefile').writeAsString('all:\n\tgcc main.c\n');
      await File('${tempDir.path}/build.gradle').writeAsString('plugins { id "java" }\n');

      final tasks = await ProjectTaskDispatcher().detect(
        projectRoot: tempDir.path,
        distroManager: distroManager,
      );

      expect(tasks, isEmpty);
    });

    test('真实自省失败时返回空结果：不产出任何兜底任务', () async {
      await File('${tempDir.path}/build.gradle').writeAsString('plugins { id "java" }\n');

      final tasks = await ProjectTaskDispatcher().detect(
        projectRoot: tempDir.path,
        systemName: kTestSystemName,
        distroManager: distroManager,
      );

      // 测试环境无法真正执行 gradle -> 该模块失败且不产出任务（也绝无 detected_gradle_* 兜底）
      expect(tasks.where((t) => t.moduleId == 'gradle'), isEmpty);
      expect(tasks.any((t) => t.id.startsWith('detected_gradle_')), isFalse);
    });

    test('RunProvider 集成：模块结果写入"类型 → 任务数组"的对应格子', () async {
      await File('${tempDir.path}/build.gradle').writeAsString('plugins { id "java" }\n');

      final dispatcher = ProjectTaskDispatcher(customModules: [_StubGradleModule()]);
      final runProvider = RunProvider(
        dispatcher: dispatcher,
        distroManager: distroManager,
      );

      await runProvider.onProjectOpened(tempDir.path, systemName: kTestSystemName);

      expect(runProvider.taskTable.tasksOf(RunTaskType.gradle).map((t) => t.id), ['gradle_assemble']);
      expect(runProvider.detectedTasks.any((t) => t.id == 'gradle_assemble'), isTrue);
      expect(runProvider.taskTable.tasksOf(RunTaskType.user), isEmpty);
    });
  });
}
