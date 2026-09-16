import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/project_modules/gradle_ide_model.dart';
import 'package:code_editor/services/project_modules/project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:code_editor/services/project_modules/standard_project_modules.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';
import 'package:code_editor/services/run_task_storage_service.dart';

class _CancellingModule extends ProjectModule {
  @override
  final String id;
  final Duration delay;
  final void Function(ProjectProbe probe)? onProbe;

  _CancellingModule(this.id, {this.delay = Duration.zero, this.onProbe});

  @override
  String get displayName => id;

  @override
  List<String> get triggerFiles => const [];

  @override
  bool shouldActivate(Directory projectDir) => true;

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    onProbe?.call(probe);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);
    return ModuleProbeResult.ok(id, const []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Probe System Logic Bug Fixes Verification', () {
    late Directory tempDir;
    late Directory distroBaseDir;
    late DistroManager distroManager;
    const systemName = 'test_sys';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('probe_fix_test_');
      distroBaseDir = await Directory.systemTemp.createTemp('probe_fix_distro_');

      final rootfs = Directory(p.join(distroBaseDir.path, systemName, 'rootfs'));
      Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
      Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);

      distroManager = DistroManager()..customBaseDir = distroBaseDir;
    });

    tearDown(() async {
      DistroManager().customBaseDir = null;
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await distroBaseDir.exists()) await distroBaseDir.delete(recursive: true);
    });

    test('1. detectSingleFileTask 安全包裹单引号与 -lm 数学库', () {
      final fileWithDollar = File(p.join(tempDir.path, 'test\$1.c'))..writeAsStringSync('int main() {}');
      final task = ProjectTaskDispatcher.detectSingleFileTask(tempDir.path, fileWithDollar.path);
      expect(task, isNotNull);
      // 命令必须包含单引号包裹和 -lm
      expect(task!.command, contains(r"gcc './test$1.c' -lm -o /tmp/a.out && /tmp/a.out"));

      final pyFile = File(p.join(tempDir.path, 'hello world.py'))..writeAsStringSync('print()');
      final pyTask = ProjectTaskDispatcher.detectSingleFileTask(tempDir.path, pyFile.path);
      expect(pyTask, isNotNull);
      expect(pyTask!.command, equals("python3 './hello world.py'"));
    });

    test('2. CargoProjectModule._declaredBinaryNames 过滤注释并支持带空格的 [[ bin ]]', () async {
      File(p.join(tempDir.path, 'Cargo.toml')).writeAsStringSync('''
[package]
name = "my_pkg"
version = "0.1.0"

[[ bin ]]
name = "server" # inline comment

[[bin]]
name = "client"
''');
      final probe = ProjectProbe(
        request: ProjectProbeRequest(
          projectDir: tempDir,
          systemName: systemName,
        ),
        distroManager: distroManager,
      );
      final cargoModule = CargoProjectModule();
      expect(cargoModule.shouldActivate(tempDir), isTrue);

      final res = await cargoModule.probe(probe);
      expect(res.tasks.map((t) => t.id), containsAll(['cargo_run_server', 'cargo_run_client']));
      final serverTask = res.tasks.firstWhere((t) => t.id == 'cargo_run_server');
      expect(serverTask.command, equals('cargo run --bin server'));
    });

    test('3. CMakeProjectModule 解析 add_executable 并包裹单引号', () async {
      File(p.join(tempDir.path, 'CMakeLists.txt')).writeAsStringSync('''
cmake_minimum_required(VERSION 3.10)
project(MyAwesomeProject)
add_executable(app_binary main.cpp)
''');
      final probe = ProjectProbe(
        request: ProjectProbeRequest(
          projectDir: tempDir,
          systemName: systemName,
        ),
        distroManager: distroManager,
      );
      final cmakeModule = CMakeProjectModule();
      final res = await cmakeModule.probe(probe);
      expect(res.status, ModuleProbeStatus.ok);
      final runTask = res.tasks.firstWhere((t) => t.id == 'detected_cmake_build_run');
      expect(runTask.command, contains("'./build/app_binary'"));
    });

    test('4. 取消探测时队列中所有未开始模块均完整记录为 cancelled', () async {
      final m1 = _CancellingModule('m1', delay: const Duration(milliseconds: 20), onProbe: (probe) {
        // 在 m1 执行时取消 probe
        probe.cancel();
      });
      final m2 = _CancellingModule('m2');
      final m3 = _CancellingModule('m3');

      final dispatcher = ProjectTaskDispatcher(customModules: [m1, m2, m3]);
      final probe = dispatcher.createProbe(
        projectRoot: tempDir.path,
        systemName: systemName,
        distroManager: distroManager,
      );

      final report = await dispatcher.run(probe);
      expect(probe.isCancelled, isTrue);
      // 全部激活模块均应在 moduleResults 中有记录
      expect(report.moduleResults.keys, containsAll(['m1', 'm2', 'm3']));
      expect(report.moduleResults['m1']?.status, ModuleProbeStatus.cancelled);
      expect(report.moduleResults['m2']?.status, ModuleProbeStatus.cancelled);
      expect(report.moduleResults['m3']?.status, ModuleProbeStatus.cancelled);
    });

    test('5. probeSystem 开始新探测时自动终止正在进行的旧探测', () async {
      final storage = RunTaskStorageService();
      final mLong = _CancellingModule('long', delay: const Duration(milliseconds: 200));

      final provider = RunProvider(
        storageService: storage,
        dispatcher: ProjectTaskDispatcher(customModules: [mLong]),
        distroManager: distroManager,
      );

      // 启动第 1 次探测
      final f1 = provider.probeSystem(projectRoot: tempDir.path, systemName: systemName);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.isDetecting, isTrue);
      final active1 = provider.activeProbeForTest;

      // 启动第 2 次探测：应该先 cancel 掉第 1 次
      final f2 = provider.probeSystem(projectRoot: tempDir.path, systemName: systemName);
      expect(active1?.isCancelled, isTrue);

      await Future.wait([f1, f2]);
    });

    test('6. SingleFileTaskDetector 独立模块支持 8 种语言并正确处理委托', () {
      final root = tempDir.path;
      final exts = {
        'a.py': 'python3',
        'a.c': 'gcc',
        'a.cpp': 'g++',
        'a.sh': 'sh',
        'a.dart': 'dart run',
        'a.go': 'go run',
        'a.rs': 'rustc',
        'a.js': 'node',
      };

      for (final entry in exts.entries) {
        final filePath = p.join(root, entry.key);
        File(filePath).writeAsStringSync('// dummy');

        expect(SingleFileTaskDetector.isSupported(filePath), isTrue);
        final task = SingleFileTaskDetector.detect(root, filePath);
        expect(task, isNotNull);
        expect(task!.command, contains(entry.value));

        // 验证 ProjectTaskDispatcher.detectSingleFileTask 委托结果一致
        final delegatedTask = ProjectTaskDispatcher.detectSingleFileTask(root, filePath);
        expect(delegatedTask, isNotNull);
        expect(delegatedTask!.id, equals(task.id));
      }
    });

    test('7. GradleIdeModel.fromJson 解析 schema: 0 包含具体 error 消息的 FormatException', () {
      final jsonWithError = {
        'schema': 0,
        'error': 'org.gradle.api.tasks.TaskInstantiationException: failed',
      };
      expect(
        () => GradleIdeModel.fromJson(jsonWithError),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('org.gradle.api.tasks.TaskInstantiationException: failed'),
          ),
        ),
      );
    });
  });
}
