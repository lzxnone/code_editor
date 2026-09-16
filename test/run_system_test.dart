import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/run_task_storage_service.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';
import 'package:code_editor/widgets/notice_host.dart';
import 'package:code_editor/widgets/run_tasks_dialog.dart';

/// 单测用的假系统名（探测必须基于"真实可用系统"，单测里用假 rootfs 代替真容器）
const String kTestSystemName = 'test_sys';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunTask & RunTaskStorageService Tests', () {
    late Directory tempDir;
    late RunTaskStorageService storageService;
    late Directory distroBaseDir;
    late DistroManager distroManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('run_task_test_');
      storageService = RunTaskStorageService();

      // 构造一个已安装就绪的假系统：<base>/<sys>/rootfs/{etc,bin}
      // 并放入各模块所需工具链的桩文件（依赖检测走宿主 rootfs 快速判定）
      distroBaseDir = await Directory.systemTemp.createTemp('run_task_distro_');
      final rootfs = Directory(p.join(distroBaseDir.path, kTestSystemName, 'rootfs'));
      Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
      Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
      final usrBin = Directory(p.join(rootfs.path, 'usr', 'bin'))..createSync(recursive: true);
      for (final binary in ['java', 'gradle', 'cmake', 'make', 'npm', 'node', 'cargo']) {
        File(p.join(usrBin.path, binary)).writeAsStringSync('#!/bin/sh\n');
      }
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

    test('save and load custom tasks', () async {
      final initialTasks = (await storageService.loadConfig(tempDir.path)).tasks;
      expect(initialTasks, isEmpty);

      final customTask = const RunTask(
        id: 'task_1',
        name: 'Debug Build',
        command: 'cmake -B build && cmake --build build',
        source: TaskSource.custom,
        description: 'Test description',
        clearBeforeRun: true,
      );

      await storageService.saveConfig(projectRoot: tempDir.path, tasks: [customTask]);

      final loadedTasks = (await storageService.loadConfig(tempDir.path)).tasks;
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

    test('任务探测：CMake + 单文件任务', () async {
      // 模拟 CMakeLists.txt
      final cmakeFile = File('${tempDir.path}/CMakeLists.txt');
      await cmakeFile.writeAsString('cmake_minimum_required(VERSION 3.10)');

      // 模拟 main.py
      final pyFile = File('${tempDir.path}/main.py');
      await pyFile.writeAsString('print("hello")');

      final tasks = await ProjectTaskDispatcher.instance.detect(
        projectRoot: tempDir.path,
        currentFilePath: pyFile.path,
        systemName: kTestSystemName,
        distroManager: distroManager,
      );

      expect(tasks.isNotEmpty, isTrue);
      // 首项为当前打开的 Python 文件单文件任务
      expect(tasks.first.id, 'detected_single_python');
      expect(tasks.first.command, contains('python3'));

      // 包含 CMake 相关构建任务
      expect(tasks.any((t) => t.id == 'detected_cmake_build_run'), isTrue);
      expect(tasks.any((t) => t.id == 'detected_cmake_clean'), isTrue);
    });

    test('任务探测：Makefile / Cargo / NPM / Dart / 单文件（Gradle 只认真实自省）', () async {
      final makefile = File('${tempDir.path}/Makefile');
      await makefile.writeAsString('all:\n\tgcc main.c\n');

      final cargoToml = File('${tempDir.path}/Cargo.toml');
      await cargoToml.writeAsString('[package]\nname = "demo"\n');

      final packageJson = File('${tempDir.path}/package.json');
      await packageJson.writeAsString('{"name": "demo", "scripts": {"start": "node index.js", "test": "jest"}}');

      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('name: demo\n');

      final gradlew = File('${tempDir.path}/gradlew');
      await gradlew.writeAsString('#!/bin/sh\n');

      final cppFile = File('${tempDir.path}/main.cpp');
      await cppFile.writeAsString('int main() { return 0; }');

      final tasks = await ProjectTaskDispatcher.instance.detect(
        projectRoot: tempDir.path,
        currentFilePath: cppFile.path,
        systemName: kTestSystemName,
        distroManager: distroManager,
      );

      expect(tasks.any((t) => t.id == 'detected_single_cpp'), isTrue);
      expect(tasks.first.command, contains('g++'));
      expect(tasks.any((t) => t.id == 'detected_make_default'), isTrue);
      expect(tasks.any((t) => t.id == 'detected_cargo_run'), isTrue);
      expect(tasks.any((t) => t.id == 'detected_npm_start'), isTrue);
      expect(tasks.any((t) => t.id == 'detected_dart_run'), isTrue);
      // Gradle 只认真实自省结果：测试环境无法真正执行 gradle，因此不产出任何 Gradle 任务，
      // 更不允许出现任何硬编码兜底任务（detected_gradle_*）
      expect(tasks.any((t) => t.id.startsWith('detected_gradle_')), isFalse);
      expect(tasks.any((t) => t.moduleId == 'gradle'), isFalse);
    });
  });

  group('RunTask Localization Tests', () {
    testWidgets('getLocalizedDescription returns correct localized text in zh and en for all detected tasks', (tester) async {
      late AppLocalizations l10nZh;
      late AppLocalizations l10nEn;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: Builder(builder: (ctx) {
            l10nZh = AppLocalizations.of(ctx)!;
            return const SizedBox();
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('en'),
          home: Builder(builder: (ctx) {
            l10nEn = AppLocalizations.of(ctx)!;
            return const SizedBox();
          }),
        ),
      );
      await tester.pumpAndSettle();

      const gradleRunTask = RunTask(
        id: 'detected_gradle_run',
        name: 'Gradle: Run',
        command: 'sh ./gradlew run',
        source: TaskSource.detected,
      );
      expect(gradleRunTask.getLocalizedDescription(l10nZh), '执行应用程序主入口');
      expect(gradleRunTask.getLocalizedDescription(l10nEn), 'Execute application main entrypoint');

      const gradleAssembleTask = RunTask(
        id: 'detected_gradle_assemble',
        name: 'Gradle: Assemble Debug',
        command: 'sh ./gradlew assembleDebug',
        source: TaskSource.detected,
      );
      expect(gradleAssembleTask.getLocalizedDescription(l10nZh), '构建调试输出包');
      expect(gradleAssembleTask.getLocalizedDescription(l10nEn), 'Build debug output package');

      const gradleBuildTask = RunTask(
        id: 'detected_gradle_build',
        name: 'Gradle: Build',
        command: 'sh ./gradlew build',
        source: TaskSource.detected,
      );
      expect(gradleBuildTask.getLocalizedDescription(l10nZh), '执行完整构建与测试');
      expect(gradleBuildTask.getLocalizedDescription(l10nEn), 'Execute full build and tests');

      const cmakeBuildRunTask = RunTask(
        id: 'detected_cmake_build_run',
        name: 'CMake: Build & Run',
        command: 'cmake -B build',
        source: TaskSource.detected,
      );
      expect(cmakeBuildRunTask.getLocalizedDescription(l10nZh), '配置、编译并尝试启动生成的目标程序');
      expect(cmakeBuildRunTask.getLocalizedDescription(l10nEn), 'Configure, build, and try launching the target executable');
    });

    testWidgets('RunTasksDialog displays English descriptions when locale is en', (tester) async {
      const detectedTasks = [
        RunTask(
          id: 'detected_gradle_run',
          name: 'Gradle: Run',
          command: 'sh ./gradlew run',
          source: TaskSource.detected,
        ),
        RunTask(
          id: 'detected_gradle_assemble',
          name: 'Gradle: Assemble Debug',
          command: 'sh ./gradlew assembleDebug',
          source: TaskSource.detected,
        ),
        RunTask(
          id: 'detected_gradle_build',
          name: 'Gradle: Build',
          command: 'sh ./gradlew build',
          source: TaskSource.detected,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('en'),
          home: Scaffold(
            body: RunTasksDialog(
              customTasks: const [],
              detectedTasks: detectedTasks,
              onTaskSelected: (_) {},
              onEditCustomTasks: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In English, subtitles should be in English
      expect(find.text('Execute application main entrypoint'), findsOneWidget);
      expect(find.text('Build debug output package'), findsOneWidget);
      expect(find.text('Execute full build and tests'), findsOneWidget);

      // Chinese text should NOT appear
      expect(find.text('执行应用程序主入口'), findsNothing);
      expect(find.text('构建调试输出包'), findsNothing);
      expect(find.text('执行完整构建与测试'), findsNothing);
    });

    testWidgets('RunTasksDialog displays Chinese descriptions when locale is zh', (tester) async {
      const detectedTasks = [
        RunTask(
          id: 'detected_gradle_run',
          name: 'Gradle: Run',
          command: 'sh ./gradlew run',
          source: TaskSource.detected,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: Scaffold(
            body: RunTasksDialog(
              customTasks: const [],
              detectedTasks: detectedTasks,
              onTaskSelected: (_) {},
              onEditCustomTasks: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Chinese, subtitles should be in Chinese
      expect(find.text('执行应用程序主入口'), findsOneWidget);
      expect(find.text('Execute application main entrypoint'), findsNothing);
    });

    testWidgets('Missing distro dialog renders without overflow in English on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.missingDistroTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  content: Text(l10n.noDistroAvailableContent),
                  actions: [
                    TextButton(onPressed: () {}, child: Text(l10n.cancel)),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(l10n.systemManagement),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('System Environment Not Ready'), findsOneWidget);
      expect(find.text('No available Linux execution environment detected.\n\nProject tasks need to run inside a Linux container. Please install or download a Linux system first (e.g. Ubuntu or Alpine).'), findsOneWidget);
    });

    test('RunProvider 切换项目时运行任务完全隔离，不发生上一个项目的任务污染', () async {
      final projectADir = await Directory.systemTemp.createTemp('project_a_');
      final projectBDir = await Directory.systemTemp.createTemp('project_b_');
      addTearDown(() async {
        if (await projectADir.exists()) await projectADir.delete(recursive: true);
        if (await projectBDir.exists()) await projectBDir.delete(recursive: true);
      });

      final runProvider = RunProvider();

      // 1. 打开项目 A，并执行并记录一个任务
      await runProvider.onProjectOpened(projectADir.path);
      expect(runProvider.currentProjectRoot, equals(projectADir.path));
      expect(runProvider.lastRunTask, isNull);

      const taskA = RunTask(
        id: 'task_a_build',
        name: 'Build Project A',
        command: 'echo "building A"',
        source: TaskSource.custom,
      );
      await runProvider.addCustomTask(taskA);
      await runProvider.setLastRunTask(taskA);

      expect(runProvider.lastRunTask?.id, equals('task_a_build'));
      expect(runProvider.lastRunTaskId, equals('task_a_build'));

      // 2. 切换至项目 B（新项目，无持久化任务）
      await runProvider.onProjectOpened(projectBDir.path);
      expect(runProvider.currentProjectRoot, equals(projectBDir.path));

      // 验证：项目 A 的 lastRunTask 与 customTasks 绝不会泄漏到项目 B！
      expect(runProvider.lastRunTask, isNull);
      expect(runProvider.lastRunTaskId, isNull);
      expect(runProvider.customTasks, isEmpty);
      expect(runProvider.allTasks.any((t) => t.id == 'task_a_build'), isFalse);

      // 3. 在项目 B 添加并执行任务 B
      const taskB = RunTask(
        id: 'task_b_test',
        name: 'Test Project B',
        command: 'pytest',
        source: TaskSource.custom,
      );
      await runProvider.addCustomTask(taskB);
      await runProvider.setLastRunTask(taskB);
      expect(runProvider.lastRunTask?.id, equals('task_b_test'));

      // 4. 切回项目 A，应该恢复项目 A 自身的历史任务
      await runProvider.onProjectOpened(projectADir.path);
      expect(runProvider.currentProjectRoot, equals(projectADir.path));
      expect(runProvider.lastRunTask?.id, equals('task_a_build'));
      expect(runProvider.lastRunTaskId, equals('task_a_build'));
      expect(runProvider.customTasks.any((t) => t.id == 'task_a_build'), isTrue);
      expect(runProvider.customTasks.any((t) => t.id == 'task_b_test'), isFalse);

      // 5. 关闭项目
      runProvider.onProjectClosed();
      expect(runProvider.currentProjectRoot, isNull);
      expect(runProvider.lastRunTask, isNull);
      expect(runProvider.lastRunTaskId, isNull);
      expect(runProvider.allTasks, isEmpty);
    });

    testWidgets('RunTasksDialog: 任务类型折叠 Tile 自由切换且在内存中保持折叠状态', (tester) async {
      const detectedTasks = [
        RunTask(
          id: 'detected_gradle_run',
          name: 'Gradle: Run',
          command: 'sh ./gradlew run',
          source: TaskSource.detected,
          moduleId: 'gradle',
          group: 'mod development/internal',
        ),
      ];

      Widget buildDialog() {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: Scaffold(
            body: RunTasksDialog(
              customTasks: const [],
              detectedTasks: detectedTasks,
              onTaskSelected: (_) {},
              onEditCustomTasks: () {},
            ),
          ),
        );
      }

      // 1. 初次渲染，任务正常显示
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();
      expect(find.text('Gradle: Run'), findsOneWidget);

      // 2. 点击 Gradle 折叠 tile 头部将其收起
      await tester.tap(find.text('Gradle'));
      await tester.pumpAndSettle();
      expect(find.text('Gradle: Run'), findsNothing);

      // 3. 模拟关闭并重新打开 Dialog（重建 widget）
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();
      // 折叠状态由内存持久化维持，依然处于收起状态
      expect(find.text('Gradle: Run'), findsNothing);

      // 4. 再次点击重新展开
      await tester.tap(find.text('Gradle'));
      await tester.pumpAndSettle();
      expect(find.text('Gradle: Run'), findsOneWidget);
    });

    testWidgets('NoticeHost 卡片视觉：成功时背景为绿色，失败时为红色描边', (tester) async {
      final center = NoticeCenter();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: Scaffold(
            body: NoticeHost(center: center),
          ),
        ),
      );

      // 1. 推送成功通知
      center.push(const NoticeItem(
        id: 'success_notice',
        kind: NoticeKind.success,
        text: ModuleDoneText('Gradle', taskCount: 3),
      ));
      await tester.pumpAndSettle();

      final successMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.textContaining('Gradle'),
          matching: find.byType(Material),
        ).first,
      );
      // 成功卡片背景为深绿或绿色
      expect(successMaterial.color, equals(const Color(0xFF2E7D32)));

      // 2. 推送失败通知
      center.push(const NoticeItem(
        id: 'failure_notice',
        kind: NoticeKind.failure,
        text: ModuleFailureText(
          moduleDisplayName: 'CMake',
          failure: NoticeFailure.executionFailed,
        ),
      ));
      await tester.pumpAndSettle();

      final failureMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.textContaining('CMake'),
          matching: find.byType(Material),
        ).first,
      );
      final shape = failureMaterial.shape as RoundedRectangleBorder;
      // 失败卡片有红色描边
      expect(shape.side.color, equals(const Color(0xFFE53935)));
      expect(shape.side.width, equals(1.5));
    });
  });
}

