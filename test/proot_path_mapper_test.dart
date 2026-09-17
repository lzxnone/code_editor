import 'dart:io';
import 'package:code_editor/services/lsp/cpp_project_helper.dart';
import 'package:code_editor/services/lsp/proot_path_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PRootPathMapper Tests', () {
    test('toGuestUri maps subpath within workspaceRoot to file:///workspace/...', () {
      final guestUri = PRootPathMapper.toGuestUri(
        '/data/data/com.example/files/workspace/src/main.c',
        '/data/data/com.example/files/workspace',
      );
      expect(guestUri, equals('file:///workspace/src/main.c'));
    });

    test('toGuestUri maps root directory itself to file:///workspace', () {
      final guestUri = PRootPathMapper.toGuestUri(
        '/data/data/com.example/files/workspace',
        '/data/data/com.example/files/workspace',
      );
      expect(guestUri, equals('file:///workspace'));
    });

    test('toGuestUri leaves path outside workspaceRoot with file:/// scheme', () {
      final guestUri = PRootPathMapper.toGuestUri(
        '/system/etc/hosts',
        '/data/data/com.example/files/workspace',
      );
      expect(guestUri, equals('file:///system/etc/hosts'));
    });

    test('fromGuestUriToHostPath restores guest URI to host absolute path', () {
      final hostPath = PRootPathMapper.fromGuestUriToHostPath(
        'file:///workspace/src/main.c',
        '/data/data/com.example/files/workspace',
      );
      expect(hostPath.replaceAll('\\', '/'), equals('/data/data/com.example/files/workspace/src/main.c'));
    });

    test('fromGuestUriToHostPath restores root /workspace', () {
      final hostPath = PRootPathMapper.fromGuestUriToHostPath(
        'file:///workspace',
        '/data/data/com.example/files/workspace',
      );
      expect(hostPath.replaceAll('\\', '/'), equals('/data/data/com.example/files/workspace'));
    });

    test('fromGuestUriToHostPath handles external file:/// URIs', () {
      final hostPath = PRootPathMapper.fromGuestUriToHostPath(
        'file:///system/etc/hosts',
        '/data/data/com.example/files/workspace',
      );
      expect(hostPath.replaceAll('\\', '/'), equals('/system/etc/hosts'));
    });

    test('toGuestPath maps host workspace and subpath to container absolute path', () {
      final guestPath = PRootPathMapper.toGuestPath(
        '/data/data/com.example/files/workspace/src/main.c',
        '/data/data/com.example/files/workspace',
      );
      expect(guestPath, equals('/workspace/src/main.c'));

      final guestRoot = PRootPathMapper.toGuestPath(
        '/data/data/com.example/files/workspace',
        '/data/data/com.example/files/workspace',
      );
      expect(guestRoot, equals('/workspace'));
    });
  });

  group('CppProjectHelper Tests', () {
    late Directory tempProjectDir;

    setUp(() {
      tempProjectDir = Directory.systemTemp.createTempSync('cpp_helper_test_');
    });

    tearDown(() {
      if (tempProjectDir.existsSync()) {
        tempProjectDir.deleteSync(recursive: true);
      }
    });

    test('Do nothing if compile_commands.json already exists in root', () async {
      final existing = File(p.join(tempProjectDir.path, 'compile_commands.json'));
      existing.writeAsStringSync('[]');

      await CppProjectHelper.ensureCompileFlags(tempProjectDir.path);

      final flagsFile = File(p.join(tempProjectDir.path, 'compile_flags.txt'));
      expect(flagsFile.existsSync(), isFalse);
    });

    test('Generates .clangd when build/compile_commands.json exists', () async {
      final buildDir = Directory(p.join(tempProjectDir.path, 'build'))..createSync();
      File(p.join(buildDir.path, 'compile_commands.json')).writeAsStringSync('[]');

      await CppProjectHelper.ensureCompileFlags(tempProjectDir.path);

      final clangdFile = File(p.join(tempProjectDir.path, '.clangd'));
      expect(clangdFile.existsSync(), isTrue);
      expect(clangdFile.readAsStringSync(), contains('CompilationDatabase: build'));
    });

    test('Auto scans header directories and generates compile_flags.txt with -I and -std=c++17', () async {
      // Create include/, src/, and ggml/include/
      final incDir = Directory(p.join(tempProjectDir.path, 'include'))..createSync();
      final srcDir = Directory(p.join(tempProjectDir.path, 'src'))..createSync();
      final ggmlIncDir = Directory(p.join(tempProjectDir.path, 'ggml', 'include'))..createSync(recursive: true);

      // Add dummy headers
      File(p.join(incDir.path, 'llama.h')).writeAsStringSync('#pragma once');
      File(p.join(srcDir.path, 'llama-impl.h')).writeAsStringSync('#pragma once');
      File(p.join(ggmlIncDir.path, 'ggml.h')).writeAsStringSync('#pragma once');

      await CppProjectHelper.ensureCompileFlags(tempProjectDir.path);

      final flagsFile = File(p.join(tempProjectDir.path, 'compile_flags.txt'));
      expect(flagsFile.existsSync(), isTrue);

      final content = flagsFile.readAsStringSync();
      expect(content, contains('-Iinclude'));
      expect(content, contains('-Isrc'));
      expect(content, contains('-Iggml/include'));
      expect(content, contains('-xc++'));
      expect(content, contains('-std=c++17'));
    });
  });
}
