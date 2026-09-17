import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// C/C++ 工程头文件搜索路径与编译数据库辅助器
///
/// 当用户打开 CMake 或普通 C/C++ 工程时，若缺少 compile_commands.json，
/// clangd 默认仅在单文件所在目录与系统库中搜索头文件，导致多目录项目（如 include/、src/、common/）
/// 中相互引用的头文件报错“file not found”。
/// 本类负责在启动 clangd 前：
/// 1. 检查是否存在 compile_commands.json、compile_flags.txt 或 .clangd，若存在则绝不覆盖；
/// 2. 检查 build/、out/ 等子构建目录下是否有 compile_commands.json，若有则自动生成 .clangd 配置指向该目录；
/// 3. 若均不存在，自动扫描项目下包含头文件的常见源码目录，推导并生成轻量合理的 compile_flags.txt。
class CppProjectHelper {
  const CppProjectHelper._();

  static const Set<String> _ignoredDirNames = {
    '.git',
    '.vscode',
    '.idea',
    '.dart_tool',
    'build',
    'out',
    'dist',
    'bin',
    'obj',
    'node_modules',
    'cache',
    'tmp',
  };

  static const Set<String> _headerExtensions = {
    '.h',
    '.hpp',
    '.hxx',
    '.hh',
    '.inl',
  };

  /// 确保指定工作区根目录下具备 clangd 编译配置
  static Future<void> ensureCompileFlags(String workspaceRoot) async {
    if (workspaceRoot.isEmpty) return;
    final rootDir = Directory(workspaceRoot);
    if (!rootDir.existsSync()) return;

    // 1. 若项目根目录已有配置，直接返回
    final rootCompileCommands = File(p.join(workspaceRoot, 'compile_commands.json'));
    final rootCompileFlags = File(p.join(workspaceRoot, 'compile_flags.txt'));
    final rootClangd = File(p.join(workspaceRoot, '.clangd'));

    if (rootCompileCommands.existsSync() ||
        rootCompileFlags.existsSync() ||
        rootClangd.existsSync()) {
      return;
    }

    // 2. 检查常见构建输出子目录下是否存在 compile_commands.json
    final candidateBuildDirs = ['build', 'out', 'cmake-build-debug', 'cmake-build-release'];
    for (final buildDirName in candidateBuildDirs) {
      final candidateFile = File(p.join(workspaceRoot, buildDirName, 'compile_commands.json'));
      if (candidateFile.existsSync()) {
        try {
          final content = 'CompileFlags:\n  CompilationDatabase: $buildDirName\n';
          rootClangd.writeAsStringSync(content, flush: true);
          debugPrint('[CppProjectHelper] 检测到 $buildDirName/compile_commands.json，已生成 .clangd 映射');
          return;
        } catch (e) {
          debugPrint('[CppProjectHelper] 写入 .clangd 失败: $e');
        }
      }
    }

    // 3. 扫描项目目录，收集包含头文件的目录
    final relativeIncludeDirs = <String>{};
    _scanHeaderDirs(rootDir, rootDir, relativeIncludeDirs, currentDepth: 0, maxDepth: 3);

    if (relativeIncludeDirs.isEmpty) return;

    // 排序：常用顶级目录优先展示
    final sortedDirs = relativeIncludeDirs.toList()
      ..sort((a, b) {
        int score(String path) {
          if (path == 'include') return 0;
          if (path == 'src') return 1;
          if (path == 'common') return 2;
          if (path.endsWith('/include')) return 3;
          if (path.endsWith('/src')) return 4;
          return 5;
        }

        final scoreA = score(a);
        final scoreB = score(b);
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        return a.compareTo(b);
      });

    final buffer = StringBuffer();
    for (final dir in sortedDirs) {
      buffer.writeln('-I$dir');
    }
    buffer.writeln('-xc++');
    buffer.writeln('-std=c++17');

    try {
      rootCompileFlags.writeAsStringSync(buffer.toString(), flush: true);
      debugPrint('[CppProjectHelper] 已为工程自动生成 compile_flags.txt (${sortedDirs.length} 个头文件路径)');
    } catch (e) {
      debugPrint('[CppProjectHelper] 写入 compile_flags.txt 异常: $e');
    }
  }

  static void _scanHeaderDirs(
    Directory root,
    Directory current,
    Set<String> result, {
    required int currentDepth,
    required int maxDepth,
  }) {
    if (currentDepth > maxDepth) return;

    try {
      final entries = current.listSync(followLinks: false);
      bool dirHasHeader = false;

      final subDirs = <Directory>[];
      for (final entry in entries) {
        if (entry is File) {
          final ext = p.extension(entry.path).toLowerCase();
          if (_headerExtensions.contains(ext)) {
            dirHasHeader = true;
          }
        } else if (entry is Directory) {
          final dirName = p.basename(entry.path);
          if (!dirName.startsWith('.') && !_ignoredDirNames.contains(dirName.toLowerCase())) {
            subDirs.add(entry);
          }
        }
      }

      if (dirHasHeader) {
        final rel = p.relative(current.path, from: root.path).replaceAll('\\', '/');
        if (rel.isNotEmpty && rel != '.') {
          result.add(rel);
        }
      }

      for (final sub in subDirs) {
        _scanHeaderDirs(root, sub, result, currentDepth: currentDepth + 1, maxDepth: maxDepth);
      }
    } catch (_) {}
  }
}
