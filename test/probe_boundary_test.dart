import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/models/run_task_type.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/project_modules/project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';
import 'package:code_editor/services/run_task_storage_service.dart';
import 'package:code_editor/widgets/notice_host.dart';

import 'package:flutter/material.dart';

/// 可控制时长的模块：用于制造"探测进行中"与"迟到的结果"
class _ControllableModule extends ProjectModule {
  @override
  final String id;
  @override
  final String displayName;
  final List<RunTask> tasks;
  final Duration delay;

  _ControllableModule(this.id, this.tasks, {String? displayName, this.delay = Duration.zero})
      : displayName = displayName ?? id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    // 迟到的结果：模拟探测期间被取消
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    return ModuleProbeResult.ok(id, tasks);
  }
}

/// 用闸门控制返回时机的模块（key = 工程目录路径），用于制造"迟到的探测结果"
class _GatedModule extends ProjectModule {
  @override
  final String id;

  _GatedModule(this.id);

  final Map<String, Completer<void>> _gates = {};

  Completer<void> gateFor(String projectDirPath) =>
      _gates.putIfAbsent(projectDirPath, () => Completer<void>());

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    final gate = _gates[probe.projectDir.path];
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    // 故意不检查 isCancelled：由 RunProvider 的结果守卫负责丢弃迟到结果
    return ModuleProbeResult.ok(id, [
      RunTask(
        id: 'gradle_from_${p.basename(probe.projectDir.path)}',
        name: 'assemble',
        command: 'sh ./gradlew assemble',
        source: TaskSource.detected,
        moduleId: id,
      ),
    ]);
  }
}

/// 可注入耗时与依赖状态的模块：用于验证时间预算检查点
class _BudgetModule extends ProjectModule {
  @override
  final String id;
  final List<String> log;
  final Duration probeDelay;
  final Duration depsDelay;
  final List<String> missingDependencies;

  _BudgetModule(
    this.id, {
    required this.log,
    this.probeDelay = Duration.zero,
    this.depsDelay = Duration.zero,
    this.missingDependencies = const [],
  });

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<List<String>> checkDependencies(ProjectProbe probe) async {
    if (depsDelay > Duration.zero) {
      await Future<void>.delayed(depsDelay);
    }
    return missingDependencies;
  }

  @override
  Future<bool> installDependencies(ProjectProbe probe, List<String> missing) async {
    log.add('$id:install');
    return true;
  }

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    log.add('$id:probe');
    if (probeDelay > Duration.zero) {
      await Future<void>.delayed(probeDelay);
    }
    return ModuleProbeResult.ok(id, [
      RunTask(
        id: '${id}_task',
        name: id,
        command: 'echo $id',
        source: TaskSource.detected,
        moduleId: id,
      ),
    ]);
  }
}

/// 固定失败的模块（用于验证失败卡片不被后续进度覆盖）
class _FailingModule extends ProjectModule {
  @override
  final String id;

  _FailingModule(this.id);

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async => ModuleProbeResult.failed(
        id,
        failure: NoticeFailure.executionFailed,
        detail: 'boom',
      );
}

/// 触发条件依赖特征文件的模块（用于验证"空工程不激活任何模块"）
class _TriggeredModule extends ProjectModule {
  @override
  final String id;
  final List<String> log;

  _TriggeredModule(this.id, {required this.log});

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const ['build.gradle'];

  @override
  bool shouldActivate(Directory projectDir) =>
      File(p.join(projectDir.path, 'build.gradle')).existsSync();

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    log.add('$id:probe');
    return ModuleProbeResult.ok(id, const []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const systemName = 'test_sys';
  late Directory projectA;
  late Directory projectB;
  late Directory distroBaseDir;
  late DistroManager distroManager;

  setUp(() async {
    projectA = await Directory.systemTemp.createTemp('probe_a_');
    projectB = await Directory.systemTemp.createTemp('probe_b_');
    distroBaseDir = await Directory.systemTemp.createTemp('probe_boundary_distro_');
    final rootfs = Directory(p.join(distroBaseDir.path, systemName, 'rootfs'));
    Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
    Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
    distroManager = DistroManager()..customBaseDir = distroBaseDir;
  });

  tearDown(() async {
    DistroManager().customBaseDir = null;
    for (final dir in [projectA, projectB, distroBaseDir]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  RunTask task(String id, String moduleId) => RunTask(
        id: id,
        name: id,
        command: 'echo $id',
        source: TaskSource.detected,
        moduleId: moduleId,
      );

  group('探测系统边界', () {
    test('切换工程：上一个工程迟到的模块结果不得写入新工程的内存表', () async {
      final storage = RunTaskStorageService();
      // 用闸门控制每个工程（目录）的模块返回时机
      final module = _GatedModule('gradle');
      final dispatcher = ProjectTaskDispatcher(customModules: [module]);
      final provider = RunProvider(
        storageService: storage,
        dispatcher: dispatcher,
        distroManager: distroManager,
      );

      // 工程 A 的模块卡在闸门上（模拟长耗时探测）
      final gateA = module.gateFor(projectA.path);
      // 工程 B 的模块立即放行
      module.gateFor(projectB.path).complete();

      final probeA = provider.probeProject(projectRoot: projectA.path, systemName: systemName);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(provider.isDetecting, isTrue);

      // 期间切到工程 B：同一 provider 会取消 A 的探测并重新探测
      final probeB = provider.probeProject(projectRoot: projectB.path, systemName: systemName);
      await probeB;
      expect(provider.currentProjectRoot, projectB.path);
      expect(
        provider.taskTable.tasksOf(RunTaskType.gradle).map((t) => t.id).toList(),
        ['gradle_from_${p.basename(projectB.path)}'],
      );

      // A 的模块这时才返回（迟到结果）：绝不能覆盖/污染当前工程的内存表
      gateA.complete();
      await probeA;
      expect(
        provider.taskTable.tasksOf(RunTaskType.gradle).map((t) => t.id).toList(),
        ['gradle_from_${p.basename(projectB.path)}'],
        reason: '被取消/被取代的探测结果必须丢弃',
      );
    });

    test('单文件任务写入 singleFile 格，且随当前打开文件本地刷新', () async {
      final storage = RunTaskStorageService();
      final pyFile = File(p.join(projectA.path, 'main.py'))..writeAsStringSync('print(1)');
      final cppFile = File(p.join(projectA.path, 'main.cpp'))..writeAsStringSync('int main(){}');

      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );

      await provider.probeProject(
        projectRoot: projectA.path,
        currentFilePath: pyFile.path,
        systemName: systemName,
      );
      expect(
        provider.taskTable.tasksOf(RunTaskType.singleFile).map((t) => t.id),
        ['detected_single_python'],
      );

      // 切换打开的文件 -> 本地重算（不跑容器）
      provider.refreshSingleFileTask(currentFilePath: cppFile.path);
      expect(
        provider.taskTable.tasksOf(RunTaskType.singleFile).map((t) => t.id),
        ['detected_single_cpp'],
      );

      // 切到无对应运行方式的文件 -> 该格清空
      final txtFile = File(p.join(projectA.path, 'notes.txt'))..writeAsStringSync('hi');
      provider.refreshSingleFileTask(currentFilePath: txtFile.path);
      expect(provider.taskTable.tasksOf(RunTaskType.singleFile), isEmpty);
    });

    test('未映射到内置类型的自定义模块：任务归入 other，不能丢', () async {
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          _ControllableModule('maven', [task('maven_package', 'maven')]),
        ]),
        distroManager: distroManager,
      );

      await provider.probeProject(projectRoot: projectA.path, systemName: systemName);

      expect(provider.taskTable.tasksOf(RunTaskType.other).map((t) => t.id), ['maven_package']);
      expect(provider.detectedTasks.any((t) => t.id == 'maven_package'), isTrue);
      expect(RunTaskType.ofTask(task('maven_package', 'maven')), RunTaskType.other);
    });

    test('探测进行中被 dispose：取消会话且不再抛"释放后通知"异常', () async {
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          _ControllableModule('gradle', [task('gradle_x', 'gradle')],
              delay: const Duration(milliseconds: 80)),
        ]),
        distroManager: distroManager,
      );

      final running = provider.probeProject(projectRoot: projectA.path, systemName: systemName);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      provider.dispose();

      // 不抛异常（ChangeNotifier 释放后调用 notifyListeners 会抛）
      await running;
      expect(provider.isDetecting, isFalse);
    });

    test('空项目（无任何构建特征文件）：不启动模块探测，但用户探测与单文件任务照常', () async {
      // 空工程：不放任何构建文件，只放一个可运行的源文件
      final pyFile = File(p.join(projectA.path, 'main.py'))..writeAsStringSync('print(1)');
      final storage = RunTaskStorageService();
      await storage.saveConfig(projectRoot: projectA.path, tasks: [
        const RunTask(id: 'user_1', name: 'u', command: 'echo', source: TaskSource.custom),
      ]);

      final log = <String>[];
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          // 触发条件为"必须有 build.gradle"的模块：空工程下不应被激活
          _TriggeredModule('gradle', log: log),
        ]),
        distroManager: distroManager,
      );

      await provider.probeProject(
        projectRoot: projectA.path,
        currentFilePath: pyFile.path,
        systemName: systemName,
      );

      // 没有模块被激活 -> 一次探测都没跑
      expect(log, isEmpty);
      expect(provider.lastProbeReport?.totalModules, 0);
      expect(provider.detectedTasks.where((t) => t.moduleId != null), isEmpty);
      // 用户任务照常（来自磁盘）
      expect(provider.customTasks.map((t) => t.id), ['user_1']);
      // 单文件任务照常（本地计算，不依赖任何模块）
      expect(provider.taskTable.tasksOf(RunTaskType.singleFile).map((t) => t.id),
          ['detected_single_python']);
    });

    test('工程外的文件不产出单文件任务（容器内不存在该文件）', () async {
      final outsideDir = await Directory.systemTemp.createTemp('probe_outside_');
      addTearDown(() async {
        if (await outsideDir.exists()) await outsideDir.delete(recursive: true);
      });
      final outsidePy = File(p.join(outsideDir.path, 'main.py'))..writeAsStringSync('print(1)');

      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );

      await provider.probeProject(
        projectRoot: projectA.path,
        currentFilePath: outsidePy.path,
        systemName: systemName,
      );

      expect(provider.taskTable.tasksOf(RunTaskType.singleFile), isEmpty);
      expect(ProjectTaskDispatcher.detectSingleFileTask(projectA.path, outsidePy.path), isNull);
    });

    test('关闭工程：清空内存并终止进行中的探测', () async {
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          _ControllableModule('gradle', [task('gradle_x', 'gradle')],
              delay: const Duration(milliseconds: 60)),
        ]),
        distroManager: distroManager,
      );

      final running = provider.probeProject(projectRoot: projectA.path, systemName: systemName);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.isDetecting, isTrue);

      provider.onProjectClosed();
      expect(provider.currentProjectRoot, isNull);
      expect(provider.taskTable.isEmpty, isTrue);

      await running;
      expect(provider.taskTable.isEmpty, isTrue, reason: '关闭工程后迟到的结果不得回填');
    });
  });

  group('用户任务与"上一次执行任务"的加载边界', () {
    test('进入项目必定加载用户任务；无可用系统时也照常加载', () async {
      final storage = RunTaskStorageService();
      await storage.saveConfig(projectRoot: projectA.path, tasks: [
        const RunTask(id: 'user_a', name: 'a', command: 'echo a', source: TaskSource.custom),
        const RunTask(id: 'user_b', name: 'b', command: 'echo b', source: TaskSource.custom),
      ], lastRunTaskId: 'user_b');

      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );

      // 没有可用系统（systemName = null）：系统探测会跳过，但用户任务必须加载
      await provider.probeProject(projectRoot: projectA.path, systemName: null);

      expect(provider.customTasks.map((t) => t.id), ['user_a', 'user_b']);
      expect(provider.lastRunTask?.id, 'user_b');
    });

    test('未进入项目时用户探测是空操作（没有工程根就不加载）', () async {
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );

      await provider.probeUser();
      expect(provider.customTasks, isEmpty);
      expect(provider.currentProjectRoot, isNull);
    });

    test('run_tasks.json 损坏：加载为空但不抛异常（磁盘文件保持原样）', () async {
      final storage = RunTaskStorageService();
      final configFile = storage.getConfigFile(projectA.path);
      configFile.parent.createSync(recursive: true);
      configFile.writeAsStringSync('{ this is not json ]');

      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );

      await provider.probeProject(projectRoot: projectA.path, systemName: null);
      expect(provider.customTasks, isEmpty);
      // 坏文件不被覆盖（用户仍可手工修复）
      expect(configFile.existsSync(), isTrue);
      expect(configFile.readAsStringSync(), contains('not json'));
    });

    test('刚打开工程就记录"上次执行任务"：不得清空磁盘上已有的用户任务', () async {
      final storage = RunTaskStorageService();
      await storage.saveConfig(projectRoot: projectA.path, tasks: [
        const RunTask(id: 'user_a', name: 'a', command: 'echo a', source: TaskSource.custom),
        const RunTask(id: 'user_b', name: 'b', command: 'echo b', source: TaskSource.custom),
      ]);

      // 全新 provider：内存里还没有任何用户任务
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );
      provider.onProjectOpened(projectA.path, systemName: null); // 不等待加载
      await provider.setLastRunTask(
        const RunTask(id: 'user_a', name: 'a', command: 'echo a', source: TaskSource.custom),
      );

      // 磁盘上两个任务都必须还在，只是 lastRunTaskId 被更新
      final persisted = await storage.loadConfig(projectA.path);
      expect(persisted.tasks.map((t) => t.id), containsAll(['user_a', 'user_b']));
      expect(persisted.lastRunTaskId, 'user_a');
    });

    test('内存尚未加载完时添加用户任务：以磁盘为基准，不丢已有任务', () async {
      final storage = RunTaskStorageService();
      await storage.saveConfig(projectRoot: projectA.path, tasks: [
        const RunTask(id: 'user_a', name: 'a', command: 'echo a', source: TaskSource.custom),
      ]);

      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: const []),
        distroManager: distroManager,
      );
      // 只绑定工程根，不等用户探测完成
      provider.onProjectOpened(projectA.path, systemName: null);
      await provider.addCustomTask(
        const RunTask(id: 'user_new', name: 'n', command: 'echo n', source: TaskSource.custom),
      );

      final persisted = await storage.loadConfig(projectA.path);
      expect(persisted.tasks.map((t) => t.id), containsAll(['user_a', 'user_new']));
    });
  });

  group('通知文案顺序（Gradle 为例）', () {
    test('失败卡片不会被后续队列进度覆盖（失败原因保留、不再二次确认）', () async {
      final center = NoticeCenter();
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          // gradle 立刻失败，npm 稍慢 -> 期间会持续上报队列进度
          _FailingModule('gradle'),
          _BudgetModule('npm', log: [], probeDelay: const Duration(milliseconds: 60)),
        ]),
        distroManager: distroManager,
        noticeCenter: center,
      );

      await provider.probeProject(projectRoot: projectA.path, systemName: systemName);

      final gradleNotice = center.visible.firstWhere((n) => n.id == 'probe:gradle');
      expect(gradleNotice.kind, NoticeKind.failure);
      final text = gradleNotice.text as ModuleFailureText;
      expect(text.moduleDisplayName, 'gradle');
      expect(text.failure, NoticeFailure.executionFailed);
      expect(gradleNotice.confirmBeforeDismiss, isFalse,
          reason: '模块已结束，关闭失败卡片不再是破坏性操作');
    });

    test('成功卡片不会被后续队列进度回写为"排队等待中"', () async {
      final center = NoticeCenter();
      final storage = RunTaskStorageService();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          _BudgetModule('gradle', log: []),
          _BudgetModule('npm', log: [], probeDelay: const Duration(milliseconds: 80)),
        ]),
        distroManager: distroManager,
        noticeCenter: center,
      );

      // 不 await：在 npm 还在跑的时候检查 gradle 的卡片
      final running = provider.probeProject(projectRoot: projectA.path, systemName: systemName);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final gradleNotice = center.visible.firstWhere((n) => n.id == 'probe:gradle');
      expect(gradleNotice.kind, NoticeKind.success);
      expect(gradleNotice.text, isA<ModuleDoneText>());

      await running;
    });
  });

  group('探测时间预算', () {
    test('模块之间超预算：剩余模块标记 skippedByBudget，且不再执行探测', () async {
      final log = <String>[];
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _BudgetModule('gradle', log: log, probeDelay: const Duration(milliseconds: 40)),
        _BudgetModule('npm', log: log),
        _BudgetModule('make', log: log),
      ]);

      final probe = dispatcher.createProbe(
        projectRoot: projectA.path,
        systemName: systemName,
        distroManager: distroManager,
        budget: const Duration(milliseconds: 15),
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      expect(report.abortedByBudget, isTrue);
      expect(report.totalModules, 3);
      expect(report.completedModules, 1);
      expect(report.moduleResults['gradle']!.status, ModuleProbeStatus.ok);
      expect(report.moduleResults['npm']!.status, ModuleProbeStatus.skippedByBudget);
      expect(report.moduleResults['make']!.status, ModuleProbeStatus.skippedByBudget);
      // 后两个模块连探测都没开始
      expect(log, ['gradle:probe']);
    });

    test('预算充足：正常跑完全部模块', () async {
      final log = <String>[];
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _BudgetModule('gradle', log: log),
        _BudgetModule('npm', log: log),
      ]);

      final probe = dispatcher.createProbe(
        projectRoot: projectA.path,
        systemName: systemName,
        distroManager: distroManager,
        budget: const Duration(seconds: 30),
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      expect(report.abortedByBudget, isFalse);
      expect(report.completedModules, 2);
      expect(log, ['gradle:probe', 'npm:probe']);
    });

    test('依赖安装前超预算：跳过安装（避免半装状态），模块标记 skippedByBudget', () async {
      final log = <String>[];
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _BudgetModule(
          'gradle',
          log: log,
          depsDelay: const Duration(milliseconds: 40),
          missingDependencies: const ['gradle'],
        ),
      ]);

      final probe = dispatcher.createProbe(
        projectRoot: projectA.path,
        systemName: systemName,
        distroManager: distroManager,
        budget: const Duration(milliseconds: 15),
      );
      final report = await dispatcher.run(probe);
      probe.dispose();

      expect(report.abortedByBudget, isTrue);
      expect(report.moduleResults['gradle']!.status, ModuleProbeStatus.skippedByBudget);
      expect(log.contains('gradle:install'), isFalse,
          reason: '预算将尽时不得开跑可能长达 10 分钟的安装');
      expect(log.contains('gradle:probe'), isFalse);
    });

    test('RunProvider：预算中止后弹出可关闭的"已中止"通知（× 仍可用）', () async {
      final storage = RunTaskStorageService();
      final center = NoticeCenter();
      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [
          _BudgetModule('gradle', log: [], probeDelay: const Duration(milliseconds: 40)),
          _BudgetModule('npm', log: []),
        ]),
        distroManager: distroManager,
        noticeCenter: center,
        probeBudget: const Duration(milliseconds: 15),
      );

      await provider.probeProject(projectRoot: projectA.path, systemName: systemName);

      final budgetNotice = center.visible.firstWhere((n) => n.id == 'probe:budget');
      expect(budgetNotice.sticky, isTrue);
      expect(budgetNotice.text, isA<ProbeBudgetExceededText>());
      final text = budgetNotice.text as ProbeBudgetExceededText;
      expect(text.completed, 1);
      expect(text.total, 2);

      // × 仍然可以关闭它（保留 x）
      center.dismiss('probe:budget');
      center.finalizeDismiss('probe:budget');
      expect(center.visible.any((n) => n.id == 'probe:budget'), isFalse);
    });
  });

  group('通知 × 的附加动作', () {
    testWidgets('点击进行中通知的 × 会触发 onUserDismiss（用于取消探测）', (tester) async {
      final center = NoticeCenter();
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(children: [
              Positioned.fill(child: NoticeHost(center: center)),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      center.push(NoticeItem(
        id: 'probe:gradle',
        kind: NoticeKind.progress,
        text: const ModulePhaseText(
          moduleDisplayName: 'Gradle',
          phase: ProbeNoticePhase.detecting,
        ),
        onUserDismiss: () => cancelled = true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(cancelled, isTrue, reason: '× 应触发附加动作');

      await tester.pump(const Duration(milliseconds: 400));
      expect(center.visible, isEmpty);
    });
  });
}
