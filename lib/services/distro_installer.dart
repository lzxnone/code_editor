import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'low_memory_xz_decoder.dart';

final RegExp _paxRecordRegexp = RegExp(r"(\d+) (\w+)=(.*)");

/// 安装进度回调
/// [progress] 0.0 ~ 1.0
/// [message] 当前阶段说明
typedef InstallProgressCallback = void Function(double progress, String message);

/// 取消安装异常
class DistroInstallCancelledException implements Exception {
  final String message;
  DistroInstallCancelledException([this.message = '用户已取消系统导入']);

  @override
  String toString() => message;
}

class _ExtractIsolateParams {
  final String archivePath;
  final String targetDirPath;
  final SendPort sendPort;

  const _ExtractIsolateParams({
    required this.archivePath,
    required this.targetDirPath,
    required this.sendPort,
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

/// Linux 发行版 Rootfs 安装与解压服务
class DistroInstaller {
  /// 从本地文件流式解压并安装 Rootfs（低内存、防卡顿、支持 XZ/GZip/Tar）
  ///
  /// [archiveFile] 压缩包文件 (.tar.xz 或 .tar.gz)
  /// [targetDir] 目标解压目录 (即容器的 rootfs 路径)
  /// [onProgress] 进度回调
  /// [isCancelled] 外部取消检查函数
  static Future<void> installFromFile({
    required File archiveFile,
    required Directory targetDir,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      throw DistroInstallCancelledException();
    }

    if (!archiveFile.existsSync()) {
      throw ArgumentError('压缩包文件不存在: ${archiveFile.path}');
    }

    onProgress?.call(0.05, '正在校验与准备解压目录...');

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    try {
      // 全平台统一使用低内存流式 Isolate 解压引擎（稳定、确定性进度、低内存、零外部依赖）
      await _extractWithDartStreamIsolate(
        archiveFile: archiveFile,
        targetDir: targetDir,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

      if (isCancelled?.call() == true) {
        throw DistroInstallCancelledException();
      }

      // 阶段 3：执行系统配置与网络补丁
      onProgress?.call(0.92, '正在配置网络 DNS 与系统环境...');
      await postInstallConfigure(targetDir);

      onProgress?.call(1.0, '系统初始化就绪！');
    } catch (e) {
      // 若中途失败或取消，清理不完整的根目录
      try {
        if (targetDir.existsSync()) {
          targetDir.deleteSync(recursive: true);
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// 解压并安装内存字节流格式的 Rootfs 到目标目录（兼容已有内置 asset 资源包接口）
  static Future<void> installFromBytes({
    required Uint8List tarGzBytes,
    required Directory targetDir,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('distro_temp_');
    try {
      final tempFile = File(p.join(tempDir.path, 'archive.bin'));
      await tempFile.writeAsBytes(tarGzBytes, flush: true);
      await installFromFile(
        archiveFile: tempFile,
        targetDir: targetDir,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// 在独立后台 Isolate 中执行流式解压与逐文件直接落盘（避免生成几十万对象引发 OOM）
  static Future<void> _extractWithDartStreamIsolate({
    required File archiveFile,
    required Directory targetDir,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
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
        ),
      );

      isolate.addOnExitListener(exitPort.sendPort);
      exitPort.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('解压引擎意外退出'));
        }
      });

      cancelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (isCancelled?.call() == true) {
          isolate?.kill(priority: Isolate.immediate);
          if (!completer.isCompleted) {
            completer.completeError(DistroInstallCancelledException());
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

      if (!Platform.isWindows) {
        await _restoreModes(byMode);
      }
    } finally {
      cancelTimer?.cancel();
      receivePort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// Isolate 入口：低内存流式解压与逐文件直接落盘
  static Future<void> _extractIsolateEntry(_ExtractIsolateParams params) async {
    File? tempTarFile;
    try {
      params.sendPort.send([0, 0.10, '正在读取并解析系统压缩包...']);
      final archiveFile = File(params.archivePath);
      if (!archiveFile.existsSync()) {
        params.sendPort.send([3, '压缩包文件不存在: ${params.archivePath}']);
        return;
      }

      // 1. 检查头部魔数判断文件格式
      final raf = archiveFile.openSync(mode: FileMode.read);
      final magic = raf.readSync(6);
      raf.closeSync();

      final isXz = magic.length >= 6 &&
          magic[0] == 0xFD &&
          magic[1] == 0x37 &&
          magic[2] == 0x7A &&
          magic[3] == 0x58 &&
          magic[4] == 0x5A &&
          magic[5] == 0x00;

      final isGz = magic.length >= 2 && magic[0] == 0x1F && magic[1] == 0x8B;

      final targetDir = Directory(params.targetDirPath);
      final tempDir = targetDir.parent.existsSync()
          ? targetDir.parent
          : Directory.systemTemp;

      File tarToExtract;
      if (isXz) {
        params.sendPort.send([0, 0.12, '正在流式解压内核与文件系统结构 (XZ)...']);
        tempTarFile = File(p.join(
          tempDir.path,
          'temp_distro_extract_${DateTime.now().microsecondsSinceEpoch}.tar',
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
              final frac = archiveSize > 0
                  ? (compPos / archiveSize).clamp(0.0, 1.0)
                  : 0.0;
              final prog = 0.12 + frac * 0.38; // 0.12 ~ 0.50
              final mb = (decompressed / (1024 * 1024)).toStringAsFixed(1);
              params.sendPort.send([0, prog, '正在解压系统文件 ($mb MB)...']);
            },
          );
        } finally {
          await tarSink.flush();
          await tarSink.close();
          await inputStream.close();
        }
        tarToExtract = tempTarFile;
      } else if (isGz) {
        params.sendPort.send([0, 0.12, '正在流式解压内核与文件系统结构 (GZip)...']);
        tempTarFile = File(p.join(
          tempDir.path,
          'temp_distro_extract_${DateTime.now().microsecondsSinceEpoch}.tar',
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
      } else {
        tarToExtract = archiveFile;
      }

      // 2. 流式释放 TAR 文件到目标根目录
      params.sendPort.send([0, 0.50, '正在释放系统文件...']);
      final byMode = await _streamExtractTarFile(
        tarFile: tarToExtract,
        targetDirPath: params.targetDirPath,
        sendPort: params.sendPort,
        progressStart: 0.50,
        progressEnd: 0.90,
      );

      params.sendPort.send([1, byMode]);
    } catch (e) {
      params.sendPort.send([3, e.toString()]);
    } finally {
      if (tempTarFile != null && tempTarFile.existsSync()) {
        try {
          tempTarFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 流式逐条解析 TAR 文件并直接落盘
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

        if (th.filename == '././@LongLink') {
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

        if (filename.contains('..')) {
          if (th.fileSize > 0) {
            input.skip(th.fileSize);
            final remainder = th.fileSize % 512;
            if (remainder != 0) input.skip(512 - remainder);
          }
          continue;
        }

        final outPath = p.join(targetDirPath, filename);

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
        if (processed % 150 == 0) {
          final fraction = totalLen > 0 ? (input.position / totalLen).clamp(0.0, 1.0) : 0.0;
          final prog = progressStart + fraction * (progressEnd - progressStart);
          sendPort.send([0, prog, '正在释放系统文件 ($processed)...']);
        }
      }
    } finally {
      await input.close();
    }

    return byMode;
  }


  /// 按 tar 头恢复权限位（dart:io 无 chmod，按 mode 分组批量调用，避免逐文件 fork）
  static Future<void> _restoreModes(Map<int, List<String>> byMode) async {
    for (final entry in byMode.entries) {
      final octal = entry.key.toRadixString(8).padLeft(4, '0');
      final paths = entry.value;
      // 单次 chmod 的参数长度有限，分批执行
      const batch = 100;
      for (var i = 0; i < paths.length; i += batch) {
        final end = (i + batch < paths.length) ? i + batch : paths.length;
        final slice = paths.sublist(i, end);
        try {
          await Process.run('chmod', [octal, ...slice]);
        } catch (e) {
          debugPrint('[DistroInstaller] 恢复权限失败 ($octal): $e');
        }
      }
    }
  }

  /// 容器可用的 DNS 解析器（按"可达优先"排序：国内公共 DNS 在前）
  static const String guestResolvConf = '# Generated by CodeEditor\n'
      'nameserver 223.5.5.5\n'
      'nameserver 119.29.29.29\n'
      'nameserver 1.1.1.1\n'
      'nameserver 114.114.114.114\n';

  /// 自动化环境补丁与配置
  ///
  /// 只做"发行版自身不会做、但容器化必需"的事：DNS、hosts、镜像源、
  /// 挂载点目录、shim 部署。**不再改写 guest 的 /etc/profile** —— 那会破坏
  /// 非 Alpine 发行版自带的登录环境（Alpine 原版 profile 与本项目此前写入的
  /// 模板逐行相同，所以删掉它对 Alpine 没有任何影响）。
  static Future<void> postInstallConfigure(Directory rootfsDir) async {
    final etcDir = Directory(p.join(rootfsDir.path, 'etc'));
    if (!etcDir.existsSync()) {
      etcDir.createSync(recursive: true);
    }

    // 1. 配置 DNS 解析器
    final resolvFile = File(p.join(etcDir.path, 'resolv.conf'));
    try {
      resolvFile.writeAsStringSync(guestResolvConf);
    } catch (e) {
      debugPrint('[DistroInstaller] 写入 resolv.conf 失败: $e');
    }

    // 2. 配置 hosts
    final hostsFile = File(p.join(etcDir.path, 'hosts'));
    try {
      hostsFile.writeAsStringSync(
        '127.0.0.1 localhost\n'
        '::1 localhost ip6-localhost ip6-loopback\n',
      );
    } catch (e) {
      debugPrint('[DistroInstaller] 写入 hosts 失败: $e');
    }

    // 3. 配置软件源镜像（按发行版自动适配，国内高速镜像）
    final apkDir = Directory(p.join(etcDir.path, 'apk'));
    if (apkDir.existsSync()) {
      // 3.1 Alpine apk 软件源镜像（使用阿里云高速镜像，自适应主版本号）
      var alpineVer = 'v3.20';
      final alpineRel = File(p.join(etcDir.path, 'alpine-release'));
      if (alpineRel.existsSync()) {
        try {
          final relStr = alpineRel.readAsStringSync().trim();
          final match = RegExp(r'^(\d+\.\d+)').firstMatch(relStr);
          if (match != null) {
            alpineVer = 'v${match.group(1)}';
          }
        } catch (_) {}
      }
      final repoFile = File(p.join(apkDir.path, 'repositories'));
      try {
        repoFile.writeAsStringSync(
          'https://mirrors.aliyun.com/alpine/$alpineVer/main\n'
          'https://mirrors.aliyun.com/alpine/$alpineVer/community\n',
        );
      } catch (e) {
        debugPrint('[DistroInstaller] 写入 repositories 失败: $e');
      }
    }

    // 4. 自动部署根证书（解决最小化 Linux 发行版缺少 ca-certificates 导致 https 证书验证失败）
    await ensureCaCertificates(rootfsDir);

    final aptDir = Directory(p.join(etcDir.path, 'apt'));
    if (aptDir.existsSync()) {
      final sourcesD = Directory(p.join(aptDir.path, 'sources.list.d'));
      final ubuntuSources = File(p.join(sourcesD.path, 'ubuntu.sources'));
      final isUbuntu = ubuntuSources.existsSync() ||
          (File(p.join(etcDir.path, 'os-release')).existsSync() &&
              File(p.join(etcDir.path, 'os-release')).readAsStringSync().toLowerCase().contains('ubuntu'));

      if (isUbuntu) {
        // 3.2 Ubuntu deb822 源配置（清华大学高速镜像）
        if (!sourcesD.existsSync()) sourcesD.createSync(recursive: true);
        try {
          final isArm = (Abi.current() == Abi.androidArm64 || Abi.current() == Abi.linuxArm64);
          final mirrorUri = isArm
              ? 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/'
              : 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu/';
          ubuntuSources.writeAsStringSync(
            'Types: deb\n'
            'URIs: $mirrorUri\n'
            'Suites: noble noble-updates noble-backports noble-security\n'
            'Components: main universe restricted multiverse\n'
            'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n',
          );
        } catch (e) {
          debugPrint('[DistroInstaller] 写入 ubuntu.sources 失败: $e');
        }
      } else {
        // 3.3 Debian 源配置（清华大学高速镜像）
        final debianSources = File(p.join(sourcesD.path, 'debian.sources'));
        final sourcesList = File(p.join(aptDir.path, 'sources.list'));
        try {
          sourcesList.writeAsStringSync(
            'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware\n'
            'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware\n'
            'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware\n'
            'deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware\n',
          );
          if (debianSources.existsSync()) {
            debianSources.writeAsStringSync(
              'Types: deb\n'
              'URIs: https://mirrors.tuna.tsinghua.edu.cn/debian/\n'
              'Suites: bookworm bookworm-updates bookworm-backports\n'
              'Components: main contrib non-free non-free-firmware\n'
              'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n'
              '\n'
              'Types: deb\n'
              'URIs: https://mirrors.tuna.tsinghua.edu.cn/debian-security\n'
              'Suites: bookworm-security\n'
              'Components: main contrib non-free non-free-firmware\n'
              'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n',
            );
          }
        } catch (e) {
          debugPrint('[DistroInstaller] 写入 debian sources 失败: $e');
        }
      }
    }

    // 3.4 Arch Linux pacman 源配置（清华大学高速镜像）
    final pacmanDir = Directory(p.join(etcDir.path, 'pacman.d'));
    if (pacmanDir.existsSync()) {
      final mirrorlist = File(p.join(pacmanDir.path, 'mirrorlist'));
      try {
        mirrorlist.writeAsStringSync(
          'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch\n'
          'Server = https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch\n',
        );
      } catch (e) {
        debugPrint('[DistroInstaller] 写入 Arch mirrorlist 失败: $e');
      }
    }

    // 3.5 Fedora yum/dnf 源配置（清华大学高速镜像）
    final yumDir = Directory(p.join(etcDir.path, 'yum.repos.d'));
    if (yumDir.existsSync()) {
      final fedoraRepo = File(p.join(yumDir.path, 'fedora.repo'));
      if (fedoraRepo.existsSync()) {
        try {
          var content = fedoraRepo.readAsStringSync();
          content = content.replaceAll('metalink=', '#metalink=');
          content = content.replaceAll(
            '#baseurl=http://download.example/pub/fedora/linux/',
            'baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora/',
          );
          fedoraRepo.writeAsStringSync(content);
        } catch (e) {
          debugPrint('[DistroInstaller] 写入 Fedora repo 失败: $e');
        }
      }
    }

    // 5. 确保 /workspace 挂载点目录存在
    final workspaceDir = Directory(p.join(rootfsDir.path, 'workspace'));
    if (!workspaceDir.existsSync()) {
      workspaceDir.createSync(recursive: true);
    }

    // 6. 确保 /tmp 目录存在
    final tmpDir = Directory(p.join(rootfsDir.path, 'tmp'));
    if (!tmpDir.existsSync()) {
      tmpDir.createSync(recursive: true);
    }

    // 7. 部署容器修复 Shim（libfix_seccomp.so）
    await ensureSeccompShim(rootfsDir);

    // 8. 自动配置 Java 运行时动态链接路径
    await ensureJavaConfiguration(rootfsDir);
  }

  /// 自动部署标准 SSL CA 证书链（让 APT / Curl / Git 默认支持 HTTPS）
  static Future<void> ensureCaCertificates(Directory rootfsDir) async {
    try {
      final certsDir = Directory(p.join(rootfsDir.path, 'etc', 'ssl', 'certs'));
      if (!certsDir.existsSync()) {
        certsDir.createSync(recursive: true);
      }
      final targetCert = File(p.join(certsDir.path, 'ca-certificates.crt'));
      if (!targetCert.existsSync() || targetCert.lengthSync() == 0) {
        final byteData = await rootBundle.load('assets/certs/ca-certificates.crt');
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        await targetCert.writeAsBytes(bytes, flush: true);

        // 建立标准符号链接以兼容 OpenSSL/GnuTLS 默认寻找路径
        final etcSslDir = Directory(p.join(rootfsDir.path, 'etc', 'ssl'));
        final certPem = Link(p.join(etcSslDir.path, 'cert.pem'));
        if (!certPem.existsSync()) {
          try {
            certPem.createSync('certs/ca-certificates.crt');
          } catch (_) {}
        }
        debugPrint('[DistroInstaller] 成功注入根证书链: ${targetCert.path}');
      }
    } catch (e) {
      debugPrint('[DistroInstaller] 注入根证书链异常 (非阻塞): $e');
    }
  }

  /// 部署容器修复 Shim（libfix_seccomp.so）
  ///
  /// 它只做两件在 Android app 进程里必需的事：
  /// 1. `utimensat()`（两个架构）：Android 不允许应用数据区创建硬链接，PRoot
  ///    的 `--link2symlink` 用 symlink + 隐藏记账文件模拟硬链接，导致 apk
  ///    保 mtime 时跟随解析失败（`Failed to preserve modification time`）。
  /// 2. `poll/select/pipe/dup2`（仅 x86_64）：Android 的 app seccomp 策略把这些
  ///    传统 syscall 返回 ENOSYS，而 musl 在有这些调用的架构上优先用它们。
  static Future<void> ensureSeccompShim(Directory rootfsDir) async {
    final libDir = Directory(p.join(rootfsDir.path, 'lib'));
    if (!libDir.existsSync() && !FileSystemEntity.isLinkSync(libDir.path)) {
      try {
        libDir.createSync(recursive: true);
      } catch (_) {}
    }
    final targetShim = File(p.join(libDir.path, 'libfix_seccomp.so'));

    String? archFolder;
    if (Platform.isAndroid || Platform.isLinux) {
      final currentAbi = Abi.current();
      if (currentAbi == Abi.androidX64 || currentAbi == Abi.linuxX64) {
        archFolder = 'x86_64';
      } else if (currentAbi == Abi.androidArm64 || currentAbi == Abi.linuxArm64) {
        archFolder = 'arm64-v8a';
      }
    }
    if (archFolder == null) return;

    try {
      final assetPath = 'assets/shims/$archFolder/libfix_seccomp.so';
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      // 如果目标文件已存在且大小一致，则跳过写入
      if (targetShim.existsSync() && targetShim.lengthSync() == bytes.length) {
        return;
      }

      await targetShim.writeAsBytes(bytes, flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['755', targetShim.path]);
      }
      debugPrint('[DistroInstaller] 成功部署 SECCOMP Shim: ${targetShim.path}');
    } catch (e) {
      debugPrint('[DistroInstaller] 部署 SECCOMP Shim 失败: $e');
    }
  }

  /// 自动探测并适配 OpenJDK 运行环境（解决 Debian/Ubuntu 等发行版下 /usr/bin/java
  /// 符号链接调用时找不到 libjli.so / libjvm.so 的问题）
  static Future<void> ensureJavaConfiguration(Directory rootfsDir) async {
    try {
      final jvmDir = Directory(p.join(rootfsDir.path, 'usr', 'lib', 'jvm'));
      if (!jvmDir.existsSync()) return;

      final javaConfLines = <String>[];
      final jvmEntries = jvmDir.listSync();
      for (final entry in jvmEntries) {
        if (entry is Directory) {
          final guestJvmBase = '/usr/lib/jvm/${p.basename(entry.path)}';
          final libDir = Directory(p.join(entry.path, 'lib'));
          if (libDir.existsSync()) {
            javaConfLines.add('$guestJvmBase/lib');
            final serverDir = Directory(p.join(libDir.path, 'server'));
            if (serverDir.existsSync()) {
              javaConfLines.add('$guestJvmBase/lib/server');
            }
          }
        }
      }

      if (javaConfLines.isNotEmpty) {
        final ldConfD = Directory(p.join(rootfsDir.path, 'etc', 'ld.so.conf.d'));
        if (!ldConfD.existsSync()) {
          ldConfD.createSync(recursive: true);
        }
        final javaConfFile = File(p.join(ldConfD.path, 'java.conf'));
        final newContent = '${javaConfLines.join('\n')}\n';
        if (!javaConfFile.existsSync() || javaConfFile.readAsStringSync() != newContent) {
          javaConfFile.writeAsStringSync(newContent);
          debugPrint('[DistroInstaller] 自动配置 /etc/ld.so.conf.d/java.conf');
        }
      }
    } catch (e) {
      debugPrint('[DistroInstaller] 配置 Java ld.so 失败 (非阻塞): $e');
    }
  }
}
