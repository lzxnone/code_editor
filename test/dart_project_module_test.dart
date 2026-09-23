import 'dart:io';

import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/services/project_modules/dart_project_module.dart';
import 'package:code_editor/services/project_modules/project_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _MockProjectProbe implements ProjectProbe {
  final Directory _dir;
  final Set<String> _availableCommands;
  final bool _cancelled = false;

  _MockProjectProbe(this._dir, {Set<String>? availableCommands})
      : _availableCommands = availableCommands ?? {};

  @override
  Directory get projectDir => _dir;

  @override
  bool get isCancelled => _cancelled;

  @override
  Future<bool> hasCommand(String command) async {
    return _availableCommands.contains(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dart_module_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DartProjectModule', () {
    test('isFlutterProject correctly identifies Flutter vs pure Dart pubspec', () {
      final flutterDir = Directory(p.join(tempDir.path, 'flutter_app'))..createSync();
      File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_flutter_app
dependencies:
  flutter:
    sdk: flutter
''');

      final dartDir = Directory(p.join(tempDir.path, 'dart_cli'))..createSync();
      File(p.join(dartDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_cli
dependencies:
  args: ^2.4.0
''');

      expect(DartProjectModule.isFlutterProject(flutterDir), isTrue);
      expect(DartProjectModule.isFlutterProject(dartDir), isFalse);
    });

    test('Flutter project gracefully returns ok with empty tasks when flutter is not installed', () async {
      final flutterDir = Directory(p.join(tempDir.path, 'flutter_app'))..createSync();
      File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_flutter_app
dependencies:
  flutter:
    sdk: flutter
''');

      final module = DartProjectModule();
      final probe = _MockProjectProbe(flutterDir, availableCommands: {});

      final result = await module.probe(probe);

      // 应当成功结束，不报未找到 dart 错误，任务列表为空
      expect(result.status, ModuleProbeStatus.ok);
      expect(result.tasks, isEmpty);
      expect(result.failure, isNull);
    });

    test('Flutter project provides Flutter tasks when flutter command is available', () async {
      final flutterDir = Directory(p.join(tempDir.path, 'flutter_app'))..createSync();
      File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_flutter_app
flutter:
  uses-material-design: true
''');

      final module = DartProjectModule();
      final probe = _MockProjectProbe(flutterDir, availableCommands: {'flutter'});

      final result = await module.probe(probe);

      expect(result.status, ModuleProbeStatus.ok);
      expect(result.tasks.length, 2);
      expect(result.tasks.any((t) => t.name == 'Flutter: Run'), isTrue);
      expect(result.tasks.any((t) => t.name == 'Flutter: Test'), isTrue);
    });

    test('Pure Dart project reports toolchainMissing when dart command is missing', () async {
      final dartDir = Directory(p.join(tempDir.path, 'dart_cli'))..createSync();
      File(p.join(dartDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_cli
dependencies:
  path: ^1.9.0
''');

      final module = DartProjectModule();
      final probe = _MockProjectProbe(dartDir, availableCommands: {});

      final result = await module.probe(probe);

      expect(result.status, ModuleProbeStatus.failed);
      expect(result.failure, NoticeFailure.toolchainMissing);
      expect(result.failureDetail, 'dart');
    });

    test('Pure Dart project returns tasks when dart command is present', () async {
      final dartDir = Directory(p.join(tempDir.path, 'dart_cli'))..createSync();
      File(p.join(dartDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_cli
''');

      final module = DartProjectModule();
      final probe = _MockProjectProbe(dartDir, availableCommands: {'dart'});

      final result = await module.probe(probe);

      expect(result.status, ModuleProbeStatus.ok);
      expect(result.tasks.length, 2);
      expect(result.tasks.any((t) => t.name == 'Dart: Run'), isTrue);
    });
  });
}
