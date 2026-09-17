import 'dart:io';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/lsp_language_config.dart';
import 'package:code_editor/models/run_task.dart';
import 'package:code_editor/services/project_modules/maven_project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:code_editor/services/project_modules/python_project_module.dart';
import 'package:code_editor/services/project_modules/single_file_task_detector.dart';
import 'package:code_editor/services/project_task_dispatcher.dart';
import 'package:code_editor/services/toolchain_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('extended_modules_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SingleFileTaskDetector Extended Tests', () {
    test('Detects Java single file', () {
      final javaFile = File(p.join(tempDir.path, 'Hello.java'))..writeAsStringSync('public class Hello {}');
      expect(SingleFileTaskDetector.isSupported(javaFile.path), isTrue);

      final task = SingleFileTaskDetector.detect(tempDir.path, javaFile.path);
      expect(task, isNotNull);
      expect(task!.id, equals('detected_single_java'));
      expect(task.name, equals('Java: Hello.java'));
      expect(task.command, contains('java '));
    });

    test('Detects TypeScript single file', () {
      final tsFile = File(p.join(tempDir.path, 'index.ts'))..writeAsStringSync('console.log(42);');
      expect(SingleFileTaskDetector.isSupported(tsFile.path), isTrue);

      final task = SingleFileTaskDetector.detect(tempDir.path, tsFile.path);
      expect(task, isNotNull);
      expect(task!.id, equals('detected_single_ts'));
      expect(task.command, contains('npx -y tsx'));
    });

    test('Detects Lua, Perl, PHP single files', () {
      final luaFile = File(p.join(tempDir.path, 'script.lua'))..writeAsStringSync('print("hi")');
      final plFile = File(p.join(tempDir.path, 'script.pl'))..writeAsStringSync('print "hi";');
      final phpFile = File(p.join(tempDir.path, 'index.php'))..writeAsStringSync('<?php echo "hi";');

      final luaTask = SingleFileTaskDetector.detect(tempDir.path, luaFile.path);
      expect(luaTask, isNotNull);
      expect(luaTask!.id, equals('detected_single_lua'));
      expect(luaTask.command, contains('lua '));

      final plTask = SingleFileTaskDetector.detect(tempDir.path, plFile.path);
      expect(plTask, isNotNull);
      expect(plTask!.id, equals('detected_single_perl'));
      expect(plTask.command, contains('perl '));

      final phpTask = SingleFileTaskDetector.detect(tempDir.path, phpFile.path);
      expect(phpTask, isNotNull);
      expect(phpTask!.id, equals('detected_single_php'));
      expect(phpTask.command, contains('php '));
    });
  });

  group('PythonProjectModule Tests', () {
    test('Activates on requirements.txt and generates pip, run and pytest tasks', () async {
      File(p.join(tempDir.path, 'requirements.txt')).writeAsStringSync('flask\npytest');
      File(p.join(tempDir.path, 'main.py')).writeAsStringSync('print("app")');
      Directory(p.join(tempDir.path, 'tests')).createSync();

      final module = PythonProjectModule();
      expect(module.shouldActivate(tempDir), isTrue);

      final dispatcher = ProjectTaskDispatcher();
      final probe = dispatcher.createProbe(
        projectRoot: tempDir.path,
        systemName: 'ubuntu',
      );

      final result = await module.probe(probe);
      expect(result.status, equals(ModuleProbeStatus.ok));
      final taskIds = result.tasks.map((t) => t.id).toList();
      expect(taskIds, contains('detected_python_pip_install'));
      expect(taskIds, contains('detected_python_run_main'));
      expect(taskIds, contains('detected_python_pytest'));
    });
  });

  group('MavenProjectModule Tests', () {
    test('Activates on pom.xml and supports mvnw wrapper', () async {
      File(p.join(tempDir.path, 'pom.xml')).writeAsStringSync('<project></project>');
      File(p.join(tempDir.path, 'mvnw')).writeAsStringSync('#!/bin/sh');

      final module = MavenProjectModule();
      expect(module.shouldActivate(tempDir), isTrue);

      final dispatcher = ProjectTaskDispatcher();
      final probe = dispatcher.createProbe(
        projectRoot: tempDir.path,
        systemName: 'ubuntu',
      );

      final result = await module.probe(probe);
      expect(result.status, equals(ModuleProbeStatus.ok));
      final taskIds = result.tasks.map((t) => t.id).toList();
      expect(taskIds, contains('detected_maven_package'));
      expect(taskIds, contains('detected_maven_compile'));
      expect(taskIds, contains('detected_maven_test'));
      expect(taskIds, contains('detected_maven_clean'));

      // Verifies ./mvnw was used because wrapper exists
      final pkgTask = result.tasks.firstWhere((t) => t.id == 'detected_maven_package');
      expect(pkgTask.command, equals('./mvnw package'));
    });
  });

  group('ToolchainService Extended Tests', () {
    test('Supported tools contain java, maven, lua, perl, php', () {
      expect(ToolchainService.supportedTools.containsKey('java'), isTrue);
      expect(ToolchainService.supportedTools.containsKey('maven'), isTrue);
      expect(ToolchainService.supportedTools.containsKey('mvn'), isTrue);
      expect(ToolchainService.supportedTools.containsKey('lua'), isTrue);
      expect(ToolchainService.supportedTools.containsKey('perl'), isTrue);
      expect(ToolchainService.supportedTools.containsKey('php'), isTrue);
    });
  });

  group('LspLanguageConfig Presets Extended Tests', () {
    test('Builtin presets contain Java, TypeScript, Lua', () {
      final javaPreset = LspLanguageConfig.findBuiltinByExtension('.java');
      expect(javaPreset, isNotNull);
      expect(javaPreset!.id, equals('java'));

      final tsPreset = LspLanguageConfig.findBuiltinByExtension('.ts');
      expect(tsPreset, isNotNull);
      expect(tsPreset!.id, equals('typescript'));

      final luaPreset = LspLanguageConfig.findBuiltinByExtension('.lua');
      expect(luaPreset, isNotNull);
      expect(luaPreset!.id, equals('lua'));
    });
  });


  group('Localization Coverage Tests', () {
    testWidgets('Localized descriptions exist for all new tasks in zh and en without throwing', (tester) async {
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
          home: Builder(
            builder: (ctx) {
              l10nZh = AppLocalizations.of(ctx)!;
              return const SizedBox();
            },
          ),
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
          home: Builder(
            builder: (ctx) {
              l10nEn = AppLocalizations.of(ctx)!;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      const newTaskIds = [
        'detected_single_java',
        'detected_single_ts',
        'detected_single_lua',
        'detected_single_perl',
        'detected_single_php',
        'detected_python_pip_install',
        'detected_python_run_main',
        'detected_python_pytest',
        'detected_maven_package',
        'detected_maven_compile',
        'detected_maven_test',
        'detected_maven_clean',
      ];

      for (final id in newTaskIds) {
        final task = RunTask(
          id: id,
          name: id,
          command: 'echo 1',
          source: TaskSource.detected,
        );
        final descZh = task.getLocalizedDescription(l10nZh);
        final descEn = task.getLocalizedDescription(l10nEn);

        expect(descZh.isNotEmpty, isTrue, reason: '$id zh description should not be empty');
        expect(descEn.isNotEmpty, isTrue, reason: '$id en description should not be empty');
        expect(descZh != descEn, isTrue, reason: '$id zh and en descriptions should be distinct');
      }
    });
  });
}
