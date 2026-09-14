import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/services/distro_image_resolver.dart';
import 'package:code_editor/services/distro_installer.dart';
import 'package:code_editor/services/low_memory_xz_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleIndexSystem = '''
# LXC Images Mirror index
debian;bookworm;arm64;default;20260912_05:24;/images/debian/bookworm/arm64/default/20260912_05:24/
debian;bookworm;arm64;default;20260913_05:24;/images/debian/bookworm/arm64/default/20260913_05:24/
debian;bookworm;amd64;default;20260913_05:24;/images/debian/bookworm/amd64/default/20260913_05:24/
archlinux;current;arm64;default;20260913_04:18;/images/archlinux/current/arm64/default/20260913_04:18/
archlinux;current;amd64;default;20260913_04:18;/images/archlinux/current/amd64/default/20260913_04:18/
fedora;43;arm64;default;20260913_20:33;/images/fedora/43/arm64/default/20260913_20:33/
fedora;43;amd64;default;20260913_20:33;/images/fedora/43/amd64/default/20260913_20:33/
''';

  group('DistroIndexEntry & DistroImageResolver Tests', () {
    late DistroImageResolver resolver;

    setUp(() {
      resolver = DistroImageResolver();
      resolver.invalidateCache();
      resolver.customIndexContent = sampleIndexSystem;
    });

    tearDown(() {
      resolver.customIndexContent = null;
      resolver.invalidateCache();
    });

    test('parseIndex extracts all valid entries', () {
      final entries = DistroImageResolver.parseIndex(sampleIndexSystem);
      expect(entries.length, 7);
      expect(entries.first.distribution, 'debian');
      expect(entries.first.release, 'bookworm');
      expect(entries.first.arch, 'arm64');
      expect(entries.first.variant, 'default');
      expect(entries.first.buildDate, '20260912_05:24');
      expect(entries.first.path, '/images/debian/bookworm/arm64/default/20260912_05:24/');
    });

    test('toLxcArch maps arm64 and x86_64 correctly', () {
      expect(DistroImageResolver.toLxcArch(DistroArch.arm64), 'arm64');
      expect(DistroImageResolver.toLxcArch(DistroArch.x86_64), 'amd64');
    });

    test('resolveDownloadUrl picks latest build date for debian arm64', () async {
      final debian = DistroRepository.getById('debian')!;
      final tsinghua = DistroRepository.getMirrorById('tsinghua');

      final url = await resolver.resolveDownloadUrl(
        item: debian,
        arch: DistroArch.arm64,
        mirror: tsinghua,
      );

      // 应该选择 20260913_05:24 而不是旧的 20260912_05:24
      expect(
        url,
        'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/bookworm/arm64/default/20260913_05:24/rootfs.tar.xz',
      );
    });

    test('resolveDownloadUrl resolves archlinux on different mirrors', () async {
      final arch = DistroRepository.getById('arch')!;
      final bfsu = DistroRepository.getMirrorById('bfsu');

      final url = await resolver.resolveDownloadUrl(
        item: arch,
        arch: DistroArch.x86_64,
        mirror: bfsu,
      );

      expect(
        url,
        'https://mirrors.bfsu.edu.cn/lxc-images/images/archlinux/current/amd64/default/20260913_04:18/rootfs.tar.xz',
      );
    });

    test('resolveDownloadUrl resolves fedora 43 arm64', () async {
      final fedora = DistroRepository.getById('fedora')!;
      final iscas = DistroRepository.getMirrorById('iscas');

      final url = await resolver.resolveDownloadUrl(
        item: fedora,
        arch: DistroArch.arm64,
        mirror: iscas,
      );

      expect(
        url,
        'https://mirror.iscas.ac.cn/lxc-images/images/fedora/43/arm64/default/20260913_20:33/rootfs.tar.xz',
      );
    });

    test('resolveDownloadUrl throws HttpException when image is not in index', () async {
      const emptyIndex = '# Empty index\n';
      resolver.customIndexContent = emptyIndex;

      final debian = DistroRepository.getById('debian')!;
      final tsinghua = DistroRepository.getMirrorById('tsinghua');

      expect(
        () => resolver.resolveDownloadUrl(
          item: debian,
          arch: DistroArch.arm64,
          mirror: tsinghua,
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('resolveDownloadUrl returns builtin asset path directly for builtin distro', () async {
      final alpine = DistroRepository.getById('alpine')!;
      final tsinghua = DistroRepository.getMirrorById('tsinghua');

      final url = await resolver.resolveDownloadUrl(
        item: alpine,
        arch: DistroArch.arm64,
        mirror: tsinghua,
      );

      expect(url, 'assets/distros/alpine-minirootfs-3.20.3-aarch64.tar.gz');
    });
  });

  group('DistroInstaller Archive Decoding Tests', () {
    test('installFromBytes succeeds with valid TarGz archive bytes', () async {
      // 创建包含一个测试文件的 TarGz 内存包
      final archive = Archive();
      archive.addFile(ArchiveFile('test.txt', 5, utf8.encode('hello')));
      final tarBytes = TarEncoder().encode(archive);
      final gzBytes = Uint8List.fromList(GZipEncoder().encode(tarBytes)!);

      final tempDir = Directory.systemTemp.createTempSync('installer_test_');
      try {
        await DistroInstaller.installFromBytes(
          tarGzBytes: gzBytes,
          targetDir: tempDir,
        );

        final testFile = File('${tempDir.path}/test.txt');
        expect(testFile.existsSync(), isTrue);
        expect(testFile.readAsStringSync(), 'hello');
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('installFromBytes succeeds with valid TarXZ archive bytes', () async {
      // 创建包含一个测试文件的 TarXZ 内存包
      final archive = Archive();
      archive.addFile(ArchiveFile('greet.txt', 5, utf8.encode('world')));
      final tarBytes = TarEncoder().encode(archive);
      final xzBytes = encodeValidXz(tarBytes);

      final tempDir = Directory.systemTemp.createTempSync('installer_xz_test_');
      try {
        await DistroInstaller.installFromBytes(
          tarGzBytes: xzBytes,
          targetDir: tempDir,
        );

        final testFile = File('${tempDir.path}/greet.txt');
        expect(testFile.existsSync(), isTrue);
        expect(testFile.readAsStringSync(), 'world');
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('installFromFile directly extracts TarXZ file on disk', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('direct.txt', 6, utf8.encode('direct')));
      final tarBytes = TarEncoder().encode(archive);
      final xzBytes = encodeValidXz(tarBytes);

      final tempDir = Directory.systemTemp.createTempSync('installer_file_test_');
      final archiveFile = File('${tempDir.path}/test.tar.xz');
      archiveFile.writeAsBytesSync(xzBytes);

      final outDir = Directory('${tempDir.path}/rootfs');
      try {
        await DistroInstaller.installFromFile(
          archiveFile: archiveFile,
          targetDir: outDir,
        );

        final testFile = File('${outDir.path}/direct.txt');
        expect(testFile.existsSync(), isTrue);
        expect(testFile.readAsStringSync(), 'direct');
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('installFromFile cancellation throws DistroInstallCancelledException and rolls back targetDir', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('cancel.txt', 6, utf8.encode('cancel')));
      final tarBytes = TarEncoder().encode(archive);
      final xzBytes = encodeValidXz(tarBytes);

      final tempDir = Directory.systemTemp.createTempSync('installer_cancel_test_');
      final archiveFile = File('${tempDir.path}/test.tar.xz');
      archiveFile.writeAsBytesSync(xzBytes);

      final outDir = Directory('${tempDir.path}/rootfs');
      try {
        expect(
          () => DistroInstaller.installFromFile(
            archiveFile: archiveFile,
            targetDir: outDir,
            isCancelled: () => true,
          ),
          throwsA(isA<DistroInstallCancelledException>()),
        );

        // 验证回滚：目标目录不残留
        expect(outDir.existsSync(), isFalse);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('LowMemoryXZDecoder decodes valid XZ stream directly to sink', () async {
      final inputBytes = utf8.encode('Low memory streaming XZ decoding test string! 1234567890');
      final xzBytes = encodeValidXz(inputBytes);

      final tempDir = Directory.systemTemp.createTempSync('low_mem_xz_test_');
      final outFile = File('${tempDir.path}/out.bin');
      final outSink = outFile.openWrite();

      final decoder = LowMemoryXZDecoder();
      var progressFired = false;
      try {
        decoder.decodeToSink(
          InputStream(xzBytes),
          outSink,
          onProgress: (decompressed, compPos) {
            progressFired = true;
          },
        );
      } finally {
        await outSink.flush();
        await outSink.close();
      }

      expect(outFile.existsSync(), isTrue);
      expect(outFile.readAsBytesSync(), inputBytes);
      expect(progressFired, isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('installFromFile extracts multiple files, subdirectories and reports progress', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('sub/dir/one.txt', 5, utf8.encode('one..')));
      archive.addFile(ArchiveFile('sub/dir/two.txt', 5, utf8.encode('two..')));
      archive.addFile(ArchiveFile('root.txt', 4, utf8.encode('root')));
      final tarBytes = TarEncoder().encode(archive);
      final xzBytes = encodeValidXz(tarBytes);

      final tempDir = Directory.systemTemp.createTempSync('installer_multi_test_');
      final archiveFile = File('${tempDir.path}/distro.tar.xz');
      archiveFile.writeAsBytesSync(xzBytes);

      final outDir = Directory('${tempDir.path}/rootfs');
      final progressList = <double>[];

      try {
        await DistroInstaller.installFromFile(
          archiveFile: archiveFile,
          targetDir: outDir,
          onProgress: (prog, msg) {
            progressList.add(prog);
          },
        );

        expect(File('${outDir.path}/sub/dir/one.txt').readAsStringSync(), 'one..');
        expect(File('${outDir.path}/sub/dir/two.txt').readAsStringSync(), 'two..');
        expect(File('${outDir.path}/root.txt').readAsStringSync(), 'root');
        expect(progressList.isNotEmpty, isTrue);
        expect(progressList.last, 1.0);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}

/// 遵循标准 LEB128 与 XZ 格式的纯 Dart 辅助编码器（避免 archive 包中 XZEncoder 的多字节大端序 bug）
Uint8List encodeValidXz(List<int> data) {
  void writeLeb128(BytesBuilder out, int value) {
    while (value >= 0x80) {
      out.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    out.addByte(value & 0x7f);
  }

  final out = BytesBuilder();
  out.add([253, 55, 122, 88, 90, 0]); // Header magic
  final headerFlags = [0, 0];
  out.add(headerFlags);
  final headerCrc = getCrc32(headerFlags);
  out.add([headerCrc & 0xff, (headerCrc >> 8) & 0xff, (headerCrc >> 16) & 0xff, (headerCrc >> 24) & 0xff]);

  final lzma2 = BytesBuilder();
  var offset = 0;
  var isFirst = true;
  while (offset < data.length) {
    final chunkLen = (data.length - offset).clamp(1, 65536);
    lzma2.addByte(isFirst ? 1 : 2);
    isFirst = false;
    final lenMinusOne = chunkLen - 1;
    lzma2.addByte((lenMinusOne >> 8) & 0xff);
    lzma2.addByte(lenMinusOne & 0xff);
    lzma2.add(data.sublist(offset, offset + chunkLen));
    offset += chunkLen;
  }
  lzma2.addByte(0); // end marker

  final lzma2Bytes = lzma2.toBytes();

  final filter = BytesBuilder();
  writeLeb128(filter, 0x21); // LZMA2
  writeLeb128(filter, 1);
  filter.addByte(0); // dict size

  final filterBytes = filter.toBytes();
  final headerSizeWithoutCrc = 1 + 1 + filterBytes.length;
  final paddingHeader = (4 - ((headerSizeWithoutCrc + 4) % 4)) % 4;
  final totalHeaderSize = headerSizeWithoutCrc + paddingHeader + 4;

  final blockHeader = BytesBuilder();
  blockHeader.addByte((totalHeaderSize ~/ 4) - 1);
  blockHeader.addByte(0); // flags
  blockHeader.add(filterBytes);
  for (var i = 0; i < paddingHeader; i++) {
    blockHeader.addByte(0);
  }
  final bhBytes = blockHeader.toBytes();
  final bhCrc = getCrc32(bhBytes);

  final blockStart = out.length;
  out.add(bhBytes);
  out.add([bhCrc & 0xff, (bhCrc >> 8) & 0xff, (bhCrc >> 16) & 0xff, (bhCrc >> 24) & 0xff]);
  out.add(lzma2Bytes);

  final paddingBlock = (4 - (out.length % 4)) % 4;
  for (var i = 0; i < paddingBlock; i++) {
    out.addByte(0);
  }

  final unpaddedLength = out.length - blockStart - paddingBlock;

  final indexStart = out.length;
  final index = BytesBuilder();
  index.addByte(0); // indicator
  writeLeb128(index, 1);
  writeLeb128(index, unpaddedLength);
  writeLeb128(index, data.length);
  while (index.length % 4 != 0) {
    index.addByte(0);
  }
  final indexBytes = index.toBytes();
  final indexCrc = getCrc32(indexBytes);
  out.add(indexBytes);
  out.add([indexCrc & 0xff, (indexCrc >> 8) & 0xff, (indexCrc >> 16) & 0xff, (indexCrc >> 24) & 0xff]);
  final indexTotalSize = out.length - indexStart;

  final footer = BytesBuilder();
  final indexSizeField = (indexTotalSize ~/ 4) - 1;
  footer.add([indexSizeField & 0xff, (indexSizeField >> 8) & 0xff, (indexSizeField >> 16) & 0xff, (indexSizeField >> 24) & 0xff]);
  footer.add([0, 0]);
  final footerBytes = footer.toBytes();
  final footerCrc = getCrc32(footerBytes);
  out.add([footerCrc & 0xff, (footerCrc >> 8) & 0xff, (footerCrc >> 16) & 0xff, (footerCrc >> 24) & 0xff]);
  out.add(footerBytes);
  out.add([89, 90]); // 'YZ'

  return out.toBytes();
}
