import 'dart:io';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/utils/git_diff_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GitDiffHelper.computeLineDiff Tests', () {
    test('Identical content returns empty markers', () {
      const base = 'line 1\nline 2\nline 3';
      const current = 'line 1\nline 2\nline 3';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers, isEmpty);
    });

    test('Added lines at end are marked as added', () {
      const base = 'line 1\nline 2';
      const current = 'line 1\nline 2\nline 3\nline 4';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers[2], equals(GitGutterDiffType.added));
      expect(markers[3], equals(GitGutterDiffType.added));
      expect(markers.containsKey(0), isFalse);
      expect(markers.containsKey(1), isFalse);
    });

    test('Added lines in middle are marked as added', () {
      const base = 'line 1\nline 3';
      const current = 'line 1\nline 2\nline 3';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers[1], equals(GitGutterDiffType.added));
      expect(markers.containsKey(0), isFalse);
      expect(markers.containsKey(2), isFalse);
    });

    test('Modified lines are marked as modified', () {
      const base = 'line 1\nold line 2\nline 3';
      const current = 'line 1\nnew line 2\nline 3';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers[1], equals(GitGutterDiffType.modified));
      expect(markers.containsKey(0), isFalse);
      expect(markers.containsKey(2), isFalse);
    });

    test('Deleted lines mark deleted triangle indicator', () {
      const base = 'line 1\nline 2\nline 3';
      const current = 'line 1\nline 3';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      // Line 2 was deleted, so marker is placed on line 1 of current text
      expect(markers[1], equals(GitGutterDiffType.deleted));
    });

    test('Delete at end marks last line as deleted', () {
      const base = 'line 1\nline 2\nline 3';
      const current = 'line 1\nline 2';
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers[1], equals(GitGutterDiffType.deleted));
    });

    test('CRLF line endings are handled transparently', () {
      const base = "a\r\nb\r\nc";
      const current = "a\r\nmodified b\r\nc";
      final markers = GitDiffHelper.computeLineDiff(base, current);
      expect(markers[1], equals(GitGutterDiffType.modified));
    });
  });

  group('ProjectProvider pasteToRoot Tests', () {
    late Directory tempDir;
    late ProjectProvider projectProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('paste_root_test_');
      final rootPath = tempDir.path;
      projectProvider = ProjectProvider();
      await projectProvider.openSpecificDirectory(rootPath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('canPaste is false initially', () {
      expect(projectProvider.canPaste, isFalse);
    });

    test('copy and pasteToRoot copies file to root directory', () async {
      final subDir = Directory(p.join(tempDir.path, 'sub'))..createSync();
      final srcFile = File(p.join(subDir.path, 'source.txt'))..writeAsStringSync('hello world');
      final fileItem = FileItem(
        path: srcFile.path,
        name: 'source.txt',
        isDirectory: false,
      );

      projectProvider.copy(fileItem);
      expect(projectProvider.canPaste, isTrue);

      await projectProvider.pasteToRoot();

      final destFile = File(p.join(tempDir.path, 'source.txt'));
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), equals('hello world'));
      expect(await srcFile.exists(), isTrue);
      expect(projectProvider.canPaste, isTrue);
    });

    test('cut and pasteToRoot moves file to root directory and clears cut state', () async {
      final subDir = Directory(p.join(tempDir.path, 'sub2'))..createSync();
      final srcFile = File(p.join(subDir.path, 'cut_target.txt'))..writeAsStringSync('move me');
      final fileItem = FileItem(
        path: srcFile.path,
        name: 'cut_target.txt',
        isDirectory: false,
      );

      projectProvider.cut(fileItem);
      expect(projectProvider.canPaste, isTrue);
      expect(projectProvider.isItemCut(srcFile.path), isTrue);

      await projectProvider.pasteToRoot();

      final destFile = File(p.join(tempDir.path, 'cut_target.txt'));
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), equals('move me'));
      expect(await srcFile.exists(), isFalse);
      expect(projectProvider.canPaste, isFalse);
      expect(projectProvider.cutItem, isNull);
    });
  });
}
