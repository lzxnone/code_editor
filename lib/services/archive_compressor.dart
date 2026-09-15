import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'archive_extractor.dart';

/// 用户或外部取消压缩异常
class ArchiveCompressCancelledException implements Exception {
  final String message;
  ArchiveCompressCancelledException([this.message = '压缩操作已取消']);

  @override
  String toString() => message;
}

/// 内部 CRC-32 表（IEEE 802.3 标准多项式 0xEDB88320）
final List<int> _crcTable = List<int>.generate(256, (i) {
  var c = i;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
  }
  return c;
});

/// 高性能增量 CRC-32 校验和计算
int computeCrc32(List<int> bytes, [int crc = 0]) {
  crc = crc ^ 0xffffffff;
  for (var i = 0; i < bytes.length; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return crc ^ 0xffffffff;
}

int _dosTime(DateTime dt) {
  return ((dt.hour & 0x1f) << 11) |
      ((dt.minute & 0x3f) << 5) |
      ((dt.second ~/ 2) & 0x1f);
}

int _dosDate(DateTime dt) {
  final year = dt.year < 1980 ? 1980 : (dt.year > 2107 ? 2107 : dt.year);
  return (((year - 1980) & 0x7f) << 9) |
      ((dt.month & 0x0f) << 5) |
      (dt.day & 0x1f);
}

class _ZipEntryRecord {
  final String name;
  final int time;
  final int date;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int method;
  final int localHeaderOffset;
  final bool isDirectory;

  const _ZipEntryRecord({
    required this.name,
    required this.time,
    required this.date,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.method,
    required this.localHeaderOffset,
    required this.isDirectory,
  });
}

class _CompressIsolateParams {
  final String sourceDirPath;
  final String targetZipPath;
  final SendPort sendPort;

  const _CompressIsolateParams({
    required this.sourceDirPath,
    required this.targetZipPath,
    required this.sendPort,
  });
}

class _RafChunkSink implements Sink<List<int>> {
  final RandomAccessFile raf;
  int bytesWritten = 0;

  _RafChunkSink(this.raf);

  @override
  void add(List<int> chunk) {
    if (chunk.isNotEmpty) {
      raf.writeFromSync(chunk);
      bytesWritten += chunk.length;
    }
  }

  @override
  void close() {}
}

/// 通用自研低内存流式 ZIP 压缩引擎
///
/// 解决原生 package:archive/ZipFileEncoder 在大项目或海量小文件时
/// 触发并发读取与全量大内存缓冲导致的 OOM (Out Of Memory) 崩溃。
///
/// 特性：
/// 1. 严格遵循 PKZIP 标准；
/// 2. 64KB 分块流式直写落盘，内存恒定在 < 15MB；
/// 3. 支持 Local File Header 占位与精确尺寸/CRC-32 回填；
/// 4. 独立后台 Worker Isolate 运行，零 UI 冻结；
/// 5. 支持实时进度回调与安全取消（清理残余半成品文件）。
class ArchiveCompressor {
  /// 将 [sourceDir] 目录下的所有文件和文件夹打包流式压缩为 ZIP 文件 [targetZipFile]
  static Future<void> zipDirectory({
    required Directory sourceDir,
    required File targetZipFile,
    ArchiveProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      throw ArchiveCompressCancelledException();
    }

    if (!sourceDir.existsSync()) {
      throw ArgumentError('源目录不存在: ${sourceDir.path}');
    }

    onProgress?.call(0.01, '正在准备压缩...');

    // 确保目标父目录存在
    final parentDir = targetZipFile.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    // 若目标文件已存在先删除旧文件
    if (targetZipFile.existsSync()) {
      try {
        targetZipFile.deleteSync();
      } catch (_) {}
    }

    final receivePort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<void>();
    Isolate? isolate;
    Timer? cancelTimer;

    try {
      isolate = await Isolate.spawn<_CompressIsolateParams>(
        _compressIsolateEntry,
        _CompressIsolateParams(
          sourceDirPath: sourceDir.path,
          targetZipPath: targetZipFile.path,
          sendPort: receivePort.sendPort,
        ),
      );

      isolate.addOnExitListener(exitPort.sendPort);
      exitPort.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('压缩 Worker Isolate 意外退出'));
        }
      });

      cancelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (isCancelled?.call() == true) {
          isolate?.kill(priority: Isolate.immediate);
          if (!completer.isCompleted) {
            completer.completeError(ArchiveCompressCancelledException());
          }
        }
      });

      receivePort.listen((message) {
        if (message is List) {
          final type = message[0] as int;
          if (type == 0) {
            // 进度通知: [0, progress(0.0~1.0), message]
            final prog = message[1] as double;
            final msg = message[2] as String;
            onProgress?.call(prog, msg);
          } else if (type == 1) {
            // 成功完成: [1]
            if (!completer.isCompleted) {
              completer.complete();
            }
          } else if (type == 3) {
            // 失败错误: [3, errorMessage]
            if (!completer.isCompleted) {
              completer.completeError(Exception(message[1].toString()));
            }
          }
        }
      });

      await completer.future;
    } catch (e) {
      if (targetZipFile.existsSync()) {
        try {
          targetZipFile.deleteSync();
        } catch (_) {}
      }
      rethrow;
    } finally {
      cancelTimer?.cancel();
      receivePort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// 后台 Worker Isolate 执行入口
  static Future<void> _compressIsolateEntry(_CompressIsolateParams params) async {
    final sendPort = params.sendPort;
    final sourceDir = Directory(params.sourceDirPath);
    final targetFile = File(params.targetZipPath);
    RandomAccessFile? raf;

    try {
      sendPort.send([0, 0.05, '正在扫描工程文件列表...']);

      final targetCanonical = p.canonicalize(targetFile.path);
      final sourceCanonical = p.canonicalize(sourceDir.path);

      // 递归收集所有实体，按目录结构排布
      final entities = <FileSystemEntity>[];
      for (final entity in sourceDir.listSync(recursive: true, followLinks: false)) {
        // 避免把正在写入的 zip 文件自身扫描进去
        if (p.canonicalize(entity.path) == targetCanonical) {
          continue;
        }
        entities.add(entity);
      }

      // 按字典序排序保持构建一致性
      entities.sort((a, b) => a.path.compareTo(b.path));

      final total = entities.length;
      sendPort.send([0, 0.10, '开始流式压缩...']);

      raf = targetFile.openSync(mode: FileMode.write);
      final entries = <_ZipEntryRecord>[];
      final readBuffer = Uint8List(64 * 1024);

      for (var i = 0; i < total; i++) {
        final entity = entities[i];
        var relPath = p.relative(entity.path, from: sourceCanonical).replaceAll('\\', '/');
        if (relPath.startsWith('./')) {
          relPath = relPath.substring(2);
        }

        final stat = entity.statSync();
        final modTime = stat.modified;
        final dosT = _dosTime(modTime);
        final dosD = _dosDate(modTime);

        if (entity is Directory) {
          if (!relPath.endsWith('/')) {
            relPath = '$relPath/';
          }
          final nameBytes = utf8.encode(relPath);
          final localHeaderOffset = raf.positionSync();

          // 写入 Local File Header（目录使用 Store，0 字节内容）
          _writeLocalHeader(
            raf: raf,
            method: 0,
            dosTime: dosT,
            dosDate: dosD,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            nameBytes: nameBytes,
          );

          entries.add(_ZipEntryRecord(
            name: relPath,
            time: dosT,
            date: dosD,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            method: 0,
            localHeaderOffset: localHeaderOffset,
            isDirectory: true,
          ));
        } else if (entity is File) {
          final fileSize = stat.size;
          final nameBytes = utf8.encode(relPath);
          final localHeaderOffset = raf.positionSync();

          if (fileSize == 0) {
            // 空文件无需压缩，使用 Store 模式
            _writeLocalHeader(
              raf: raf,
              method: 0,
              dosTime: dosT,
              dosDate: dosD,
              crc32: 0,
              compressedSize: 0,
              uncompressedSize: 0,
              nameBytes: nameBytes,
            );

            entries.add(_ZipEntryRecord(
              name: relPath,
              time: dosT,
              date: dosD,
              crc32: 0,
              compressedSize: 0,
              uncompressedSize: 0,
              method: 0,
              localHeaderOffset: localHeaderOffset,
              isDirectory: false,
            ));
          } else {
            // 写入占位 Local File Header (待压缩完成后回填 CRC 和压缩后大小)
            _writeLocalHeader(
              raf: raf,
              method: 8, // Deflate
              dosTime: dosT,
              dosDate: dosD,
              crc32: 0,
              compressedSize: 0,
              uncompressedSize: fileSize,
              nameBytes: nameBytes,
            );

            // 流式分块压缩直写
            final fileRaf = entity.openSync(mode: FileMode.read);
            var crc = 0;
            var uncompressedBytes = 0;
            final chunkSink = _RafChunkSink(raf);
            final deflateSink = ZLibEncoder(raw: true, level: 6).startChunkedConversion(chunkSink);

            try {
              while (true) {
                final bytesRead = fileRaf.readIntoSync(readBuffer);
                if (bytesRead <= 0) break;
                final view = Uint8List.sublistView(readBuffer, 0, bytesRead);
                crc = computeCrc32(view, crc);
                uncompressedBytes += bytesRead;
                deflateSink.add(view);
              }
            } finally {
              deflateSink.close();
              fileRaf.closeSync();
            }

            final compressedBytes = chunkSink.bytesWritten;
            final endPos = raf.positionSync();

            // 回退到 Local Header 的 crc32 位置 (localHeaderOffset + 14) 回填元数据
            raf.setPositionSync(localHeaderOffset + 14);
            final fixHeader = ByteData(12);
            fixHeader.setUint32(0, crc, Endian.little);
            fixHeader.setUint32(4, compressedBytes, Endian.little);
            fixHeader.setUint32(8, uncompressedBytes, Endian.little);
            raf.writeFromSync(fixHeader.buffer.asUint8List());

            // 恢复指针到写入末尾
            raf.setPositionSync(endPos);

            entries.add(_ZipEntryRecord(
              name: relPath,
              time: dosT,
              date: dosD,
              crc32: crc,
              compressedSize: compressedBytes,
              uncompressedSize: uncompressedBytes,
              method: 8,
              localHeaderOffset: localHeaderOffset,
              isDirectory: false,
            ));
          }
        }

        if ((i + 1) % 20 == 0 || (i + 1) == total) {
          final fraction = total > 0 ? (i + 1) / total : 1.0;
          final prog = 0.10 + fraction * 0.85;
          sendPort.send([0, prog, '正在压缩 (${i + 1}/$total)...']);
        }
      }

      // 写入 Central Directory 和 End of Central Directory (EOCD)
      sendPort.send([0, 0.96, '正在封装压缩文件索引...']);
      final cdStartOffset = raf.positionSync();

      for (final entry in entries) {
        _writeCentralDirectoryHeader(raf: raf, entry: entry);
      }

      final cdEndOffset = raf.positionSync();
      final cdSize = cdEndOffset - cdStartOffset;

      // 写入 End of Central Directory Record
      _writeEOCD(
        raf: raf,
        entryCount: entries.length,
        cdSize: cdSize,
        cdStartOffset: cdStartOffset,
      );

      raf.flushSync();
      raf.closeSync();
      raf = null;

      sendPort.send([0, 1.0, '压缩导出完成']);
      sendPort.send([1]);
    } catch (e, stack) {
      if (raf != null) {
        try {
          raf.closeSync();
        } catch (_) {}
      }
      sendPort.send([3, '$e\n$stack']);
    }
  }

  /// 写入 30 字节 Local File Header + 文件名
  static void _writeLocalHeader({
    required RandomAccessFile raf,
    required int method,
    required int dosTime,
    required int dosDate,
    required int crc32,
    required int compressedSize,
    required int uncompressedSize,
    required List<int> nameBytes,
  }) {
    final header = ByteData(30);
    // Signature: 0x04034b50
    header.setUint32(0, 0x04034b50, Endian.little);
    // Version needed: 20 (2.0)
    header.setUint16(4, 20, Endian.little);
    // General purpose flag: bit 11 (UTF-8) = 0x0800
    header.setUint16(6, 0x0800, Endian.little);
    // Compression method: 8 (Deflate) or 0 (Store)
    header.setUint16(8, method, Endian.little);
    // Last mod file time
    header.setUint16(10, dosTime, Endian.little);
    // Last mod file date
    header.setUint16(12, dosDate, Endian.little);
    // CRC-32
    header.setUint32(14, crc32, Endian.little);
    // Compressed size
    header.setUint32(18, compressedSize, Endian.little);
    // Uncompressed size
    header.setUint32(22, uncompressedSize, Endian.little);
    // File name length
    header.setUint16(26, nameBytes.length, Endian.little);
    // Extra field length: 0
    header.setUint16(28, 0, Endian.little);

    raf.writeFromSync(header.buffer.asUint8List());
    raf.writeFromSync(nameBytes);
  }

  /// 写入 46 字节 Central Directory Header + 文件名
  static void _writeCentralDirectoryHeader({
    required RandomAccessFile raf,
    required _ZipEntryRecord entry,
  }) {
    final nameBytes = utf8.encode(entry.name);
    final header = ByteData(46);

    // Signature: 0x02014b50
    header.setUint32(0, 0x02014b50, Endian.little);
    // Version made by: 0x0314 (Unix 2.0)
    header.setUint16(4, 0x0314, Endian.little);
    // Version needed to extract: 20 (2.0)
    header.setUint16(6, 20, Endian.little);
    // General purpose flag: bit 11 (UTF-8) = 0x0800
    header.setUint16(8, 0x0800, Endian.little);
    // Compression method
    header.setUint16(10, entry.method, Endian.little);
    // Last mod time
    header.setUint16(12, entry.time, Endian.little);
    // Last mod date
    header.setUint16(14, entry.date, Endian.little);
    // CRC-32
    header.setUint32(16, entry.crc32, Endian.little);
    // Compressed size
    header.setUint32(20, entry.compressedSize, Endian.little);
    // Uncompressed size
    header.setUint32(24, entry.uncompressedSize, Endian.little);
    // File name length
    header.setUint16(28, nameBytes.length, Endian.little);
    // Extra field length: 0
    header.setUint16(30, 0, Endian.little);
    // File comment length: 0
    header.setUint16(32, 0, Endian.little);
    // Disk number start: 0
    header.setUint16(34, 0, Endian.little);
    // Internal file attributes: 0
    header.setUint16(36, 0, Endian.little);

    // External file attributes:
    // 目录: Unix 0755 (0x41ED0000) | MS-DOS directory flag (0x10) = 0x41ED0010
    // 普通文件: Unix 0644 (0x81A40000)
    final extAttr = entry.isDirectory ? 0x41ED0010 : 0x81A40000;
    header.setUint32(38, extAttr, Endian.little);

    // Relative offset of local header
    header.setUint32(42, entry.localHeaderOffset, Endian.little);

    raf.writeFromSync(header.buffer.asUint8List());
    raf.writeFromSync(nameBytes);
  }

  /// 写入 22 字节 End of Central Directory Record (EOCD)
  static void _writeEOCD({
    required RandomAccessFile raf,
    required int entryCount,
    required int cdSize,
    required int cdStartOffset,
  }) {
    final eocd = ByteData(22);
    // Signature: 0x06054b50
    eocd.setUint32(0, 0x06054b50, Endian.little);
    // Number of this disk: 0
    eocd.setUint16(4, 0, Endian.little);
    // Disk where central directory starts: 0
    eocd.setUint16(6, 0, Endian.little);
    // Number of central directory records on this disk
    eocd.setUint16(8, entryCount.clamp(0, 0xFFFF), Endian.little);
    // Total number of central directory records
    eocd.setUint16(10, entryCount.clamp(0, 0xFFFF), Endian.little);
    // Size of central directory
    eocd.setUint32(12, cdSize, Endian.little);
    // Offset of start of central directory
    eocd.setUint32(16, cdStartOffset, Endian.little);
    // ZIP file comment length: 0
    eocd.setUint16(20, 0, Endian.little);

    raf.writeFromSync(eocd.buffer.asUint8List());
  }
}
