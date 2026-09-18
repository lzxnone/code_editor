import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/services/project_history_service.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/services/file_watcher_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class EditorNavigationTarget {
  final String filePath;
  final int line; // 0-based
  final int? column; // 0-based
  final int? length;
  final int timestamp;

  EditorNavigationTarget({
    required this.filePath,
    required this.line,
    this.column,
    this.length,
  }) : timestamp = DateTime.now().microsecondsSinceEpoch;
}

class TabProvider extends ChangeNotifier {
  List<EditorTabItem> _openTabs = [];
  String? _activeFilePath;
  bool _isModified = false;
  Future<bool> Function()? _saveHandler;
  EditorNavigationTarget? _navigationTarget;

  ProjectProvider? _projectProvider;

  List<EditorTabItem> get openTabs => _openTabs;
  EditorNavigationTarget? get navigationTarget => _navigationTarget;
  EditorTabItem? get activeTab {
    if (_activeFilePath == null) return null;
    final index = _openTabs.indexWhere((tab) => p.equals(tab.path, _activeFilePath!));
    return index != -1 ? _openTabs[index] : null;
  }

  void navigateTo({
    required String filePath,
    required int line,
    int? column,
    int? length,
  }) {
    _navigationTarget = EditorNavigationTarget(
      filePath: p.normalize(filePath),
      line: line,
      column: column,
      length: length,
    );
    notifyListeners();
  }

  void clearNavigationTarget() {
    _navigationTarget = null;
  }

  String? get currentFilePath => _activeFilePath;
  bool get isModified => activeTab?.isModified ?? _isModified;
  bool get hasUnsavedChanges => _isModified || _openTabs.any((t) => t.isModified);

  void bindProjectProvider(ProjectProvider projectProvider) {
    if (_projectProvider == projectProvider) return;
    _projectProvider = projectProvider;
    projectProvider.onEntityRenamed = handleEntityRenamed;
    projectProvider.onEntityDeleted = handleEntityDeleted;
    projectProvider.onProjectChanged = handleProjectChanged;
    projectProvider.onExternalFileModified = handleExternalFileModified;
    projectProvider.onExternalFileDeleted = handleExternalFileDeleted;
  }

  GitProvider? _gitProvider;

  void bindGitProvider(GitProvider gitProvider) {
    _gitProvider = gitProvider;
  }

  bool isFileSelected(String path) {
    if (_activeFilePath == null) return false;
    return p.equals(_activeFilePath!, path);
  }

  Future<void> init() async {
    await _loadTabsFromHistory();
  }

  Future<void> _loadTabsFromHistory() async {
    try {
      final lastHistory = await ProjectHistoryService.instance.getLastHistory();
      if (lastHistory == null) return;
      await handleProjectChanged(
        lastHistory.rootPath,
        lastHistory.openFilePaths,
        lastHistory.lastOpenedFilePath,
      );
    } catch (e) {
      debugPrint('加载标签页历史失败: $e');
    }
  }

  Future<void> handleProjectChanged(
    String? rootPath,
    List<String> openFilePaths,
    String? lastOpenedFilePath,
  ) async {
    final List<EditorTabItem> loadedTabs = [];

    for (final filePath in openFilePaths) {
      final cleanFilePath = p.normalize(filePath.trim());
      if (await FileService.instance.entityExists(cleanFilePath)) {
        loadedTabs.add(EditorTabItem(
          path: cleanFilePath,
          isModified: false,
        ));
      }
    }

    if (loadedTabs.isEmpty && lastOpenedFilePath != null && lastOpenedFilePath.trim().isNotEmpty) {
      final cleanLast = p.normalize(lastOpenedFilePath.trim());
      final wasExplicitlyClosed = openFilePaths.isNotEmpty && !openFilePaths.any((pStr) => p.equals(p.normalize(pStr), cleanLast));
      if (!wasExplicitlyClosed && await FileService.instance.entityExists(cleanLast)) {
        loadedTabs.add(EditorTabItem(
          path: cleanLast,
          isModified: false,
        ));
      }
    }

    _openTabs = loadedTabs;

    if (lastOpenedFilePath != null && _openTabs.any((t) => p.equals(t.path, lastOpenedFilePath.trim()))) {
      _activeFilePath = _openTabs.firstWhere((t) => p.equals(t.path, lastOpenedFilePath.trim())).path;
    } else if (_openTabs.isNotEmpty) {
      _activeFilePath = _openTabs.first.path;
    } else {
      _activeFilePath = null;
    }

    _isModified = false;
    notifyListeners();
  }

  void handleEntityRenamed(String oldNormalized, String targetPath) {
    for (int i = 0; i < _openTabs.length; i++) {
      final tabPath = _openTabs[i].path;
      if (p.equals(tabPath, oldNormalized)) {
        _openTabs[i] = EditorTabItem(
          path: targetPath,
          content: _openTabs[i].content,
          originalContent: _openTabs[i].originalContent,
          isModified: _openTabs[i].isModified,
          isLoaded: _openTabs[i].isLoaded,
          verticalScrollOffset: _openTabs[i].verticalScrollOffset,
          horizontalScrollOffset: _openTabs[i].horizontalScrollOffset,
        );
      } else if (p.isWithin(oldNormalized, tabPath)) {
        final rel = p.relative(tabPath, from: oldNormalized);
        final newChildPath = p.normalize(p.join(targetPath, rel));
        _openTabs[i] = EditorTabItem(
          path: newChildPath,
          content: _openTabs[i].content,
          originalContent: _openTabs[i].originalContent,
          isModified: _openTabs[i].isModified,
          isLoaded: _openTabs[i].isLoaded,
          verticalScrollOffset: _openTabs[i].verticalScrollOffset,
          horizontalScrollOffset: _openTabs[i].horizontalScrollOffset,
        );
      }
    }

    if (_activeFilePath != null) {
      if (p.equals(_activeFilePath!, oldNormalized)) {
        _activeFilePath = targetPath;
      } else if (p.isWithin(oldNormalized, _activeFilePath!)) {
        final rel = p.relative(_activeFilePath!, from: oldNormalized);
        _activeFilePath = p.normalize(p.join(targetPath, rel));
      }
    }

    _persistTabsHistory();
    notifyListeners();
  }

  void handleEntityDeleted(String oldNormalized) {
    _openTabs.removeWhere((tab) => p.equals(tab.path, oldNormalized) || p.isWithin(oldNormalized, tab.path));
    if (_activeFilePath != null && (p.equals(_activeFilePath!, oldNormalized) || p.isWithin(oldNormalized, _activeFilePath!))) {
      _activeFilePath = _openTabs.isNotEmpty ? _openTabs.first.path : null;
      _isModified = activeTab?.isModified ?? false;
    }
    _persistTabsHistory();
    notifyListeners();
  }

  /// 处理外部文件内容被修改事件
  Future<void> handleExternalFileModified(String modifiedPath) async {
    final cleanPath = p.normalize(modifiedPath);
    final tabIndex = _openTabs.indexWhere((t) => p.equals(t.path, cleanPath));
    if (tabIndex == -1) return;
    final tab = _openTabs[tabIndex];

    try {
      if (!await FileService.instance.entityExists(cleanPath)) return;
      final raw = await FileService.instance.readFileContent(cleanPath);
      final diskContent = raw.replaceAll('\r\n', '\n');

      // 内容无实质改变则跳过
      if (tab.content == diskContent) {
        return;
      }

      if (!tab.isModified) {
        // 未修改文件：静默无感热重载
        tab.content = diskContent;
        tab.originalContent = diskContent;
        tab.isLoaded = true;
        tab.hasExternalConflict = false;
        notifyListeners();
      } else {
        // 已修改文件：发生外部冲突，标记冲突以通知 UI 弹出提示，严禁直接覆盖
        tab.hasExternalConflict = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('处理外部文件变动失败: $e');
    }
  }

  /// 解决外部文件冲突
  Future<void> resolveConflict(EditorTabItem tab, {required bool reloadFromDisk}) async {
    tab.hasExternalConflict = false;
    if (reloadFromDisk) {
      try {
        final raw = await FileService.instance.readFileContent(tab.path);
        final diskContent = raw.replaceAll('\r\n', '\n');
        tab.content = diskContent;
        tab.originalContent = diskContent;
        tab.isModified = false;
        if (_activeFilePath == tab.path) {
          _isModified = false;
        }
      } catch (e) {
        debugPrint('重载外部文件失败: $e');
      }
    }
    notifyListeners();
  }

  /// 处理外部文件被删除事件
  void handleExternalFileDeleted(String deletedPath) {
    final cleanPath = p.normalize(deletedPath);
    final affectedTabs = _openTabs
        .where((t) {
          final tClean = p.normalize(t.path);
          return tClean == cleanPath || p.isWithin(cleanPath, tClean);
        })
        .toList();

    for (final tab in affectedTabs) {
      if (!tab.isModified) {
        // 未修改的文件安全自动关闭
        _openTabs.remove(tab);
        if (_activeFilePath == tab.path) {
          _activeFilePath = _openTabs.isNotEmpty ? _openTabs.first.path : null;
          _isModified = activeTab?.isModified ?? false;
        }
      } else {
        // 已修改的文件保留在标签栏防止丢代码，仅标记磁盘已被删除
        tab.isDeletedOnDisk = true;
      }
    }
    _persistTabsHistory();
    notifyListeners();
  }

  Future<void> _persistTabsHistory() async {
    final root = _projectProvider?.rootPath;
    if (root != null) {
      final openPaths = _openTabs.map((t) => t.path).toList();
      await ProjectHistoryService.instance.recordHistory(
        rootPath: root,
        lastOpenedFilePath: _activeFilePath,
        openDirectoryPaths: _projectProvider?.openDirectoryPaths ?? const [],
        openFilePaths: openPaths,
      );
    }
  }

  @visibleForTesting
  void setOpenTabsForTesting(List<EditorTabItem> tabs, {String? activePath}) {
    _openTabs = List.from(tabs);
    _activeFilePath = activePath ?? (_openTabs.isNotEmpty ? _openTabs.first.path : null);
    _isModified = activeTab?.isModified ?? false;
    notifyListeners();
  }

  @visibleForTesting
  void setModifiedForTesting(bool modified) {
    _isModified = modified;
    if (activeTab != null) {
      activeTab!.isModified = modified;
    }
    notifyListeners();
  }

  void setModified(bool modified) {
    if (isModified == modified) return;
    if (activeTab != null) {
      activeTab!.isModified = modified;
    }
    _isModified = modified;
    notifyListeners();
  }

  void updateActiveTabContent(String content, {bool? isModified}) {
    final tab = activeTab;
    if (tab != null) {
      final normalized = content.replaceAll('\r\n', '\n');
      tab.content = normalized;
      if (isModified != null) {
        tab.isModified = isModified;
      } else {
        tab.isModified = normalized != tab.originalContent.replaceAll('\r\n', '\n');
      }
      _isModified = tab.isModified;
      notifyListeners();
    }
  }

  void registerSaveHandler(Future<bool> Function()? handler) {
    _saveHandler = handler;
  }

  Future<void> selectFile(FileItem item) async {
    if (item.isDirectory) return;
    await openFile(item.path);
  }

  Future<void> openFile(String path, {String? content}) async {
    final cleanPath = p.normalize(path.trim());
    final existingIndex = _openTabs.indexWhere((tab) => p.equals(tab.path, cleanPath));
    if (existingIndex != -1) {
      _activeFilePath = _openTabs[existingIndex].path;
      _isModified = _openTabs[existingIndex].isModified;
    } else {
      String initialContent = content ?? '';
      bool loaded = false;
      if (content != null) {
        initialContent = initialContent.replaceAll('\r\n', '\n');
        loaded = true;
      } else {
        try {
          if (await FileService.instance.entityExists(cleanPath)) {
            final raw = await FileService.instance.readFileContent(cleanPath);
            initialContent = raw.replaceAll('\r\n', '\n');
            loaded = true;
          }
        } catch (_) {}
      }
      final tab = EditorTabItem(
        path: cleanPath,
        content: initialContent,
        originalContent: initialContent,
        isModified: false,
        isLoaded: loaded,
      );
      _openTabs.add(tab);
      _activeFilePath = cleanPath;
      _isModified = false;
    }

    await _persistTabsHistory();
    notifyListeners();
  }

  Future<bool> closeTab(BuildContext context, int index) async {
    if (index < 0 || index >= _openTabs.length) return false;
    final tab = _openTabs[index];

    if (tab.isModified) {
      final result = await DialogUtils.showSavePromptDialog(
        context,
        fileName: tab.name,
      );
      switch (result) {
        case SavePromptResult.save:
          final saved = await saveTab(tab);
          if (!saved) return false;
          break;
        case SavePromptResult.discard:
          break;
        case SavePromptResult.cancel:
          return false;
      }
    }

    final wasActive = _activeFilePath != null && p.equals(tab.path, _activeFilePath!);
    _openTabs.removeAt(index);

    if (wasActive) {
      if (_openTabs.isEmpty) {
        _activeFilePath = null;
        _isModified = false;
      } else {
        final newIndex = index.clamp(0, _openTabs.length - 1);
        _activeFilePath = _openTabs[newIndex].path;
        _isModified = _openTabs[newIndex].isModified;
      }
    }

    await _persistTabsHistory();
    notifyListeners();
    return true;
  }

  /// 根据文件路径安全关闭指定标签页（避免由于并发动画或索引错位导致的越界异常）
  Future<bool> closeTabByPath(BuildContext context, String path) async {
    final cleanPath = p.normalize(path.trim());
    final index = _openTabs.indexWhere((t) => p.equals(t.path, cleanPath));
    if (index == -1) return false;
    return closeTab(context, index);
  }

  /// 关闭所有打开的标签页
  Future<bool> closeAllTabs(BuildContext context) async {
    if (_openTabs.isEmpty) return true;
    final canProceed = await checkUnsavedChanges(context);
    if (!canProceed) return false;

    _openTabs.clear();
    _activeFilePath = null;
    _isModified = false;
    await _persistTabsHistory();
    notifyListeners();
    return true;
  }

  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _openTabs.length) return;
    if (newIndex < 0 || newIndex >= _openTabs.length) return;
    final item = _openTabs.removeAt(oldIndex);
    _openTabs.insert(newIndex, item);
    await _persistTabsHistory();
    notifyListeners();
  }

  Future<bool> saveTab(EditorTabItem tab) async {
    try {
      FileWatcherService.instance.markRecentlySaved(tab.path);
      if (_activeFilePath != null && p.equals(tab.path, _activeFilePath!) && _saveHandler != null) {
        final ok = await _saveHandler!();
        if (ok) {
          tab.originalContent = tab.content;
          tab.isModified = false;
          _isModified = false;
          _gitProvider?.refresh();
          notifyListeners();
        }
        return ok;
      }

      await FileService.instance.saveFile(tab.path, tab.content);
      tab.originalContent = tab.content;
      tab.isModified = false;
      if (_activeFilePath != null && p.equals(tab.path, _activeFilePath!)) {
        _isModified = false;
      }
      _gitProvider?.refresh();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('保存文件失败: $e');
      return false;
    }
  }

  Future<bool> saveCurrentFile() async {
    final tab = activeTab;
    if (tab != null) {
      return await saveTab(tab);
    }
    if (_saveHandler != null) {
      return await _saveHandler!();
    }
    return false;
  }

  Future<bool> saveAllFiles() async {
    if (_openTabs.isEmpty) {
      return await saveCurrentFile();
    }
    bool allSuccess = true;
    for (final tab in _openTabs) {
      if (tab.isModified) {
        FileWatcherService.instance.markRecentlySaved(tab.path);
        final ok = await saveTab(tab);
        if (!ok) allSuccess = false;
      }
    }
    notifyListeners();
    return allSuccess;
  }

  /// 检查是否有未保存的更改；若有脏文件则弹出确认弹窗
  Future<bool> checkUnsavedChanges(BuildContext context) async {
    final dirtyTabs = _openTabs.where((t) => t.isModified).toList();
    if (dirtyTabs.isEmpty && !_isModified) {
      return true;
    }

    final result = await DialogUtils.showSaveAllPromptDialog(context);
    switch (result) {
      case SavePromptResult.save:
        final saved = await saveAllFiles();
        if (saved && context.mounted) {
          final l10n = AppLocalizations.of(context);
          DialogUtils.showSuccessToast(context, l10n?.saveAllSuccess ?? '所有文件已保存');
        }
        return saved;

      case SavePromptResult.discard:
        return true;

      case SavePromptResult.cancel:
        return false;
    }
  }
}
