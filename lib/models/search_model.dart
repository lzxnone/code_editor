import 'package:flutter/foundation.dart';

enum SearchMode {
  text,
  fileName,
}

@immutable
class SearchOptions {
  final String query;
  final String replaceText;
  final bool caseSensitive;
  final bool wholeWord;
  final bool isRegex;
  final SearchMode mode;
  final bool isReplaceExpanded;

  const SearchOptions({
    this.query = '',
    this.replaceText = '',
    this.caseSensitive = false,
    this.wholeWord = false,
    this.isRegex = false,
    this.mode = SearchMode.text,
    this.isReplaceExpanded = false,
  });

  SearchOptions copyWith({
    String? query,
    String? replaceText,
    bool? caseSensitive,
    bool? wholeWord,
    bool? isRegex,
    SearchMode? mode,
    bool? isReplaceExpanded,
  }) {
    return SearchOptions(
      query: query ?? this.query,
      replaceText: replaceText ?? this.replaceText,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWord: wholeWord ?? this.wholeWord,
      isRegex: isRegex ?? this.isRegex,
      mode: mode ?? this.mode,
      isReplaceExpanded: isReplaceExpanded ?? this.isReplaceExpanded,
    );
  }

  /// 构建用于匹配的正则表达式，非法正则时返回 null
  RegExp? buildRegExp() {
    if (query.isEmpty) return null;
    try {
      String pattern = isRegex ? query : RegExp.escape(query);
      if (wholeWord) {
        pattern = '\\b$pattern\\b';
      }
      return RegExp(pattern, caseSensitive: caseSensitive, multiLine: false);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchOptions &&
        other.query == query &&
        other.replaceText == replaceText &&
        other.caseSensitive == caseSensitive &&
        other.wholeWord == wholeWord &&
        other.isRegex == isRegex &&
        other.mode == mode &&
        other.isReplaceExpanded == isReplaceExpanded;
  }

  @override
  int get hashCode => Object.hash(
        query,
        replaceText,
        caseSensitive,
        wholeWord,
        isRegex,
        mode,
        isReplaceExpanded,
      );
}

class LineMatch {
  final int lineNumber; // 1-indexed
  final String lineContent;
  final int matchStart; // 0-indexed within lineContent
  final int matchEnd;

  LineMatch({
    required this.lineNumber,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });

  String get matchedText {
    if (matchStart < 0 || matchEnd > lineContent.length || matchStart > matchEnd) {
      return '';
    }
    return lineContent.substring(matchStart, matchEnd);
  }

  LineMatch copyWith({
    int? lineNumber,
    String? lineContent,
    int? matchStart,
    int? matchEnd,
  }) {
    return LineMatch(
      lineNumber: lineNumber ?? this.lineNumber,
      lineContent: lineContent ?? this.lineContent,
      matchStart: matchStart ?? this.matchStart,
      matchEnd: matchEnd ?? this.matchEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LineMatch &&
        other.lineNumber == lineNumber &&
        other.lineContent == lineContent &&
        other.matchStart == matchStart &&
        other.matchEnd == matchEnd;
  }

  @override
  int get hashCode => Object.hash(lineNumber, lineContent, matchStart, matchEnd);
}

class FileSearchResult {
  final String filePath;
  final String relativePath;
  final String fileName;
  final List<LineMatch> matches;
  final bool isDirectory;
  bool isExpanded;

  FileSearchResult({
    required this.filePath,
    required this.relativePath,
    required this.fileName,
    required this.matches,
    this.isDirectory = false,
    this.isExpanded = true,
  });

  int get matchCount => matches.length;

  FileSearchResult copyWith({
    String? filePath,
    String? relativePath,
    String? fileName,
    List<LineMatch>? matches,
    bool? isDirectory,
    bool? isExpanded,
  }) {
    return FileSearchResult(
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      fileName: fileName ?? this.fileName,
      matches: matches ?? this.matches,
      isDirectory: isDirectory ?? this.isDirectory,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

enum SearchErrorCode {
  invalidRegex,
  projectDirNotFound,
}

class SearchResult {
  final String query;
  final List<FileSearchResult> fileResults;
  final int totalMatches;
  final int durationMs;
  final bool isFileNameSearch;
  final String? errorMessage;
  final SearchErrorCode? errorCode;

  const SearchResult({
    required this.query,
    required this.fileResults,
    required this.totalMatches,
    this.durationMs = 0,
    this.isFileNameSearch = false,
    this.errorMessage,
    this.errorCode,
  });

  const SearchResult.empty()
      : query = '',
        fileResults = const [],
        totalMatches = 0,
        durationMs = 0,
        isFileNameSearch = false,
        errorMessage = null,
        errorCode = null;

  const SearchResult.error(String message, {this.errorCode})
      : query = '',
        fileResults = const [],
        totalMatches = 0,
        durationMs = 0,
        isFileNameSearch = false,
        errorMessage = message;
}
