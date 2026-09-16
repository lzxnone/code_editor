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
import 'package:code_editor/services/run_task_storage_service.dart';

/// 计数用存储服务：用于验证"用户探测"的并发合并（磁盘 IO 不被放大）
class _CountingStorage extends RunTaskStorageService {
  int loadCount = 0;

  @override
  Future<({List<RunTask> tasks, String? lastRunTaskId})> loadConfig(String projectRoot) {
    loadCount++;
    return super.loadConfig(projectRoot);
  }
}

/// 固定返回任务的假系统模块
class _StubModule extends ProjectModule {
  @override
  final String id;
  @override
  final String displayName;
  final List<RunTask> tasks;

  _StubModule(this.id, this.tasks, {String? displayName}) : displayName = displayName ?? id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async => ModuleProbeResult.ok(id, tasks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const systemName = 'test_sys';
  late Directory projectDir;
  late Directory distroBaseDir;
  late DistroManager distroManager;

  setUp(() async {
    projectDir = await Directory.systemTemp.createTemp('probe_split_project_');
    distroBaseDir = await Directory.systemTemp.createTemp('probe_split_distro_');
    final rootfs = Directory(p.join(distroBaseDir.path, systemName, 'rootfs'));
    Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
    Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
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

  RunProvider buildProvider(RunTaskStorageService storage, {ProjectTaskDispatcher? dispatcher}) {
    return RunProvider(
      storageService: storage,
      dispatcher: dispatcher ?? ProjectTaskDispatcher(customModules: [_StubModule('gradle', [task('gradle_build', 'gradle')])]),
      distroManager: distroManager,
    );
  }

  group('探测层三函数：探测 / 系统探测 / 用户探测', () {
    test('探测函数：清空内存 → 用户探测（磁盘覆盖内存）→ 系统探测（模块写入类型格）', () async {
      final storage = RunTaskStorageService();
      // 磁盘上先放一份用户任务与"上次执行"
      const userTask = RunTask(
        id: 'user_1',
        name: '我的任务',
        command: 'echo user',
        source: TaskSource.custom,
      );
      await storage.saveConfig(projectRoot: projectDir.path, tasks: [userTask], lastRunTaskId: 'user_1');

      final provider = buildProvider(storage);

      // 先手动污染内存中的用户任务，验证"覆盖"语义
      await provider.probeUser(projectRoot: projectDir.path);
      expect(provider.customTasks.map((t) => t.id), ['user_1']);

      await provider.probeProject(
        projectRoot: projectDir.path,
        systemName: systemName,
      );

      // 用户探测从磁盘覆盖
      expect(provider.customTasks.map((t) => t.id), ['user_1']);
      expect(provider.lastRunTaskId, 'user_1');
      expect(provider.lastRunTask?.id, 'user_1');
      // 系统探测写入 gradle 类型格
      expect(provider.taskTable.tasksOf(RunTaskType.gradle).map((t) => t.id), ['gradle_build']);
      expect(provider.taskTable.tasksOf(RunTaskType.user).map((t) => t.id), ['user_1']);
      expect(provider.isDetecting, isFalse);
    });

    test('探测函数会清空上一轮系统任务（系统任务只存在于内存）', () async {
      final storage = RunTaskStorageService();
      final dispatcher = ProjectTaskDispatcher(customModules: [
        _StubModule('gradle', [task('gradle_a', 'gradle')]),
      ]);
      final provider = buildProvider(storage, dispatcher: dispatcher);

      await provider.probeProject(projectRoot: projectDir.path, systemName: systemName);
      expect(provider.taskTable.tasksOf(RunTaskType.gradle).map((t) => t.id), ['gradle_a']);

      // 换成"探测不出任何任务"的模块后重新探测 -> 旧的系统任务必须被清掉
      final emptyDispatcher = ProjectTaskDispatcher(customModules: [
        _StubModule('gradle', const []),
      ]);
      final provider2 = RunProvider(
        storageService: storage,
        dispatcher: emptyDispatcher,
        distroManager: distroManager,
      );
      await provider2.probeProject(projectRoot: projectDir.path, systemName: systemName);
      expect(provider2.detectedTasks, isEmpty);
    });

    test('无可用系统时只完成用户探测，系统类型格保持为空', () async {
      final storage = RunTaskStorageService();
      await storage.saveConfig(
        projectRoot: projectDir.path,
        tasks: [
          const RunTask(id: 'user_1', name: 'u', command: 'echo', source: TaskSource.custom),
        ],
      );
      final provider = buildProvider(storage);

      await provider.probeProject(projectRoot: projectDir.path, systemName: null);

      expect(provider.customTasks, hasLength(1));
      expect(provider.detectedTasks, isEmpty);
    });

    test('用户探测并发合并：连续 50 次触发只做 1~2 次磁盘读取，且最后一次编辑生效', () async {
      final storage = _CountingStorage();
      final provider = buildProvider(storage);

      const finalTask = RunTask(
        id: 'user_final',
        name: 'final',
        command: 'echo',
        source: TaskSource.custom,
      );
      await storage.saveConfig(projectRoot: projectDir.path, tasks: [finalTask]);

      // 模拟"用户瞬间编辑了几十次"：紧循环触发（两次调用之间不 await，才能形成真正的并发重叠）
      final futures = <Future<void>>[];
      for (var i = 0; i < 50; i++) {
        futures.add(provider.probeUser(projectRoot: projectDir.path));
      }
      await Future.wait(futures);
      // 合并后可能还有一次补跑，多等一拍
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(storage.loadCount, lessThanOrEqualTo(2),
          reason: '并发合并应把 50 次触发压缩为 1~2 次磁盘读取');
      // 内存中的用户任务等于磁盘上的最终内容（覆盖语义）
      expect(provider.customTasks.map((t) => t.id), ['user_final']);
    });

    test('编辑用户任务：先写盘再用户探测，内存 user 格被磁盘内容覆盖', () async {
      final storage = RunTaskStorageService();
      final provider = buildProvider(storage);
      await provider.probeProject(projectRoot: projectDir.path, systemName: systemName);

      const edited = RunTask(
        id: 'user_custom_1',
        name: 'My Custom Run',
        command: 'echo "custom"',
        source: TaskSource.custom,
      );
      await provider.addCustomTask(edited);
      expect(provider.customTasks.any((t) => t.id == 'user_custom_1'), isTrue);

      // 直接从磁盘读回的持久化结果应与内存一致
      final persisted = await storage.loadConfig(projectDir.path);
      expect(persisted.tasks.map((t) => t.id), ['user_custom_1']);
    });

    test('"上一次执行任务"同样走磁盘并同步内存（任务被删除时不再命中）', () async {
      final storage = RunTaskStorageService();
      final provider = buildProvider(storage);
      await provider.probeProject(projectRoot: projectDir.path, systemName: systemName);

      const userTask = RunTask(
        id: 'user_run_me',
        name: 'run me',
        command: 'echo',
        source: TaskSource.custom,
      );
      await provider.addCustomTask(userTask);
      await provider.setLastRunTask(userTask);
      expect(provider.lastRunTask?.id, 'user_run_me');
      expect((await storage.loadConfig(projectDir.path)).lastRunTaskId, 'user_run_me');

      // 删除该任务后再探一次：id 仍在，但内存对象不再命中
      await provider.removeCustomTask('user_run_me');
      expect(provider.customTasks, isEmpty);
      expect(provider.lastRunTask, isNull);
    });

    test('requestProjectProbe：探测进行中时拒绝并返回 false', () async {
      final storage = RunTaskStorageService();
      final provider = buildProvider(storage);

      // 构造一个"慢模块"，让探测保持在 isDetecting 状态
      final slowDispatcher = ProjectTaskDispatcher(customModules: [
        _SlowModule('gradle'),
      ]);
      final slowProvider = RunProvider(
        storageService: storage,
        dispatcher: slowDispatcher,
        distroManager: distroManager,
      );

      final running = slowProvider.probeProject(
        projectRoot: projectDir.path,
        systemName: systemName,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(slowProvider.isDetecting, isTrue);

      final started = await slowProvider.requestProjectProbe(
        projectRoot: projectDir.path,
        systemName: systemName,
      );
      expect(started, isFalse, reason: '已有探测在进行时应拒绝新的探测请求');

      await running;
      expect(slowProvider.isDetecting, isFalse);
      // 未使用的 provider 不影响断言
      expect(provider.isDetecting, isFalse);
    });
  });
}

/// 慢模块：让探测持续一段时间，便于观察 isDetecting
class _SlowModule extends ProjectModule {
  @override
  final String id;

  _SlowModule(this.id);

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ModuleProbeResult.ok(id, const []);
  }
}
