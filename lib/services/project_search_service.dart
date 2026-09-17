import 'dart:io';
import 'dart:isolate';
import 'package:code_editor/models/search_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ProjectSearchService {
  static final ProjectSearchService instance = ProjectSearchService._();
  ProjectSearchService._();

  static const Set<String> ignoredDirectories = {
    '.git',
    '.dart_tool',
    '.idea',
    '.vscode',
    'build',
    'node_modules',
    '.gradle',
    '.svn',
    '.hg',
    'dist',
    'target',
    'out',
    '__pycache__',
    '.vs',
    '.settings',
  };

  static const Set<String> binaryExtensions = {
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.bmp',
    '.mp3', '.mp4', '.wav', '.avi', '.mov', '.flac',
    '.zip', '.tar', '.gz', '.7z', '.rar', '.bz2',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.exe', '.dll', '.so', '.dylib', '.class', '.jar', '.apk', '.aab', '.bin',
    '.pyc', '.o', '.a', '.obj',
    '.ttf', '.otf', '.woff', '.woff2', '.eot',
  };

  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2MB

  /// 在后台 Isolate 中执行工程全文或文件名异步检索
  Future<SearchResult> search({
    required String rootPath,
    required SearchOptions options,
    int maxResults = 2000,
  }) async {
    final query = options.query.trim();
    if (query.isEmpty) {
      return const SearchResult.empty();
    }

    final regExp = options.buildRegExp();
    if (regExp == null) {
      return const SearchResult.error('无效的正则表达式', errorCode: SearchErrorCode.invalidRegex);
    }

    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      return const SearchResult.error('项目目录不存在', errorCode: SearchErrorCode.projectDirNotFound);
    }

    // 采用 Isolate.run 彻底隔离耗时文件读取与正则计算，UI 线程 0 阻塞
    try {
      return await Isolate.run(() => _executeSearchInIsolate(
            rootPath: rootPath,
            options: options,
            maxResults: maxResults,
          ));
    } catch (e) {
      debugPrint('ProjectSearchService 搜索异常: $e');
      return SearchResult.error(e.toString());
    }
  }

  static SearchResult _executeSearchInIsolate({
    required String rootPath,
    required SearchOptions options,
    required int maxResults,
  }) {
    final sw = Stopwatch()..start();
    final regExp = options.buildRegExp();
    if (regExp == null) {
      return const SearchResult.error('无效的正则表达式', errorCode: SearchErrorCode.invalidRegex);
    }

    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      return const SearchResult.error('项目目录不存在', errorCode: SearchErrorCode.projectDirNotFound);
    }

    final List<FileSearchResult> fileResults = [];
    int totalMatchCount = 0;

    void processDirectory(Directory dir) {
      final List<FileSystemEntity> entities;
      try {
        entities = dir.listSync(followLinks: false);
      } catch (_) {
        return;
      }

      for (final entity in entities) {
        if (totalMatchCount >= maxResults) return;

        final basename = p.basename(entity.path);

        if (entity is Directory) {
          if (ignoredDirectories.contains(basename) || basename.startsWith('.')) {
            continue;
          }
          if (options.mode == SearchMode.fileName) {
            final match = regExp.firstMatch(basename);
            if (match != null) {
              final relPath = p.relative(entity.path, from: rootPath).replaceAll('\\', '/');
              fileResults.add(FileSearchResult(
                filePath: entity.path,
                relativePath: relPath,
                fileName: basename,
                isDirectory: true,
                matches: [
                  LineMatch(
                    lineNumber: 1,
                    lineContent: basename,
                    matchStart: match.start,
                    matchEnd: match.end,
                  ),
                ],
              ));
              totalMatchCount++;
            }
          }
          processDirectory(entity);
        } else if (entity is File) {
          final ext = p.extension(basename).toLowerCase();
          if (binaryExtensions.contains(ext)) {
            continue;
          }

          final relPath = p.relative(entity.path, from: rootPath).replaceAll('\\', '/');

          if (options.mode == SearchMode.fileName) {
            // 文件名称匹配（仅对文件名/文件夹名本身匹配，不含上层相对路径）
            final match = regExp.firstMatch(basename);
            if (match != null) {
              fileResults.add(FileSearchResult(
                filePath: entity.path,
                relativePath: relPath,
                fileName: basename,
                isDirectory: false,
                matches: [
                  LineMatch(
                    lineNumber: 1,
                    lineContent: basename,
                    matchStart: match.start,
                    matchEnd: match.end,
                  ),
                ],
              ));
              totalMatchCount++;
            }
          } else {
            // 文本内容匹配
            try {
              final stat = entity.statSync();
              if (stat.size > maxFileSizeBytes) {
                continue;
              }

              final content = entity.readAsStringSync();
              final lines = content.split('\n');
              final List<LineMatch> lineMatches = [];

              for (var i = 0; i < lines.length; i++) {
                final line = lines[i].replaceAll('\r', '');
                final matches = regExp.allMatches(line);

                for (final m in matches) {
                  lineMatches.add(LineMatch(
                    lineNumber: i + 1,
                    lineContent: line,
                    matchStart: m.start,
                    matchEnd: m.end,
                  ));
                  totalMatchCount++;
                  if (totalMatchCount >= maxResults) break;
                }
                if (totalMatchCount >= maxResults) break;
              }

              if (lineMatches.isNotEmpty) {
                fileResults.add(FileSearchResult(
                  filePath: entity.path,
                  relativePath: relPath,
                  fileName: basename,
                  matches: lineMatches,
                ));
              }
            } catch (_) {
              // 忽略编码不可读等非文本异常文件
            }
          }
        }
      }
    }

    processDirectory(rootDir);
    sw.stop();

    return SearchResult(
      query: options.query,
      fileResults: fileResults,
      totalMatches: totalMatchCount,
      durationMs: sw.elapsedMilliseconds,
      isFileNameSearch: options.mode == SearchMode.fileName,
    );
  }

  /// 替换单行匹配项并返回更新后的整篇文本内容
  String replaceSingleMatchInContent({
    required String fileContent,
    required LineMatch match,
    required String replacement,
  }) {
    final hasCrLf = fileContent.contains('\r\n');
    final normalized = fileContent.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');

    final lineIndex = match.lineNumber - 1;
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return fileContent;
    }

    final targetLine = lines[lineIndex];
    if (match.matchStart >= 0 &&
        match.matchEnd <= targetLine.length &&
        match.matchStart <= match.matchEnd) {
      final updatedLine = targetLine.replaceRange(
        match.matchStart,
        match.matchEnd,
        replacement,
      );
      lines[lineIndex] = updatedLine;
    }

    final result = lines.join('\n');
    return hasCrLf ? result.replaceAll('\n', '\r\n') : result;
  }

  /// 替换文本中所有匹配项并返回更新后的内容
  String replaceAllInContent({
    required String fileContent,
    required RegExp regExp,
    required String replacement,
  }) {
    return fileContent.replaceAll(regExp, replacement);
  }
}
