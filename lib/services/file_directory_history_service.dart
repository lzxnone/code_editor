import 'package:code_editor/models/file_directory_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileDirectoryHistoryService {
  static final FileDirectoryHistoryService instance = FileDirectoryHistoryService._();
  FileDirectoryHistoryService._();

  static const String _keyHistory = 'file_directory_history';
  static const int _maxHistoryCount = 15;

  //记录
  Future<void> recordHistory({
    required String rootPath,
    String? lastOpenedFilePath,
    List<String>? openDirectoryPaths,
    List<String>? openFilePaths,
  }) async {
    final cleanPath = rootPath.trim();
    if(cleanPath.isEmpty) return;

    List<FileDirectoryHistory> history = await getFullHistory();

    final existingIndex = history.indexWhere((item) => item.rootPath == cleanPath);
    String? resolvedFile = lastOpenedFilePath;
    List<String>? resolvedOpenDirs = openDirectoryPaths;
    List<String>? resolvedOpenFiles = openFilePaths;

    if(existingIndex != -1) {
      resolvedFile ??= history[existingIndex].lastOpenedFilePath;
      resolvedOpenDirs ??= history[existingIndex].openDirectoryPaths;
      resolvedOpenFiles ??= history[existingIndex].openFilePaths;
      history.removeAt(existingIndex);
    }

    history.insert(
      0,
      FileDirectoryHistory(
        rootPath: cleanPath,
        lastOpenedFilePath: resolvedFile,
        openDirectoryPaths: resolvedOpenDirs ?? const [],
        openFilePaths: resolvedOpenFiles ?? const [],
      ),
    );

    if(history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    await _saveHistoryList(history);
  }

  //获取完整历史
  Future<List<FileDirectoryHistory>> getFullHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyHistory) ?? [];
    return rawList.map((jsonStr) => FileDirectoryHistory.fromJson(jsonStr)).toList();
  }

  //获取最近历史
  Future<FileDirectoryHistory?> getLastHistory() async {
    final history = await getFullHistory();
    return history.isNotEmpty ? history.first : null;
  }

  //删除指定的历史
  Future<void> removeHistory(String path) async {
    List<FileDirectoryHistory> history = await getFullHistory();
    history.removeWhere((item) => item.rootPath == path);
    await _saveHistoryList(history);
  }

  //清空历史
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  Future<void> _saveHistoryList(List<FileDirectoryHistory> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((item) => item.toJson()).toList();
    await prefs.setStringList(_keyHistory, jsonList);
  }
}