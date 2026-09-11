import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 外部文件系统变动监听服务：
/// 1. 递归监听项目根目录下的文件与目录变动
/// 2. 300ms 防抖机制合并高频写入与构建事件
/// 3. 自身写盘保护（Self-Trigger Filter），避免自身保存陷入死循环
/// 4. 自动过滤 .git、.dart_tool、build 等高频临时目录
class FileWatcherService {
  static final FileWatcherService instance = FileWatcherService._();
  FileWatcherService._();

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  final List<FileSystemEvent> _pendingEvents = [];
  final Map<String, DateTime> _recentlySavedFiles = {};

  String? _watchedRootPath;

  /// 当前是否正在监听
  bool get isWatching => _subscription != null;

  /// 当前监听的根路径
  String? get watchedRootPath => _watchedRootPath;

  /// 登记应用自身刚才写盘保存的文件，在 600ms 内忽略该文件抛出的外部修改事件
  void markRecentlySaved(String filePath) {
    final clean = p.normalize(filePath);
    _recentlySavedFiles[clean] = DateTime.now();
  }

  /// 检查是否为应用自身刚刚保存的文件
  bool isRecentlySaved(String filePath) {
    final clean = p.normalize(filePath);
    final savedTime = _recentlySavedFiles[clean];
    if (savedTime == null) return false;
    final elapsed = DateTime.now().difference(savedTime);
    if (elapsed.inMilliseconds < 600) {
      return true;
    }
    _recentlySavedFiles.remove(clean);
    return false;
  }

  /// 判断路径是否属于应该忽略的隐藏或构建目录
  static bool shouldIgnore(String path) {
    final segments = p.split(path);
    for(final seg in segments) {
      if (seg == '.git' ||
          seg == '.dart_tool' ||
          seg == '.idea' ||
          seg == '.vscode' ||
          seg == 'build' ||
          seg == '.gradle') {
        return true;
      }
    }
    return false;
  }

  /// 开始监听指定项目根目录
  void startWatching(
    String rootPath, {
    required void Function(List<FileSystemEvent> events) onEvents,
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    stopWatching();

    final cleanRoot = p.normalize(rootPath);
    final dir = Directory(cleanRoot);
    if(!dir.existsSync()) return;

    _watchedRootPath = cleanRoot;

    try {
      _subscription = dir.watch(recursive: true).listen(
        (event) {
          if(shouldIgnore(event.path)) {
            return;
          }

          // 自身保存的文件在保护窗口内忽略内容修改事件
          if(event is FileSystemModifyEvent && isRecentlySaved(event.path)) {
            return;
          }

          _pendingEvents.add(event);

          _debounceTimer?.cancel();
          _debounceTimer = Timer(debounceDuration, () {
            if (_pendingEvents.isEmpty) return;
            final batch = List<FileSystemEvent>.from(_pendingEvents);
            _pendingEvents.clear();
            onEvents(batch);
          });
        },
        onError: (e) {
          debugPrint('FileWatcherService 监听异常: $e');
        },
      );
    }catch (e) {
      debugPrint('FileWatcherService 启动监听失败: $e');
    }
  }

  /// 停止并释放监听
  void stopWatching() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingEvents.clear();
    _subscription?.cancel();
    _subscription = null;
    _watchedRootPath = null;
  }

  @visibleForTesting
  void clearRecentlySavedForTesting() {
    _recentlySavedFiles.clear();
  }
}
