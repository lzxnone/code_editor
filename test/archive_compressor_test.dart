import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:code_editor/services/archive_compressor.dart';
import 'package:code_editor/services/archive_extractor.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempTestDir;

  setUp(() {
    tempTestDir = Directory.systemTemp.createTempSync('archive_compressor_test_');
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      try {
        tempTestDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('ArchiveCompressor CRC-32 Tests', () {
    test('standard test vector "123456789" produces 0xCBF43926', () {
      final input = utf8.encode('123456789');
      final crc = computeCrc32(input);
      expect(crc, equals(0xCBF43926));
    });

    test('empty byte array produces 0', () {
      final crc = computeCrc32(<int>[]);
      expect(crc, equals(0));
    });

    test('incremental chunked calculation matches one-shot calculation', () {
      final data = Uint8List.fromList(List<int>.generate(20000, (i) => i % 256));
      final oneShotCrc = computeCrc32(data);

      var chunkedCrc = 0;
      const chunkSize = 1024;
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
        chunkedCrc = computeCrc32(data.sublist(i, end), chunkedCrc);
      }

      expect(chunkedCrc, equals(oneShotCrc));
    });
  });

  group('ArchiveCompressor Streaming ZIP Compression Tests', () {
    test('compresses nested files, empty files, empty dirs and utf-8 names cleanly', () async {
      final srcDir = Directory(p.join(tempTestDir.path, 'source_project'))..createSync();

      // 1. 普通文件
      final fileA = File(p.join(srcDir.path, 'main.dart'))..writeAsStringSync('void main() => print("hello");');

      // 2. 多级子目录与文件
      final subDir = Directory(p.join(srcDir.path, 'src', 'utils'))..createSync(recursive: true);
      final fileB = File(p.join(subDir.path, 'helper.dart'))..writeAsStringSync('class Helper {}');

      // 3. 空目录
      Directory(p.join(srcDir.path, 'assets', 'empty_folder')).createSync(recursive: true);

      // 4. 空文件
      File(p.join(srcDir.path, 'EMPTY.txt')).writeAsStringSync('');

      // 5. 中文与表情等 UTF-8 文件名
      final fileUtf8 = File(p.join(srcDir.path, '测试项目_说明.md'))..writeAsStringSync('# 中文测试文档\n内容丰富');

      // 6. 大文件 (> 128KB 验证 64KB 多分块流式压缩与 CRC 回填)
      final largeContent = 'Line of large content for streaming test 1234567890\n' * 3000;
      final fileLarge = File(p.join(srcDir.path, 'large_file.txt'))..writeAsStringSync(largeContent);

      final zipFile = File(p.join(tempTestDir.path, 'output.zip'));
      final progressList = <double>[];

      await ArchiveCompressor.zipDirectory(
        sourceDir: srcDir,
        targetZipFile: zipFile,
        onProgress: (p, msg) {
          progressList.add(p);
        },
      );

      expect(zipFile.existsSync(), isTrue);
      expect(zipFile.lengthSync(), greaterThan(100));
      expect(progressList, isNotEmpty);
      expect(progressList.last, equals(1.0));

      // 使用 ArchiveExtractor 解压验证 ZIP 完整性与正确性
      final extractDir = Directory(p.join(tempTestDir.path, 'extracted'))..createSync();
      await ArchiveExtractor.extract(
        archiveFile: zipFile,
        targetDir: extractDir,
      );

      // 校验解压出的各个文件及内容
      expect(File(p.join(extractDir.path, 'main.dart')).existsSync(), isTrue);
      expect(File(p.join(extractDir.path, 'main.dart')).readAsStringSync(), equals(fileA.readAsStringSync()));

      expect(File(p.join(extractDir.path, 'src', 'utils', 'helper.dart')).existsSync(), isTrue);
      expect(File(p.join(extractDir.path, 'src', 'utils', 'helper.dart')).readAsStringSync(), equals(fileB.readAsStringSync()));

      expect(Directory(p.join(extractDir.path, 'assets', 'empty_folder')).existsSync(), isTrue);

      expect(File(p.join(extractDir.path, 'EMPTY.txt')).existsSync(), isTrue);
      expect(File(p.join(extractDir.path, 'EMPTY.txt')).readAsStringSync(), isEmpty);

      expect(File(p.join(extractDir.path, '测试项目_说明.md')).existsSync(), isTrue);
      expect(File(p.join(extractDir.path, '测试项目_说明.md')).readAsStringSync(), equals(fileUtf8.readAsStringSync()));

      expect(File(p.join(extractDir.path, 'large_file.txt')).existsSync(), isTrue);
      expect(File(p.join(extractDir.path, 'large_file.txt')).readAsStringSync(), equals(fileLarge.readAsStringSync()));
    });

    test('cancellation aborts compression and cleans up target zip file', () async {
      final srcDir = Directory(p.join(tempTestDir.path, 'cancel_src'))..createSync();
      for (var i = 0; i < 50; i++) {
        File(p.join(srcDir.path, 'file_$i.txt')).writeAsStringSync('Content $i ' * 500);
      }

      final zipFile = File(p.join(tempTestDir.path, 'cancel_target.zip'));

      expect(
        () async {
          await ArchiveCompressor.zipDirectory(
            sourceDir: srcDir,
            targetZipFile: zipFile,
            isCancelled: () => true,
          );
        },
        throwsA(isA<ArchiveCompressCancelledException>()),
      );

      // 验证未完成的临时或目标 zip 文件被及时清理
      expect(zipFile.existsSync(), isFalse);
    });
  });

  group('InternalProjectService Export & Import End-to-End Tests', () {
    test('exports project to zip and re-imports back with perfect fidelity', () async {
      final service = InternalProjectService.instance;
      final customProjectsDir = Directory(p.join(tempTestDir.path, 'projects'))..createSync(recursive: true);
      service.customProjectsDir = customProjectsDir;

      // 1. 创建待导出的项目
      final projectDir = await service.createProject('MyExportApp');
      File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('name: my_export_app\nversion: 1.0.0\n');
      final libDir = Directory(p.join(projectDir.path, 'lib'))..createSync();
      File(p.join(libDir.path, 'main.dart')).writeAsStringSync('void main() {}');
      File(p.join(libDir.path, 'calc.dart')).writeAsStringSync('int add(int a, int b) => a + b;');

      // 2. 导出到外部目标目录
      final exportDir = Directory(p.join(tempTestDir.path, 'user_exports'))..createSync(recursive: true);
      final targetZipPath = p.join(exportDir.path, 'MyExportApp.zip');

      final exportedFile = await service.exportProjectToZip(projectDir, targetZipPath);
      expect(exportedFile.existsSync(), isTrue);
      expect(exportedFile.path, equals(targetZipPath));

      // 3. 从导出的 ZIP 重新导入为新项目
      final importedProjectDir = await service.importProjectFromArchive(
        targetZipPath,
        'MyExportApp_Restored',
      );

      expect(importedProjectDir.existsSync(), isTrue);
      expect(p.basename(importedProjectDir.path), equals('MyExportApp_Restored'));

      // 4. 校验所有导入的文件及内容无损还原
      final pubspec = File(p.join(importedProjectDir.path, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue);
      expect(pubspec.readAsStringSync(), contains('name: my_export_app'));

      final restoredMain = File(p.join(importedProjectDir.path, 'lib', 'main.dart'));
      expect(restoredMain.existsSync(), isTrue);
      expect(restoredMain.readAsStringSync(), equals('void main() {}'));

      final restoredCalc = File(p.join(importedProjectDir.path, 'lib', 'calc.dart'));
      expect(restoredCalc.existsSync(), isTrue);
      expect(restoredCalc.readAsStringSync(), equals('int add(int a, int b) => a + b;'));
    });
  });
}
