import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late InternalProjectService service;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('internal_project_test_');
    service = InternalProjectService.instance;
    service.customProjectsDir = Directory(p.join(tempBaseDir.path, 'files', 'projects'));
  });

  tearDown(() {
    service.customProjectsDir = null;
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  group('InternalProjectService Unit Tests', () {
    test('getProjectsDirectory creates directory if it does not exist', () async {
      final dir = await service.getProjectsDirectory();
      expect(dir.existsSync(), isTrue);
      expect(p.split(dir.path), containsAll(['files', 'projects']));
    });

    test('createProject successfully creates new project folder', () async {
      final projectDir = await service.createProject('my_cool_project');
      expect(projectDir.existsSync(), isTrue);
      expect(p.basename(projectDir.path), 'my_cool_project');

      final exists = await service.projectExists('my_cool_project');
      expect(exists, isTrue);
    });

    test('createProject throws when name is empty or already exists', () async {
      expect(() => service.createProject('   '), throwsA(isA<FileSystemException>()));

      await service.createProject('unique_project');
      expect(() => service.createProject('unique_project'), throwsA(isA<FileSystemException>()));
    });

    test('listProjects returns sorted directories', () async {
      await service.createProject('project_c');
      await service.createProject('project_a');
      await service.createProject('project_b');

      final list = await service.listProjects();
      expect(list.length, 3);
      expect(p.basename(list[0].path), 'project_a');
      expect(p.basename(list[1].path), 'project_b');
      expect(p.basename(list[2].path), 'project_c');
    });

    test('renameProject successfully renames project folder', () async {
      final original = await service.createProject('old_name');
      expect(original.existsSync(), isTrue);

      final renamed = await service.renameProject(original, 'new_name');
      expect(original.existsSync(), isFalse);
      expect(renamed.existsSync(), isTrue);
      expect(p.basename(renamed.path), 'new_name');

      final list = await service.listProjects();
      expect(list.length, 1);
      expect(p.basename(list[0].path), 'new_name');
    });

    test('renameProject throws if target name already exists or is empty', () async {
      final p1 = await service.createProject('p1');
      await service.createProject('p2');

      expect(() => service.renameProject(p1, '  '), throwsA(isA<FileSystemException>()));
      expect(() => service.renameProject(p1, 'p2'), throwsA(isA<FileSystemException>()));
    });

    test('deleteProject recursively deletes project folder', () async {
      final projectDir = await service.createProject('to_delete');
      // Create subfile inside project
      final subFile = File(p.join(projectDir.path, 'main.dart'));
      await subFile.writeAsString('void main() {}');
      expect(subFile.existsSync(), isTrue);

      await service.deleteProject(projectDir);
      expect(projectDir.existsSync(), isFalse);
      expect(await service.projectExists('to_delete'), isFalse);
    });

    test('isInternalProject correctly identifies internal vs external paths', () async {
      final proj = await service.createProject('my_app');
      expect(service.isInternalProject(proj.path), isTrue);

      expect(service.isInternalProject(null), isFalse);
      expect(service.isInternalProject(''), isFalse);
      expect(service.isInternalProject('   '), isFalse);
      expect(service.isInternalProject('C:/Users/SomeUser/Desktop/other_project'), isFalse);
      expect(service.isInternalProject('/storage/emulated/0/Download/some_proj'), isFalse);
    });

    test('importProjectFromArchive extracts archive into new project directory', () async {
      // Create a test zip file
      final zipFilePath = p.join(tempBaseDir.path, 'sample_project.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      final dummyFile = File(p.join(tempBaseDir.path, 'readme.md'));
      dummyFile.writeAsStringSync('# Test Project');
      encoder.addFile(dummyFile);
      encoder.close();

      final importedDir = await service.importProjectFromArchive(zipFilePath, 'sample_project');
      expect(importedDir.existsSync(), isTrue);
      expect(p.basename(importedDir.path), 'sample_project');

      final extractedReadme = File(p.join(importedDir.path, 'readme.md'));
      expect(extractedReadme.existsSync(), isTrue);
      expect(extractedReadme.readAsStringSync(), '# Test Project');

      // Verify listing includes imported project
      final list = await service.listProjects();
      expect(list.any((d) => p.basename(d.path) == 'sample_project'), isTrue);
    });

    test('importProjectFromArchive throws when target project already exists or archive missing', () async {
      await service.createProject('existing_project');

      final zipFilePath = p.join(tempBaseDir.path, 'dummy.zip');
      expect(
        () => service.importProjectFromArchive(zipFilePath, 'existing_project'),
        throwsA(isA<FileSystemException>()),
      );

      expect(
        () => service.importProjectFromArchive(zipFilePath, 'non_existent_zip_proj'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

