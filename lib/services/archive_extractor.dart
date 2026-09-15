import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'low_memory_xz_decoder.dart';

final RegExp _paxRecordRegexp = RegExp(r"(\d+) (\w+)=(.*)");

/// 压缩包格式枚举
enum ArchiveFormat {
  zip,
  tarGz,
  tarXz,
  tarBz2,
  tar,
  unknown,
}

/// 解压进度回调
/// [progress] 0.0 ~ 1.0
/// [message] 当前阶段文字说明
typedef ArchiveProgressCallback = void Function(double progress, String message);

/// 用户或外部取消解压异常
class ArchiveExtractCancelledException implements Exception {
  final String message;
  ArchiveExtractCancelledException([this.message = '解压操作已取消']);

  @override
  String toString() => message;
}

class _ExtractIsolateParams {
  final String archivePath;
  final String targetDirPath;
  final SendPort sendPort;
  final bool restorePermissions;

  const _ExtractIsolateParams({
    required this.archivePath,
    required this.targetDirPath,
    required this.sendPort,
    this.restorePermissions = false,
  });
}

/// 流式 TAR 块头部结构解析器
class _TarHeader {
  final String filename;
  final int mode;
  final int fileSize;
  final String typeFlag;
  final String? nameOfLinkedFile;

  _TarHeader({
    required this.filename,
    required this.mode,
    required this.fileSize,
    required this.typeFlag,
    this.nameOfLinkedFile,
  });

  static _TarHeader? read(InputStreamBase input) {
    if (input.isEOS) return null;
    final header = input.readBytes(512);
    if (header.length < 512) return null;
    final bytes = header.toUint8List();

    var allZero = true;
    for (var i = 0; i < 512; i++) {
      if (bytes[i] != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) return null;

    String parseString(int offset, int length) {
      var end = offset;
      final max = offset + length;
      while (end < max && bytes[end] != 0) {
        end++;
      }
      return utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
    }

    int parseInt(int offset, int length) {
      final s = parseString(offset, length).trim();
      if (s.isEmpty) return 0;
      return int.tryParse(s, radix: 8) ?? 0;
    }

    var filename = parseString(0, 100);
    final mode = parseInt(100, 8);
    final fileSize = parseInt(124, 12);
    final typeFlag = parseString(156, 1);
    String? nameOfLinkedFile = parseString(157, 100);
    if (nameOfLinkedFile.isEmpty) nameOfLinkedFile = null;

    final ustarIndicator = parseString(257, 6);
    if (ustarIndicator == 'ustar') {
      final filenamePrefix = parseString(345, 155);
      if (filenamePrefix.isNotEmpty) {
        filename = '$filenamePrefix/$filename';
      }
    }

    return _TarHeader(
      filename: filename,
      mode: mode,
      fileSize: fileSize,
      typeFlag: typeFlag,
      nameOfLinkedFile: nameOfLinkedFile,
    );
  }
}

/// 通用高性能、低内存流式解压引擎
///
/// 解决原生 package:archive 全量读入内存导致的 OOM (Out Of Memory) 崩溃，
/// 并将高负载解压迁移到独立的后台 Worker Isolate，保证主 UI 线程持续 120fps 流畅。
/// 支持全格式解压：.zip, .tar.gz, .tgz, .tar.xz, .txz, .tar.bz2, .tbz, .tar。
class ArchiveExtractor {
  /// 根据文件头部魔数与文件后缀综合识别压缩包格式
  static ArchiveFormat detectFormat(File file) {
    if (!file.existsSync()) return ArchiveFormat.unknown;

    try {
      final raf = file.openSync(mode: FileMode.read);
      final bytes = raf.readSync(6);
      raf.closeSync();

      // XZ 魔数: FD 37 7A 58 5A 00
      if (bytes.length >= 6 &&
          bytes[0] == 0xFD &&
          bytes[1] == 0x37 &&
          bytes[2] == 0x7A &&
          bytes[3] == 0x58 &&
          bytes[4] == 0x5A &&
          bytes[5] == 0x00) {
        return ArchiveFormat.tarXz;
      }

      // GZ 魔数: 1F 8B
      if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
        return ArchiveFormat.tarGz;
      }

      // BZ2 魔数: 42 5A 68 ('BZh')
      if (bytes.length >= 3 && bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68) {
        return ArchiveFormat.tarBz2;
      }

      // ZIP 魔数: 50 4B 03 04 ('PK\x03\x04')
      if (bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04) {
        return ArchiveFormat.zip;
      }
    } catch (_) {}

    final lower = file.path.toLowerCase();
    if (lower.endsWith('.zip')) return ArchiveFormat.zip;
    if (lower.endsWith('.tar.xz') || lower.endsWith('.txz') || lower.endsWith('.xz')) {
      return ArchiveFormat.tarXz;
    }
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz') || lower.endsWith('.gz')) {
      return ArchiveFormat.tarGz;
    }
    if (lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz') ||
        lower.endsWith('.tbz2') ||
        lower.endsWith('.bz2')) {
      return ArchiveFormat.tarBz2;
    }
    if (lower.endsWith('.tar')) return ArchiveFormat.tar;

    return ArchiveFormat.unknown;
  }

  /// 在独立后台 Isolate 中低内存流式解压压缩包到目标目录
  ///
  /// [archiveFile] 输入压缩包文件
  /// [targetDir] 目标解压目录
  /// [onProgress] 进度与状态说明回调（0.0 ~ 1.0）
  /// [isCancelled] 外部取消检查函数
  /// [restorePermissions] 是否恢复 Unix 权限位（Linux/Android 系统 Rootfs 解压需要）
  static Future<void> extract({
    required File archiveFile,
    required Directory targetDir,
    ArchiveProgressCallback? onProgress,
    bool Function()? isCancelled,
    bool restorePermissions = false,
  }) async {
    if (isCancelled?.call() == true) {
      throw ArchiveExtractCancelledException();
    }

    if (!archiveFile.existsSync()) {
      throw ArgumentError('压缩包文件不存在: ${archiveFile.path}');
    }

    onProgress?.call(0.02, '正在准备解压目录...');

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final receivePort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<Map<int, List<String>>>();
    Isolate? isolate;
    Timer? cancelTimer;

    try {
      isolate = await Isolate.spawn<_ExtractIsolateParams>(
        _extractIsolateEntry,
        _ExtractIsolateParams(
          archivePath: archiveFile.path,
          targetDirPath: targetDir.path,
          sendPort: receivePort.sendPort,
          restorePermissions: restorePermissions,
        ),
      );

      isolate.addOnExitListener(exitPort.sendPort);
      exitPort.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('解压 Worker 意外退出'));
        }
      });

      cancelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (isCancelled?.call() == true) {
          isolate?.kill(priority: Isolate.immediate);
          if (!completer.isCompleted) {
            completer.completeError(ArchiveExtractCancelledException());
          }
        }
      });

      receivePort.listen((message) {
        if (message is List) {
          final type = message[0] as int;
          if (type == 0) {
            final prog = message[1] as double;
            final msg = message[2] as String;
            onProgress?.call(prog, msg);
          } else if (type == 1) {
            final byMode = (message[1] as Map).cast<int, List<String>>();
            if (!completer.isCompleted) {
              completer.complete(byMode);
            }
          } else if (type == 3) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(message[1].toString()));
            }
          }
        }
      });

      final byMode = await completer.future;

      if (restorePermissions && !Platform.isWindows && byMode.isNotEmpty) {
        await _restoreModes(byMode);
      }

      onProgress?.call(1.0, '解压完成！');
    } catch (e) {
      // 若中途失败或取消，清理不完整的目标目录
      try {
        if (targetDir.existsSync()) {
          targetDir.deleteSync(recursive: true);
        }
      } catch (_) {}
      rethrow;
    } finally {
      cancelTimer?.cancel();
      receivePort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// Worker Isolate 入口：低内存流式解码与单文件即刻落盘
  static Future<void> _extractIsolateEntry(_ExtractIsolateParams params) async {
    File? tempTarFile;
    try {
      params.sendPort.send([0, 0.05, '正在分析压缩文件结构...']);
      final archiveFile = File(params.archivePath);
      if (!archiveFile.existsSync()) {
        params.sendPort.send([3, '压缩包文件不存在: ${params.archivePath}']);
        return;
      }

      final format = detectFormat(archiveFile);
      final targetDir = Directory(params.targetDirPath);
      final tempDir = targetDir.parent.existsSync() ? targetDir.parent : Directory.systemTemp;

      if (format == ArchiveFormat.zip) {
        // ZIP 流式解压（单文件解压并立即清除内存对象）
        params.sendPort.send([0, 0.10, '正在读取 ZIP 目录索引...']);
        await _streamExtractZipFile(
          zipFile: archiveFile,
          targetDirPath: params.targetDirPath,
          sendPort: params.sendPort,
          progressStart: 0.10,
          progressEnd: 0.98,
        );
        params.sendPort.send([1, <int, List<String>>{}]);
        return;
      }

      File tarToExtract;
      if (format == ArchiveFormat.tarXz) {
        params.sendPort.send([0, 0.10, '正在通过环形缓冲流式解压 XZ 格式...']);
        tempTarFile = File(p.join(
          tempDir.path,
          'temp_extract_${DateTime.now().microsecondsSinceEpoch}.tar',
        ));
        if (tempTarFile.existsSync()) {
          try {
            tempTarFile.deleteSync();
          } catch (_) {}
        }
        final tarSink = tempTarFile.openWrite();
        final inputStream = InputFileStream(archiveFile.path);
        final archiveSize = archiveFile.lengthSync();

        try {
          final decoder = LowMemoryXZDecoder();
          decoder.decodeToSink(
            inputStream,
            tarSink,
            onProgress: (decompressed, compPos) {
              final frac = archiveSize > 0 ? (compPos / archiveSize).clamp(0.0, 1.0) : 0.0;
              final prog = 0.10 + frac * 0.40; // 0.10 ~ 0.50
              final mb = (decompressed / (1024 * 1024)).toStringAsFixed(1);
              params.sendPort.send([0, prog, '正在解码流 ($mb MB)...']);
            },
          );
        } finally {
          await tarSink.flush();
          await tarSink.close();
          await inputStream.close();
        }
        tarToExtract = tempTarFile;
      } else if (format == ArchiveFormat.tarGz) {
        params.sendPort.send([0, 0.10, '正在流式解压 GZip 压缩流...']);
        tempTarFile = File(p.join(
          tempDir.path,
          'temp_extract_${DateTime.now().microsecondsSinceEpoch}.tar',
        ));
        if (tempTarFile.existsSync()) {
          try {
            tempTarFile.deleteSync();
          } catch (_) {}
        }
        final tarSink = tempTarFile.openWrite();
        try {
          await archiveFile.openRead().transform(gzip.decoder).pipe(tarSink);
        } finally {
          await tarSink.close();
        }
        tarToExtract = tempTarFile;
      } else if (format == ArchiveFormat.tarBz2) {
        params.sendPort.send([0, 0.10, '正在流式解压 BZip2 压缩流...']);
        tempTarFile = File(p.join(
          tempDir.path,
          'temp_extract_${DateTime.now().microsecondsSinceEpoch}.tar',
        ));
        if (tempTarFile.existsSync()) {
          try {
            tempTarFile.deleteSync();
          } catch (_) {}
        }
        final tarSink = OutputFileStream(tempTarFile.path);
        final inputStream = InputFileStream(archiveFile.path);
        try {
          BZip2Decoder().decodeStream(inputStream, tarSink);
        } finally {
          await inputStream.close();
          await tarSink.close();
        }
        tarToExtract = tempTarFile;
      } else {
        tarToExtract = archiveFile;
      }

      // TAR 块流式释放到目标根目录
      params.sendPort.send([0, 0.50, '正在释放文件与构建目录结构...']);
      final byMode = await _streamExtractTarFile(
        tarFile: tarToExtract,
        targetDirPath: params.targetDirPath,
        sendPort: params.sendPort,
        progressStart: 0.50,
        progressEnd: 0.98,
      );

      params.sendPort.send([1, byMode]);
    } catch (e, stack) {
      params.sendPort.send([3, '$e\n$stack']);
    } finally {
      if (tempTarFile != null && tempTarFile.existsSync()) {
        try {
          tempTarFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 流式逐条解析 TAR 文件并直接落盘（不缓存大对象，单块 64KB 直写）
  static Future<Map<int, List<String>>> _streamExtractTarFile({
    required File tarFile,
    required String targetDirPath,
    required SendPort sendPort,
    required double progressStart,
    required double progressEnd,
  }) async {
    final input = InputFileStream(tarFile.path);
    final byMode = <int, List<String>>{};
    final totalLen = tarFile.lengthSync();
    String? nextName;
    String? nextLinkName;
    int processed = 0;

    try {
      while (!input.isEOS) {
        final th = _TarHeader.read(input);
        if (th == null) break;

        if (th.filename == '././@LongLink' || th.filename == '././@LongSymLink') {
          final contentBytes = input.readBytes(th.fileSize).toUint8List();
          final remainder = th.fileSize % 512;
          if (remainder != 0) input.skip(512 - remainder);
          final text = utf8.decode(contentBytes, allowMalformed: true).split('\x00').first;
          if (th.typeFlag == 'K') {
            nextLinkName = text;
          } else {
            nextName = text;
          }
          continue;
        }

        if (th.typeFlag == 'g' || th.typeFlag == 'x') {
          // PAX Header
          try {
            final paxBytes = input.readBytes(th.fileSize).toUint8List();
            final remainder = th.fileSize % 512;
            if (remainder != 0) input.skip(512 - remainder);
            final headerContent = utf8.decode(paxBytes, allowMalformed: true);
            for (final line in headerContent.split('\n')) {
              final match = _paxRecordRegexp.firstMatch(line);
              if (match != null) {
                final k = match.group(2);
                final v = match.group(3);
                if (k == 'path' && v != null) nextName = v;
                if (k == 'linkpath' && v != null) nextLinkName = v;
              }
            }
          } catch (_) {}
          continue;
        }

        final filename = nextName ?? th.filename;
        nextName = null;
        final linkName = nextLinkName ?? th.nameOfLinkedFile;
        nextLinkName = null;

        // 路径穿越校验 (TarSlip 防护)
        if (filename.contains('..') || filename.startsWith('/') || filename.contains(':')) {
          if (th.fileSize > 0) {
            input.skip(th.fileSize);
            final remainder = th.fileSize % 512;
            if (remainder != 0) input.skip(512 - remainder);
          }
          continue;
        }

        final cleanRel = p.normalize(filename);
        if (cleanRel.startsWith('..') || p.isAbsolute(cleanRel)) {
          if (th.fileSize > 0) {
            input.skip(th.fileSize);
            final remainder = th.fileSize % 512;
            if (remainder != 0) input.skip(512 - remainder);
          }
          continue;
        }

        final outPath = p.join(targetDirPath, cleanRel);
        if (!p.isWithin(p.canonicalize(targetDirPath), p.canonicalize(outPath)) &&
            p.canonicalize(targetDirPath) != p.canonicalize(outPath)) {
          if (th.fileSize > 0) {
            input.skip(th.fileSize);
            final remainder = th.fileSize % 512;
            if (remainder != 0) input.skip(512 - remainder);
          }
          continue;
        }

        if (th.typeFlag == '5' || th.filename.endsWith('/')) {
          final d = Directory(outPath);
          if (!d.existsSync()) d.createSync(recursive: true);
        } else if ((th.typeFlag == '2' || th.typeFlag == '1') && linkName != null) {
          try {
            final parent = Directory(p.dirname(outPath));
            if (!parent.existsSync()) parent.createSync(recursive: true);
            final link = Link(outPath);
            if (link.existsSync()) link.deleteSync();
            link.createSync(linkName);
          } catch (_) {}
        } else {
          final parent = Directory(p.dirname(outPath));
          if (!parent.existsSync()) parent.createSync(recursive: true);

          final f = File(outPath);
          final sink = f.openWrite();
          var remaining = th.fileSize;
          while (remaining > 0) {
            final chunk = remaining < 65536 ? remaining : 65536;
            sink.add(input.readBytes(chunk).toUint8List());
            remaining -= chunk;
          }
          await sink.flush();
          await sink.close();

          final remainder = th.fileSize % 512;
          if (remainder != 0) input.skip(512 - remainder);
        }

        final mode = th.mode & 0xFFF;
        if (mode != 0 && th.typeFlag != '2') {
          byMode.putIfAbsent(mode, () => <String>[]).add(outPath);
        }

        processed++;
        if (processed % 100 == 0) {
          final fraction = totalLen > 0 ? (input.position / totalLen).clamp(0.0, 1.0) : 0.0;
          final prog = progressStart + fraction * (progressEnd - progressStart);
          sendPort.send([0, prog, '正在释放文件 ($processed)...']);
        }
      }
    } finally {
      await input.close();
    }

    return byMode;
  }

  /// 流式逐条解析 ZIP 文件并直接落盘（单文件即解即清，内存严格平稳）
  static Future<void> _streamExtractZipFile({
    required File zipFile,
    required String targetDirPath,
    required SendPort sendPort,
    required double progressStart,
    required double progressEnd,
  }) async {
    final input = InputFileStream(zipFile.path);
    try {
      final zip = ZipDecoder().decodeBuffer(input);
      final total = zip.files.length;
      var count = 0;

      for (final file in zip.files) {
        final rawName = file.name.replaceAll('\\', '/');

        // 路径穿越校验 (ZipSlip 防护)
        if (rawName.contains('..') || rawName.startsWith('/') || rawName.contains(':')) {
          count++;
          continue;
        }

        final cleanRel = p.normalize(rawName);
        if (cleanRel.startsWith('..') || p.isAbsolute(cleanRel)) {
          count++;
          continue;
        }

        final outPath = p.join(targetDirPath, cleanRel);
        if (!p.isWithin(p.canonicalize(targetDirPath), p.canonicalize(outPath)) &&
            p.canonicalize(targetDirPath) != p.canonicalize(outPath)) {
          count++;
          continue;
        }

        if (!file.isFile || rawName.endsWith('/')) {
          final d = Directory(outPath);
          if (!d.existsSync()) d.createSync(recursive: true);
        } else if (file.isSymbolicLink) {
          try {
            final parent = Directory(p.dirname(outPath));
            if (!parent.existsSync()) parent.createSync(recursive: true);
            final link = Link(outPath);
            if (link.existsSync()) link.deleteSync();
            link.createSync(p.normalize(file.nameOfLinkedFile));
          } catch (_) {}
        } else {
          final parent = Directory(p.dirname(outPath));
          if (!parent.existsSync()) parent.createSync(recursive: true);

          final outStream = OutputFileStream(outPath);
          try {
            file.writeContent(outStream, freeMemory: true);
          } finally {
            await outStream.close();
            file.clear();
          }
        }

        count++;
        if (count % 25 == 0 || count == total) {
          final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 1.0;
          final prog = progressStart + fraction * (progressEnd - progressStart);
          sendPort.send([0, prog, '正在解压文件 ($count/$total)...']);
        }
      }
    } finally {
      await input.close();
    }
  }

  /// 按 tar 头部恢复 POSIX 文件权限位
  static Future<void> _restoreModes(Map<int, List<String>> byMode) async {
    for (final entry in byMode.entries) {
      final octal = entry.key.toRadixString(8).padLeft(4, '0');
      final paths = entry.value;

      const batchSize = 100;
      for (var i = 0; i < paths.length; i += batchSize) {
        final batch = paths.sublist(i, (i + batchSize).clamp(0, paths.length));
        try {
          await Process.run('chmod', [octal, ...batch]);
        } catch (_) {
          break; // 若系统无 chmod 则静默跳过
        }
      }
    }
  }
}
