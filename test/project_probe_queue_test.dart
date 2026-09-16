import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/models/project_task_table.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/models/run_task_type.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/project_modules/project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';

/// 记录执行时序的假模块：用于验证"队列线性执行 + 三动作顺序"
class _FakeModule extends ProjectModule {
  @override
  final String id;
  final List<String> log;
  final List<RunTask> tasks;
  final bool probeFails;

  /// 首次依赖检测返回缺失，安装成功后复检返回空
  List<String> _pendingDependencies;
  final bool installSucceeds;
  final Duration probeDelay;

  /// 并发探针：probe 执行期间 +1，用于断言"线性执行、无重叠"
  final ValueNotifier<int> concurrency;

  _FakeModule({
    required this.id,
    required this.log,
    required this.concurrency,
    this.tasks = const [],
    this.probeFails = false,
    List<String> pendingDependencies = const [],
    this.installSucceeds = true,
    this.probeDelay = Duration.zero,
  }) : _pendingDependencies = pendingDependencies;

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<void> prepare(ProjectProbe probe) async {
    log.add('$id:prepare');
  }

  @override
  Future<List<String>> checkDependencies(ProjectProbe probe) async {
    log.add('$id:check');
    return _pendingDependencies;
  }

  @override
  Future<bool> installDependencies(ProjectProbe probe, List<String> missing) async {
    log.add('$id:install:${missing.join(",")}');
    if (installSucceeds) {
      _pendingDependencies = const [];
    }
    return installSucceeds;
  }

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    log.add('$id:probe');
    concurrency.value = concurrency.value + 1;
    // 同一时刻只允许一个模块处于探测中（队列线性执行的硬约束）
    expect(concurrency.value, 1, reason: '队列必须线性执行，不允许两个模块同时探测');
    if (probeDelay > Duration.zero) {
      await Future<void>.delayed(probeDelay);
    }
    concurrency.value = concurrency.value - 1;

    if (probeFails) {
      return ModuleProbeResult.failed(
        id,
        failure: NoticeFailure.executionFailed,
        detail: 'boom',
      );
    }
    return ModuleProbeResult.ok(id, tasks);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory projectDir;
  late Directory distroBaseDir;
  late DistroManager distroManager;
  const systemName = 'test_sys';

  setUp(() async {
    projectDir = await Directory.systemTemp.createTemp('probe_queue_project_');

    // 假系统：rootfs/{etc,bin,usr/bin/java}
    distroBaseDir = await Directory.systemTemp.createTemp('probe_queue_distro_');
    final rootfs = Directory(p.join(distroBaseDir.path, systemName, 'rootfs'));
    Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
    Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
    final usrBin = Directory(p.join(rootfs.path, 'usr', 'bin'))..createSync(recursive: true);
    File(p.join(usrBin.path, 'java')).writeAsStringSync('#!/bin/sh\n');
    distroManager = DistroManager()..customBaseDir = distroBaseDir;
  });

  tearDown(() async {
    DistroManager().customBaseDir = null;
    if (await projectDir.exists()) await projectDir.delete(recursive: true);
    if (await distroBaseDir.exists()) await distroBaseDir.delete(recursive: true);
  });

  RunTask task(String id, String moduleId) => RunTask(
        id: id,
        name: id,
        command: 'echo $id',
        source: TaskSource.detected,
        moduleId: moduleId,
      );

  group('探测队列：模块发现 → 入队 → 线性三动作', () {
    test('队列线性执行：按顺序串行、成功与失败都继续下一个', () async {
      final log = <String>[];
      final concurrency = ValueNotifier<int>(0);
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _FakeModule(
          id: 'gradle',
          log: log,
          concurrency: concurrency,
          tasks: [task('gradle_build', 'gradle')],
          probeDelay: const Duration(milliseconds: 20),
        ),
        _FakeModule(
          id: 'cmake',
          log: log,
          concurrency: concurrency,
          probeFails: true,
          probeDelay: const Duration(milliseconds: 20),
        ),
        _FakeModule(
          id: 'npm',
          log: log,
          concurrency: concurrency,
          tasks: [task('npm_start', 'npm')],
          probeDelay: const Duration(milliseconds: 20),
        ),
      ]);

      final emitted = <String>[];
      final probe = dispatcher.createProbe(
        projectRoot: projectDir.path,
        systemName: systemName,
        distroManager: distroManager,
      );
      final report = await dispatcher.run(
        probe,
        onModuleResult: (module, result) => emitted.add('${module.id}:${result.status.name}'),
      );
      probe.dispose();

      // 严格线性：a 全套 → b 全套 → c 全套
      expect(log, [
        'gradle:prepare', 'gradle:check', 'gradle:probe',
        'cmake:prepare', 'cmake:check', 'cmake:probe',
        'npm:prepare', 'npm:check', 'npm:probe',
      ]);
      expect(concurrency.value, 0);

      // 失败模块不影响后续模块执行，结果逐模块上抛
      expect(emitted, ['gradle:ok', 'cmake:failed', 'npm:ok']);
      expect(report.moduleResults['cmake']!.status, ModuleProbeStatus.failed);
      expect(report.detectedTasks.map((t) => t.id), containsAll(['gradle_build', 'npm_start']));
    });

    test('依赖检测 → 自动补全 → 复检 → 执行探测（顺序固定）', () async {
      final log = <String>[];
      final concurrency = ValueNotifier<int>(0);
      final module = _FakeModule(
        id: 'gradle',
        log: log,
        concurrency: concurrency,
        tasks: [task('gradle_build', 'gradle')],
        pendingDependencies: const ['gradle'],
      );
      final dispatcher = ProjectTaskDispatcher(customModules: [module]);

      final probe = dispatcher.createProbe(
        projectRoot: projectDir.path,
        systemName: systemName,
        distroManager: distroManager,
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      expect(log, [
        'gradle:prepare',
        'gradle:check',
        'gradle:install:gradle',
        'gradle:check',
        'gradle:probe',
      ]);
      expect(report.moduleResults['gradle']!.status, ModuleProbeStatus.ok);
    });

    test('依赖自动补全失败：该模块标记 dependencyInstallFailed，后续模块照常执行', () async {
      final log = <String>[];
      final concurrency = ValueNotifier<int>(0);
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _FakeModule(
          id: 'gradle',
          log: log,
          concurrency: concurrency,
          installSucceeds: false,
          pendingDependencies: const ['gradle'],
        ),
        _FakeModule(id: 'make', log: log, concurrency: concurrency, tasks: [task('make_default', 'make')]),
      ]);

      final probe = dispatcher.createProbe(
        projectRoot: projectDir.path,
        systemName: systemName,
        distroManager: distroManager,
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      final gradleResult = report.moduleResults['gradle']!;
      expect(gradleResult.status, ModuleProbeStatus.failed);
      expect(gradleResult.failure, NoticeFailure.dependencyInstallFailed);
      // 没有进入 probe 阶段
      expect(log.contains('gradle:probe'), isFalse);
      // 后续模块照常完成
      expect(report.moduleResults['make']!.status, ModuleProbeStatus.ok);
      expect(log.contains('make:probe'), isTrue);
    });

    test('无可用系统时不入队、不探测、也不创建任何目录', () async {
      final emptyBase = await Directory.systemTemp.createTemp('probe_queue_empty_');
      addTearDown(() async {
        if (await emptyBase.exists()) await emptyBase.delete(recursive: true);
      });
      DistroManager().customBaseDir = emptyBase;

      final log = <String>[];
      final concurrency = ValueNotifier<int>(0);
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _FakeModule(id: 'gradle', log: log, concurrency: concurrency),
      ]);

      final probe = dispatcher.createProbe(
        projectRoot: projectDir.path,
        systemName: 'ubuntu',
        distroManager: DistroManager(),
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      expect(report.detectedTasks, isEmpty);
      expect(log, isEmpty);
      expect(Directory(p.join(emptyBase.path, 'ubuntu')).existsSync(), isFalse);
    });
  });

  group('任务类型表（类型 → 任务数组）', () {
    test('RunTaskType.ofTask 映射：模块任务 / 单文件 / 用户任务', () {
      expect(RunTaskType.ofTask(task('gradle_build', 'gradle')), RunTaskType.gradle);
      expect(RunTaskType.ofTask(task('cmake_build', 'cmake')), RunTaskType.cmake);
      expect(
        RunTaskType.ofTask(const RunTask(
          id: 'detected_single_python',
          name: 'py',
          command: 'python3 x.py',
          source: TaskSource.detected,
          group: 'single_file',
        )),
        RunTaskType.singleFile,
      );
      expect(
        RunTaskType.ofTask(const RunTask(
          id: 'user_1',
          name: 'custom',
          command: 'echo',
          source: TaskSource.custom,
        )),
        RunTaskType.user,
      );
    });

    test('模块只写入自己类型那一格，用户任务固定在最后', () {
      final table = ProjectTaskTable();
      table.replaceType(RunTaskType.gradle, [task('gradle_build', 'gradle')]);
      table.replaceType(RunTaskType.npm, [task('npm_start', 'npm')]);
      table.setUserTasks([
        const RunTask(id: 'user_1', name: 'custom', command: 'echo', source: TaskSource.custom),
      ]);

      expect(table.tasksOf(RunTaskType.gradle), hasLength(1));
      expect(table.tasksOf(RunTaskType.cmake), isEmpty);
      expect(table.nonEmptyTypes, [RunTaskType.gradle, RunTaskType.npm, RunTaskType.user]);
      expect(RunTaskType.ofTask(table.allOrdered.last), RunTaskType.user);
      expect(table.detectedTasks.any((t) => t.source == TaskSource.custom), isFalse);

      // 覆盖写入（重新同步）不会残留旧任务
      table.replaceType(RunTaskType.gradle, [task('gradle_test', 'gradle')]);
      expect(table.tasksOf(RunTaskType.gradle).map((t) => t.id), ['gradle_test']);
    });
  });
}
