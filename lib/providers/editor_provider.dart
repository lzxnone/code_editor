import 'package:code_editor/models/file_directory_history.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/services/file_directory_history_service.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class EditorProvider extends ChangeNotifier {
  FileDirectoryHistory _history = const FileDirectoryHistory(
    rootPath: null,
    lastOpenedFilePath: "未命名",
  );
  List<FileItem> _items = [];
  bool _isLoading = false;
  FileItem? _cutItem;
  FileItem? _copiedItem;

  FileDirectoryHistory get history => _history;
  String? get rootPath => _history.rootPath;
  String? get currentFilePath => _history.lastOpenedFilePath;
  List<String> get openDirectoryPaths => _history.openDirectoryPaths;
  List<FileItem> get items => _items;
  bool get isLoading => _isLoading;
  FileItem? get cutItem => _cutItem;
  FileItem? get copiedItem => _copiedItem;
  bool get canPaste => _cutItem != null || _copiedItem != null;

  bool isFileSelected(String path) {
    if (currentFilePath == null) return false;
    return currentFilePath == path || currentFilePath!.trim() == path.trim();
  }

  bool isItemCut(String path) {
    if (_cutItem == null) return false;
    return _cutItem!.path == path || _cutItem!.path.trim() == path.trim();
  }

  Future<void> init() async {
    await _loadProjectFromHistory();
  }

  Future<void> _loadProjectFromHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final lastHistory = await FileDirectoryHistoryService.instance.getLastHistory();
      if (lastHistory == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final path = lastHistory.rootPath;
      final cleanPath = (path != null && path.trim().isNotEmpty) ? p.normalize(path.trim()) : null;
      final validOpenPaths = cleanPath == null
          ? <String>[]
          : lastHistory.openDirectoryPaths
              .map((e) => p.normalize(e.trim()))
              .where((e) => e != cleanPath && p.isWithin(cleanPath, e))
              .toList();

      List<FileItem> items = cleanPath != null
          ? await FileService.instance.buildTree(
              cleanPath,
              openDirectoryPaths: validOpenPaths,
            )
          : [];

      _items = items;
      _history = FileDirectoryHistory(
        rootPath: cleanPath,
        lastOpenedFilePath: lastHistory.lastOpenedFilePath,
        openDirectoryPaths: validOpenPaths,
      );
    } catch (e) {
      debugPrint('加载项目历史失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openDirectory() async {
    try {
      final String? selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        return;
      }

      final cleanPath = p.normalize(selectedPath.trim());
      final currentRoot = _history.rootPath != null ? p.normalize(_history.rootPath!) : null;
      final isSameRoot = currentRoot != null && cleanPath == currentRoot;

      await FileDirectoryHistoryService.instance.recordHistory(
        rootPath: cleanPath,
        lastOpenedFilePath: isSameRoot ? _history.lastOpenedFilePath : null,
        openDirectoryPaths: isSameRoot ? _history.openDirectoryPaths : const [],
      );

      _cutItem = null;
      _copiedItem = null;

      await _loadProjectFromHistory();
    } catch (e) {
      debugPrint('打开文件夹失败: $e');
    }
  }

  Future<void> switchProject(FileDirectoryHistory selectedHistory) async {
    final selectedRoot = selectedHistory.rootPath;
    if (selectedRoot == null || selectedRoot.trim().isEmpty) return;

    await FileDirectoryHistoryService.instance.recordHistory(
      rootPath: selectedRoot,
      lastOpenedFilePath: selectedHistory.lastOpenedFilePath,
      openDirectoryPaths: selectedHistory.openDirectoryPaths,
    );

    _cutItem = null;
    _copiedItem = null;

    await _loadProjectFromHistory();
  }

  Future<void> selectFile(FileItem item) async {
    if (item.isDirectory) return;
    final cleanPath = _history.rootPath;
    if (cleanPath != null) {
      await FileDirectoryHistoryService.instance.recordHistory(
        rootPath: cleanPath,
        lastOpenedFilePath: item.path,
        openDirectoryPaths: _history.openDirectoryPaths,
      );
      _history = FileDirectoryHistory(
        rootPath: cleanPath,
        lastOpenedFilePath: item.path,
        openDirectoryPaths: _history.openDirectoryPaths,
      );
      notifyListeners();
    }
  }

  Future<void> toggleDirectory(FileItem item, bool expanded) async {
    final cleanPath = _history.rootPath;
    if (cleanPath == null) return;

    final updatedOpenPaths = List<String>.from(_history.openDirectoryPaths);
    if (expanded) {
      if (!updatedOpenPaths.contains(item.path)) {
        updatedOpenPaths.add(item.path);
      }
      if (item.children.isEmpty) {
        final children = await FileService.instance.buildTree(
          item.path,
          depth: item.depth + 1,
          openDirectoryPaths: updatedOpenPaths,
        );
        item.children.clear();
        item.children.addAll(children);
      }
    } else {
      updatedOpenPaths.remove(item.path);
    }

    await FileDirectoryHistoryService.instance.recordHistory(
      rootPath: cleanPath,
      lastOpenedFilePath: _history.lastOpenedFilePath,
      openDirectoryPaths: updatedOpenPaths,
    );
    _history = FileDirectoryHistory(
      rootPath: cleanPath,
      lastOpenedFilePath: _history.lastOpenedFilePath,
      openDirectoryPaths: updatedOpenPaths,
    );
    notifyListeners();
  }

  Future<void> refreshTree() async {
    final currentRoot = _history.rootPath;
    if (currentRoot == null || currentRoot.trim().isEmpty) return;

    try {
      final items = await FileService.instance.buildTree(
        currentRoot,
        openDirectoryPaths: _history.openDirectoryPaths,
      );

      String? currentFile = _history.lastOpenedFilePath;
      if (currentFile != null) {
        final exists = await FileService.instance.entityExists(currentFile);
        if (!exists) {
          currentFile = null;
          await FileDirectoryHistoryService.instance.recordHistory(
            rootPath: currentRoot,
            lastOpenedFilePath: null,
            openDirectoryPaths: _history.openDirectoryPaths,
          );
        }
      }

      _items = items;
      if (currentFile != _history.lastOpenedFilePath) {
        _history = FileDirectoryHistory(
          rootPath: currentRoot,
          lastOpenedFilePath: currentFile,
          openDirectoryPaths: _history.openDirectoryPaths,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('刷新目录树失败: $e');
    }
  }

  void cut(FileItem item) {
    _cutItem = item;
    _copiedItem = null;
    notifyListeners();
  }

  void copy(FileItem item) {
    _copiedItem = item;
    _cutItem = null;
    notifyListeners();
  }

  Future<void> paste(FileItem targetDir) async {
    if (!targetDir.isDirectory) return;

    if (_cutItem != null) {
      final source = _cutItem!;
      await FileService.instance.moveEntity(source.path, targetDir.path);
      _cutItem = null;
      await refreshTree();
    } else if (_copiedItem != null) {
      final source = _copiedItem!;
      await FileService.instance.copyEntity(source.path, targetDir.path);
      await refreshTree();
    }
  }

  Future<void> createFile(String parentDir, String name) async {
    final targetPath = p.join(parentDir, name.trim());
    await FileService.instance.createFile(targetPath);
    await refreshTree();
  }

  Future<void> createDirectory(String parentDir, String name) async {
    final targetPath = p.join(parentDir, name.trim());
    await FileService.instance.createDirectory(targetPath);
    await refreshTree();
  }

  Future<void> rename(FileItem item, String newName) async {
    await FileService.instance.renameEntity(item.path, newName.trim());
    await refreshTree();
  }

  Future<void> delete(FileItem item) async {
    await FileService.instance.deleteEntity(item.path);
    await refreshTree();
  }
}
