import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/distro_manifest.dart';
import 'distro_image_resolver.dart';

/// 系统包下载状态枚举
enum DistroDownloadState {
  notStarted,
  downloading,
  completed,
  cancelled,
  failed,
}

/// 单个系统的下载状态快照
class DistroDownloadProgress {
  final String distroId;
  final DistroDownloadState state;
  final double progress; // 0.0 ~ 1.0
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;
  final File? targetFile;

  const DistroDownloadProgress({
    required this.distroId,
    required this.state,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.errorMessage,
    this.targetFile,
  });

  DistroDownloadProgress copyWith({
    DistroDownloadState? state,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
    File? targetFile,
  }) {
    return DistroDownloadProgress(
      distroId: distroId,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      targetFile: targetFile ?? this.targetFile,
    );
  }
}

/// 下载被取消异常
class DistroDownloadCancelledException implements Exception {
  final String message;
  const DistroDownloadCancelledException([this.message = 'Download cancelled']);
  @override
  String toString() => message;
}

/// 全局异步系统镜像下载管理器（单例模式）
class DistroDownloadManager extends ChangeNotifier {
  static final DistroDownloadManager _instance = DistroDownloadManager._internal();
  factory DistroDownloadManager() => _instance;
  DistroDownloadManager._internal();

  final Map<String, DistroDownloadProgress> _progressMap = {};
  final Map<String, HttpClientRequest> _activeRequests = {};
  final Map<String, HttpClient> _activeClients = {};
  final Map<String, StreamSubscription<List<int>>> _activeSubscriptions = {};
  final Map<String, IOSink> _activeSinks = {};
  final Map<String, Completer<void>> _activeCompleters = {};
  final Set<String> _cancelledDistroIds = {};

  @visibleForTesting
  Directory? customPackagesDir;

  /// 获取系统安装包持久化存储目录: `<app_dir>/distro_packages`
  Future<Directory> getPackagesDir() async {
    if (customPackagesDir != null) return customPackagesDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'distro_packages'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 获取指定系统的安装包文件对象
  Future<File> getPackageFile(String distroId, [String? downloadUrl]) async {
    final dir = await getPackagesDir();
    final ext = (downloadUrl?.endsWith('.tar.gz') ?? false) ? '.tar.gz' : '.tar.xz';
    final targetFile = File(p.join(dir.path, '${distroId}_rootfs$ext'));
    if (targetFile.existsSync()) return targetFile;
    final altExt = ext == '.tar.xz' ? '.tar.gz' : '.tar.xz';
    final altFile = File(p.join(dir.path, '${distroId}_rootfs$altExt'));
    if (altFile.existsSync()) return altFile;
    return targetFile;
  }

  /// 检测指定系统的离线安装包是否已下载完备
  Future<bool> isPackageDownloaded(String distroId, [String? downloadUrl]) async {
    final dir = await getPackagesDir();
    final xzFile = File(p.join(dir.path, '${distroId}_rootfs.tar.xz'));
    final gzFile = File(p.join(dir.path, '${distroId}_rootfs.tar.gz'));
    return (xzFile.existsSync() && xzFile.lengthSync() > 0) ||
        (gzFile.existsSync() && gzFile.lengthSync() > 0);
  }

  /// 物理删除已下载的系统安装包
  Future<void> deletePackage(String distroId, [String? downloadUrl]) async {
    if (isDownloading(distroId)) {
      await cancelDownload(distroId);
    }
    final dir = await getPackagesDir();
    final files = [
      File(p.join(dir.path, '${distroId}_rootfs.tar.xz')),
      File(p.join(dir.path, '${distroId}_rootfs.tar.gz')),
    ];
    for (final f in files) {
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    _progressMap.remove(distroId);
    notifyListeners();
  }

  /// 获取所有正在跟踪的下载任务快照
  Map<String, DistroDownloadProgress> get allProgress => Map.unmodifiable(_progressMap);

  /// 查询指定系统的下载状态
  DistroDownloadProgress? getProgress(String distroId) => _progressMap[distroId];

  /// 是否正在下载
  bool isDownloading(String distroId) {
    final status = _progressMap[distroId];
    return status != null && status.state == DistroDownloadState.downloading;
  }

  /// 启动异步流式下载
  Future<File?> startDownload({
    required String distroId,
    required String downloadUrl,
    DistroMirror? mirror,
    DistroManifestItem? manifestItem,
  }) async {
    if (isDownloading(distroId)) return null;

    // 资源检测：若本地已存在完整的离线镜像包，拒绝重复下载并直接返回已有文件
    if (await isPackageDownloaded(distroId, downloadUrl)) {
      final existingFile = await getPackageFile(distroId, downloadUrl);
      _progressMap[distroId] = DistroDownloadProgress(
        distroId: distroId,
        state: DistroDownloadState.completed,
        progress: 1.0,
        receivedBytes: existingFile.existsSync() ? existingFile.lengthSync() : 0,
        totalBytes: existingFile.existsSync() ? existingFile.lengthSync() : 0,
        targetFile: existingFile,
      );
      notifyListeners();
      return existingFile;
    }

    // 清除历史取消标记
    _cancelledDistroIds.remove(distroId);

    // 状态更新为 downloading
    _progressMap[distroId] = DistroDownloadProgress(
      distroId: distroId,
      state: DistroDownloadState.downloading,
      progress: 0.0,
    );
    notifyListeners();

    String actualDownloadUrl = downloadUrl;
    if (manifestItem != null && manifestItem.lxcSpec != null) {
      try {
        final activeMirror = mirror ?? DistroRepository.defaultMirror;
        actualDownloadUrl = await DistroImageResolver().resolveDownloadUrl(
          item: manifestItem,
          arch: DistroManifestItem.currentArch,
          mirror: activeMirror,
        );
      } catch (e) {
        if (_cancelledDistroIds.contains(distroId)) {
          _cleanupCancelledState(distroId);
          return null;
        }
        _progressMap[distroId] = DistroDownloadProgress(
          distroId: distroId,
          state: DistroDownloadState.failed,
          errorMessage: e.toString(),
        );
        notifyListeners();
        return null;
      }
    }

    if (_cancelledDistroIds.contains(distroId)) {
      _cleanupCancelledState(distroId);
      return null;
    }

    // 二次资源检测：解析目标 URL 后再次检测文件是否完备
    if (await isPackageDownloaded(distroId, actualDownloadUrl)) {
      final existingFile = await getPackageFile(distroId, actualDownloadUrl);
      _progressMap[distroId] = DistroDownloadProgress(
        distroId: distroId,
        state: DistroDownloadState.completed,
        progress: 1.0,
        receivedBytes: existingFile.existsSync() ? existingFile.lengthSync() : 0,
        totalBytes: existingFile.existsSync() ? existingFile.lengthSync() : 0,
        targetFile: existingFile,
      );
      notifyListeners();
      return existingFile;
    }

    final targetFile = await getPackageFile(distroId, actualDownloadUrl);
    final partFilePath = '${targetFile.path}.part';
    final partFile = File(partFilePath);

    HttpClient? client;
    IOSink? sink;
    StreamSubscription<List<int>>? subscription;
    final completer = Completer<void>();
    _activeCompleters[distroId] = completer;

    try {
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }

      if (_cancelledDistroIds.contains(distroId)) {
        throw const DistroDownloadCancelledException();
      }

      client = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      _activeClients[distroId] = client;

      final uri = Uri.parse(actualDownloadUrl);
      final request = await client.getUrl(uri);
      _activeRequests[distroId] = request;

      if (_cancelledDistroIds.contains(distroId)) {
        throw const DistroDownloadCancelledException();
      }

      final response = await request.close();
      if (_cancelledDistroIds.contains(distroId)) {
        throw const DistroDownloadCancelledException();
      }

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP Error: ${response.statusCode} ${response.reasonPhrase}');
      }

      final total = response.contentLength;
      int received = 0;
      sink = partFile.openWrite();
      _activeSinks[distroId] = sink;

      subscription = response.listen(
        (chunk) {
          if (_cancelledDistroIds.contains(distroId)) {
            subscription?.cancel();
            return;
          }
          sink?.add(chunk);
          received += chunk.length;
          final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

          _progressMap[distroId] = DistroDownloadProgress(
            distroId: distroId,
            state: DistroDownloadState.downloading,
            progress: prog,
            receivedBytes: received,
            totalBytes: total,
          );
          notifyListeners();
        },
        onDone: () async {
          if (_cancelledDistroIds.contains(distroId)) {
            if (!completer.isCompleted) {
              completer.completeError(const DistroDownloadCancelledException());
            }
            return;
          }
          try {
            await sink?.flush();
            await sink?.close();
            sink = null;
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        cancelOnError: true,
      );
      _activeSubscriptions[distroId] = subscription;

      await completer.future;

      if (_cancelledDistroIds.contains(distroId)) {
        throw const DistroDownloadCancelledException();
      }

      // 下载完成，原子重命名 .part -> targetFile
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      partFile.renameSync(targetFile.path);

      _progressMap[distroId] = DistroDownloadProgress(
        distroId: distroId,
        state: DistroDownloadState.completed,
        progress: 1.0,
        receivedBytes: received,
        totalBytes: total,
        targetFile: targetFile,
      );
      notifyListeners();
      return targetFile;
    } catch (e) {
      final isCancelled = _cancelledDistroIds.contains(distroId) ||
          e is DistroDownloadCancelledException;

      // 无论如何先关闭写入流，确保文件句柄释放
      try {
        await sink?.close();
      } catch (_) {}

      // 清理临时文件
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }

      if (isCancelled) {
        _cleanupCancelledState(distroId);
      } else {
        _progressMap[distroId] = DistroDownloadProgress(
          distroId: distroId,
          state: DistroDownloadState.failed,
          errorMessage: e.toString(),
        );
        notifyListeners();
      }
      return null;
    } finally {
      _activeRequests.remove(distroId);
      _activeSubscriptions.remove(distroId);
      _activeSinks.remove(distroId);
      _activeCompleters.remove(distroId);
      final c = _activeClients.remove(distroId);
      try {
        c?.close(force: true);
      } catch (_) {}
      _cancelledDistroIds.remove(distroId);
    }
  }

  /// 取消下载并清理已下载的临时缓存资源
  Future<void> cancelDownload(String distroId) async {
    _cancelledDistroIds.add(distroId);

    // 1. 中断活跃 Completer
    final completer = _activeCompleters.remove(distroId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const DistroDownloadCancelledException());
    }

    // 2. 中断 Request 并强力关闭 HttpClient（立即熔断底层 TCP Socket，避免 sub.cancel() 陷入 socket 耗尽等待）
    final request = _activeRequests.remove(distroId);
    if (request != null) {
      try {
        request.abort();
      } catch (_) {}
    }
    final client = _activeClients.remove(distroId);
    if (client != null) {
      try {
        client.close(force: true);
      } catch (_) {}
    }

    // 3. 取消活跃 Stream 订阅以停止接收数据包（不阻塞等待 drain）
    final sub = _activeSubscriptions.remove(distroId);
    if (sub != null) {
      try {
        unawaited(sub.cancel());
      } catch (_) {}
    }

    // 4. 关闭文件写入流以释放文件句柄（Windows 平台必须关闭方可删除）
    final sink = _activeSinks.remove(distroId);
    if (sink != null) {
      try {
        await sink.close();
      } catch (_) {}
    }

    // 5. 立即清除临时 .part 文件
    try {
      final dir = await getPackagesDir();
      final partFiles = [
        File(p.join(dir.path, '${distroId}_rootfs.tar.gz.part')),
        File(p.join(dir.path, '${distroId}_rootfs.tar.xz.part')),
      ];
      for (final f in partFiles) {
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}

    // 6. 重置状态并通知刷新
    _cleanupCancelledState(distroId);
  }

  void _cleanupCancelledState(String distroId) {
    _progressMap.remove(distroId);
    notifyListeners();
  }

  /// 重置已完成或失败的状态
  void resetState(String distroId) {
    _progressMap.remove(distroId);
    notifyListeners();
  }
}
