import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:code_editor/services/archive_extractor.dart';
import 'package:code_editor/services/internal_project_service.dart';

/// 构造包含合法 XZ 头的字节流用于测试
List<int> encodeValidXz(List<int> payload) {
  // 最小合法 XZ 流结构 (Stream Header + Filter Flags + Data + Footer)
  final xzEncoded = XZEncoder().encode(payload);
  return xzEncoded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('archive_extractor_test_');
  });

  tearDown(() {
    try {
      if (tempBaseDir.existsSync()) {
        tempBaseDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('ArchiveExtractor Format Detection Tests', () {
    test('detectFormat correctly identifies format from magic bytes or extension', () {
      final zipFile = File(p.join(tempBaseDir.path, 'test.zip'));
      zipFile.writeAsBytesSync(ZipEncoder().encode(Archive()..addFile(ArchiveFile('a.txt', 1, [65])))!);
      expect(ArchiveExtractor.detectFormat(zipFile), ArchiveFormat.zip);

      final tarGzFile = File(p.join(tempBaseDir.path, 'test.tar.gz'));
      final tarBytes = TarEncoder().encode(Archive()..addFile(ArchiveFile('b.txt', 1, [66])));
      tarGzFile.writeAsBytesSync(GZipEncoder().encode(tarBytes)!);
      expect(ArchiveExtractor.detectFormat(tarGzFile), ArchiveFormat.tarGz);

      final xzBytes = encodeValidXz(tarBytes);
      final tarXzFile = File(p.join(tempBaseDir.path, 'test.tar.xz'));
      tarXzFile.writeAsBytesSync(xzBytes);
      expect(ArchiveExtractor.detectFormat(tarXzFile), ArchiveFormat.tarXz);
    });
  });

  group('ArchiveExtractor Extraction Tests', () {
    test('extracts ZIP archive with subdirectories and verifies content', () async {
      final zipFile = File(p.join(tempBaseDir.path, 'project.zip'));
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);

      final file1 = File(p.join(tempBaseDir.path, 'pubspec.yaml'));
      file1.writeAsStringSync('name: test_project\nversion: 1.0.0\n');
      encoder.addFile(file1);

      final file2 = File(p.join(tempBaseDir.path, 'main.dart'));
      file2.writeAsStringSync('void main() { print("hello world"); }');
      encoder.addFile(file2);

      encoder.close();

      final targetDir = Directory(p.join(tempBaseDir.path, 'extracted_zip'));
      final progressList = <double>[];

      await ArchiveExtractor.extract(
        archiveFile: zipFile,
        targetDir: targetDir,
        onProgress: (prog, msg) {
          progressList.add(prog);
        },
      );

      expect(targetDir.existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'pubspec.yaml')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'pubspec.yaml')).readAsStringSync(), contains('name: test_project'));
      expect(File(p.join(targetDir.path, 'main.dart')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'main.dart')).readAsStringSync(), contains('hello world'));
      expect(progressList.isNotEmpty, isTrue);
      expect(progressList.last, 1.0);
    });

    test('extracts TAR.GZ archive with low-memory streaming', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('src/index.js', 25, utf8.encode('console.log("hello node");')));
      archive.addFile(ArchiveFile('package.json', 16, utf8.encode('{"name":"demo"}')));
      final tarBytes = TarEncoder().encode(archive);
      final gzBytes = GZipEncoder().encode(tarBytes)!;

      final gzFile = File(p.join(tempBaseDir.path, 'project.tar.gz'));
      gzFile.writeAsBytesSync(gzBytes);

      final targetDir = Directory(p.join(tempBaseDir.path, 'extracted_targz'));
      await ArchiveExtractor.extract(
        archiveFile: gzFile,
        targetDir: targetDir,
      );

      expect(targetDir.existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'src', 'index.js')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'src', 'index.js')).readAsStringSync(), contains('hello node'));
      expect(File(p.join(targetDir.path, 'package.json')).existsSync(), isTrue);
    });

    test('extracts TAR.XZ archive using LowMemoryXZDecoder', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('CMakeLists.txt', 25, utf8.encode('cmake_minimum_required()')));
      archive.addFile(ArchiveFile('main.cpp', 20, utf8.encode('int main(){return 0;}')));
      final tarBytes = TarEncoder().encode(archive);
      final xzBytes = encodeValidXz(tarBytes);

      final xzFile = File(p.join(tempBaseDir.path, 'project.tar.xz'));
      xzFile.writeAsBytesSync(xzBytes);

      final targetDir = Directory(p.join(tempBaseDir.path, 'extracted_tarxz'));
      await ArchiveExtractor.extract(
        archiveFile: xzFile,
        targetDir: targetDir,
      );

      expect(targetDir.existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'CMakeLists.txt')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'CMakeLists.txt')).readAsStringSync(), 'cmake_minimum_required()');
      expect(File(p.join(targetDir.path, 'main.cpp')).existsSync(), isTrue);
    });

    test('cancellation aborts extraction and cleans up target directory', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('file1.txt', 10, utf8.encode('1234567890')));
      final tarBytes = TarEncoder().encode(archive);
      final gzBytes = GZipEncoder().encode(tarBytes)!;

      final gzFile = File(p.join(tempBaseDir.path, 'cancel_test.tar.gz'));
      gzFile.writeAsBytesSync(gzBytes);

      final targetDir = Directory(p.join(tempBaseDir.path, 'cancelled_target'));

      expect(
        () => ArchiveExtractor.extract(
          archiveFile: gzFile,
          targetDir: targetDir,
          isCancelled: () => true,
        ),
        throwsA(isA<ArchiveExtractCancelledException>()),
      );

      expect(targetDir.existsSync(), isFalse);
    });
  });

  group('InternalProjectService with ArchiveExtractor Tests', () {
    test('importProjectFromArchive uses ArchiveExtractor and imports project successfully', () async {
      final service = InternalProjectService.instance;
      service.customProjectsDir = Directory(p.join(tempBaseDir.path, 'files', 'projects'));

      final zipFile = File(p.join(tempBaseDir.path, 'sample_repo.zip'));
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      final dummyFile = File(p.join(tempBaseDir.path, 'app.py'));
      dummyFile.writeAsStringSync('print("python app")');
      encoder.addFile(dummyFile);
      encoder.close();

      final importedDir = await service.importProjectFromArchive(zipFile.path, 'sample_repo');
      expect(importedDir.existsSync(), isTrue);
      expect(File(p.join(importedDir.path, 'app.py')).existsSync(), isTrue);
      expect(File(p.join(importedDir.path, 'app.py')).readAsStringSync(), 'print("python app")');

      service.customProjectsDir = null;
    });
  });
}
