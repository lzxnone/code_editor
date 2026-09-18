import 'dart:async';
import 'dart:io';
import 'package:code_editor/models/search_model.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/services/project_search_service.dart';
import 'package:code_editor/utils/case_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class SearchProvider extends ChangeNotifier {
  SearchOptions _options = const SearchOptions();
  SearchResult _result = const SearchResult.empty();
  bool _isLoading = false;
  Timer? _debounceTimer;
  int _searchVersion = 0;
  String? _rootPath;

  SearchOptions get options => _options;
  SearchResult get result => _result;
  bool get isLoading => _isLoading;
  String get query => _options.query;
  String get replaceText => _options.replaceText;
  bool get isReplaceExpanded => _options.isReplaceExpanded;
  SearchMode get mode => _options.mode;
  bool get caseSensitive => _options.caseSensitive;
  bool get wholeWord => _options.wholeWord;
  bool get isRegex => _options.isRegex;
  bool get preserveCase => _options.preserveCase;

  double scrollOffset = 0.0;
  int _displayedFilesLimit = 20;
  final Map<String, int> _displayedMatchesLimits = {};
  final Map<String, bool> _fileExpandedStates = {};

  int get displayedFilesLimit => _displayedFilesLimit;

  void loadMoreFiles(int step) {
    _displayedFilesLimit += step;
    notifyListeners();
  }

  /// 一键解除分页限制，加载/展示全部匹配文件
  void loadAllFiles() {
    if (_result.fileResults.isNotEmpty) {
      _displayedFilesLimit = _result.fileResults.length;
      notifyListeners();
    }
  }

  /// 展开指定文件并加载展示其全部匹配行
  void expandAndLoadAllMatchesForFile(FileSearchResult fileResult) {
    fileResult.isExpanded = true;
    _fileExpandedStates[fileResult.filePath] = true;
    _displayedMatchesLimits[fileResult.filePath] = fileResult.matches.length;
    notifyListeners();
  }

  int getFileMatchesLimit(String filePath, int defaultSize) {
    return _displayedMatchesLimits[filePath] ?? defaultSize;
  }

  void loadMoreMatches(String filePath, int step, int defaultSize) {
    final cur = _displayedMatchesLimits[filePath] ?? defaultSize;
    _displayedMatchesLimits[filePath] = cur + step;
    notifyListeners();
  }

  void resetPagination() {
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
  }

  @visibleForTesting
  void setResultForTesting(SearchResult result) {
    for (final f in result.fileResults) {
      if (_fileExpandedStates.containsKey(f.filePath)) {
        f.isExpanded = _fileExpandedStates[f.filePath]!;
      }
    }
    _result = result;
    _isLoading = false;
    notifyListeners();
  }

  void bindRootPath(String? rootPath) {
    if (_rootPath != rootPath) {
      _rootPath = rootPath;
      if (_options.query.isNotEmpty && _rootPath != null && _rootPath!.isNotEmpty) {
        triggerSearch();
      }
    }
  }

  void setQuery(String newQuery) {
    if (_options.query == newQuery) return;
    _options = _options.copyWith(query: newQuery);
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
    _fileExpandedStates.clear();
    notifyListeners();
    _scheduleDebouncedSearch();
  }

  void setReplaceText(String newReplaceText) {
    if (_options.replaceText == newReplaceText) return;
    _options = _options.copyWith(replaceText: newReplaceText);
    notifyListeners();
  }

  void toggleReplaceExpanded() {
    _options = _options.copyWith(isReplaceExpanded: !_options.isReplaceExpanded);
    notifyListeners();
  }

  void setMode(SearchMode newMode) {
    if (_options.mode == newMode) return;
    _options = _options.copyWith(mode: newMode);
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
    _fileExpandedStates.clear();
    notifyListeners();
    triggerSearch();
  }

  void toggleCaseSensitive() {
    _options = _options.copyWith(caseSensitive: !_options.caseSensitive);
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
    notifyListeners();
    triggerSearch();
  }

  void toggleWholeWord() {
    _options = _options.copyWith(wholeWord: !_options.wholeWord);
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
    notifyListeners();
    triggerSearch();
  }

  void toggleRegex() {
    _options = _options.copyWith(isRegex: !_options.isRegex);
    scrollOffset = 0.0;
    _displayedFilesLimit = 20;
    _displayedMatchesLimits.clear();
    notifyListeners();
    triggerSearch();
  }

  void togglePreserveCase() {
    _options = _options.copyWith(preserveCase: !_options.preserveCase);
    notifyListeners();
  }

  void setPreserveCase(bool value) {
    if (_options.preserveCase == value) return;
    _options = _options.copyWith(preserveCase: value);
    notifyListeners();
  }

  void toggleFileExpanded(FileSearchResult file) {
    file.isExpanded = !file.isExpanded;
    _fileExpandedStates[file.filePath] = file.isExpanded;
    notifyListeners();
  }

  void collapseAll() {
    for (final f in _result.fileResults) {
      f.isExpanded = false;
      _fileExpandedStates[f.filePath] = false;
    }
    notifyListeners();
  }

  void expandAll() {
    for (final f in _result.fileResults) {
      f.isExpanded = true;
      _fileExpandedStates[f.filePath] = true;
    }
    notifyListeners();
  }

  void _scheduleDebouncedSearch() {
    _debounceTimer?.cancel();
    if (_options.query.trim().isEmpty) {
      _result = const SearchResult.empty();
      _isLoading = false;
      resetPagination();
      notifyListeners();
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      triggerSearch();
    });
  }

  Future<void> triggerSearch({bool keepPagination = false}) async {
    _debounceTimer?.cancel();
    final currentQuery = _options.query.trim();
    if (currentQuery.isEmpty || _rootPath == null || _rootPath!.isEmpty) {
      _result = const SearchResult.empty();
      _isLoading = false;
      resetPagination();
      notifyListeners();
      return;
    }

    final thisVersion = ++_searchVersion;
    _isLoading = true;
    if (!keepPagination) {
      resetPagination();
    }
    notifyListeners();

    try {
      final searchResult = await ProjectSearchService.instance.search(
        rootPath: _rootPath!,
        options: _options,
      );

      // 仅保留最新检索请求的结果，规避时序竞态
      if (thisVersion == _searchVersion) {
        // 恢复之前对同路径文件的展开/折叠状态偏好
        for (final f in searchResult.fileResults) {
          if (_fileExpandedStates.containsKey(f.filePath)) {
            f.isExpanded = _fileExpandedStates[f.filePath]!;
          }
        }
        _result = searchResult;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (thisVersion == _searchVersion) {
        _result = SearchResult.error(e.toString());
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 替换单行单处匹配项
  Future<bool> replaceSingleMatch({
    required FileSearchResult file,
    required LineMatch match,
    required TabProvider tabProvider,
  }) async {
    final cleanPath = p.normalize(file.filePath);
    final openTab = tabProvider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;

    try {
      String originalContent;
      if (openTab != null && openTab.isLoaded) {
        originalContent = openTab.content;
      } else {
        originalContent = await FileService.instance.readFileContent(cleanPath);
      }

      String replacement = _options.replaceText;
      if (_options.preserveCase) {
        replacement = CaseUtils.applyPreserveCase(
          original: match.matchedText,
          replacement: replacement,
        );
      }

      final updatedContent = ProjectSearchService.instance.replaceSingleMatchInContent(
        fileContent: originalContent,
        match: match,
        replacement: replacement,
      );

      if (openTab != null && openTab.isLoaded) {
        // 若在标签页中已打开，直接同步内存并置脏，避免与磁盘抢占覆盖
        openTab.content = updatedContent.replaceAll('\r\n', '\n');
        openTab.isModified = true;
        tabProvider.notifyListeners();
      } else {
        // 未打开的文件直接安全覆写磁盘
        final ioFile = File(cleanPath);
        await ioFile.writeAsString(updatedContent);
      }

      // 局部移除已替换的行匹配
      file.matches.remove(match);
      if (file.matches.isEmpty) {
        _result.fileResults.remove(file);
      }
      _updateTotalMatchesCount();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('替换单项失败: $e');
      return false;
    }
  }

  /// 替换单文件中的所有匹配项
  Future<int> replaceFileMatches({
    required FileSearchResult file,
    required TabProvider tabProvider,
  }) async {
    final regExp = _options.buildRegExp();
    if (regExp == null) return 0;

    final cleanPath = p.normalize(file.filePath);
    final openTab = tabProvider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;

    try {
      String originalContent;
      if (openTab != null && openTab.isLoaded) {
        originalContent = openTab.content;
      } else {
        originalContent = await FileService.instance.readFileContent(cleanPath);
      }

      final replacedCount = file.matches.length;
      final String updatedContent;
      if (_options.preserveCase) {
        updatedContent = originalContent.replaceAllMapped(regExp, (m) {
          final matched = m[0] ?? '';
          return CaseUtils.applyPreserveCase(
            original: matched,
            replacement: _options.replaceText,
          );
        });
      } else {
        updatedContent = ProjectSearchService.instance.replaceAllInContent(
          fileContent: originalContent,
          regExp: regExp,
          replacement: _options.replaceText,
        );
      }

      if (openTab != null && openTab.isLoaded) {
        openTab.content = updatedContent.replaceAll('\r\n', '\n');
        openTab.isModified = true;
        tabProvider.notifyListeners();
      } else {
        final ioFile = File(cleanPath);
        await ioFile.writeAsString(updatedContent);
      }

      _result.fileResults.remove(file);
      _updateTotalMatchesCount();
      notifyListeners();
      return replacedCount;
    } catch (e) {
      debugPrint('替换文件全部项失败: $e');
      return 0;
    }
  }

  /// 替换工程内所有文件中的所有匹配项
  Future<int> replaceAllMatches({
    required TabProvider tabProvider,
  }) async {
    final files = List<FileSearchResult>.from(_result.fileResults);
    int totalReplaced = 0;

    for (final file in files) {
      final count = await replaceFileMatches(
        file: file,
        tabProvider: tabProvider,
      );
      totalReplaced += count;
    }

    return totalReplaced;
  }

  void _updateTotalMatchesCount() {
    int count = 0;
    for (final f in _result.fileResults) {
      count += f.matches.length;
    }
    _result = SearchResult(
      query: _result.query,
      fileResults: _result.fileResults,
      totalMatches: count,
      durationMs: _result.durationMs,
      isFileNameSearch: _result.isFileNameSearch,
      errorMessage: _result.errorMessage,
      errorCode: _result.errorCode,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
