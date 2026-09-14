import 'dart:io';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/toolchain_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ToolchainService Tool Detection Tests', () {
    test('detectRequiredTools extracts compiler and runtime tools correctly', () {
      expect(
        ToolchainService.detectRequiredTools('make').map((r) => r.checkBinary),
        contains('make'),
      );

      expect(
        ToolchainService.detectRequiredTools('cmake -B build && cmake --build build').map((r) => r.checkBinary),
        contains('cmake'),
      );

      expect(
        ToolchainService.detectRequiredTools('gcc "./main.c" -o /tmp/a.out && /tmp/a.out').map((r) => r.checkBinary),
        contains('gcc'),
      );

      expect(
        ToolchainService.detectRequiredTools('g++ "./main.cpp" -o /tmp/a.out').map((r) => r.checkBinary),
        contains('g++'),
      );

      expect(
        ToolchainService.detectRequiredTools('python3 "./script.py"').map((r) => r.checkBinary),
        contains('python3'),
      );

      expect(
        ToolchainService.detectRequiredTools('npm start').map((r) => r.checkBinary),
        contains('npm'),
      );

      expect(
        ToolchainService.detectRequiredTools('node app.js').map((r) => r.checkBinary),
        contains('node'),
      );

      expect(
        ToolchainService.detectRequiredTools('cargo run').map((r) => r.checkBinary),
        contains('cargo'),
      );

      expect(
        ToolchainService.detectRequiredTools('rustc main.rs').map((r) => r.checkBinary),
        contains('rustc'),
      );

      expect(
        ToolchainService.detectRequiredTools('go run main.go').map((r) => r.checkBinary),
        contains('go'),
      );

      expect(
        ToolchainService.detectRequiredTools('./gradlew assembleDebug').map((r) => r.checkBinary),
        contains('java'),
      );

      expect(
        ToolchainService.detectRequiredTools('sh ./gradlew run').map((r) => r.checkBinary),
        contains('java'),
      );

      expect(
        ToolchainService.detectRequiredTools('echo "hello world" && ls -la'),
        isEmpty,
      );
    });

    test('detectRequiredTools deduplicates multiple calls to the same tool', () {
      final reqs = ToolchainService.detectRequiredTools('cmake -B build && cmake --build build');
      expect(reqs.length, equals(1));
      expect(reqs.first.checkBinary, equals('cmake'));
    });
  });

  group('ToolchainService Command Resolution Tests', () {
    test('unknown distro returns raw command directly without modification', () {
      const cmd = 'make';
      final resolved = ToolchainService.resolveCommand(cmd, DistroFamily.unknown);
      expect(resolved, equals('make'));
    });

    test('non-toolchain command returns raw command directly', () {
      const cmd = 'echo "test" && ls -la';
      final resolved = ToolchainService.resolveCommand(cmd, DistroFamily.ubuntu);
      expect(resolved, equals('echo "test" && ls -la'));
    });

    test('Alpine generates apk install preamble for make', () {
      final resolved = ToolchainService.resolveCommand('make', DistroFamily.alpine);
      expect(resolved, contains('command -v make'));
      expect(resolved, contains('apk update && apk add --no-cache make build-base'));
      expect(resolved, contains('make 编译构建工具'));
      expect(resolved, endsWith('&& (make)'));
    });

    test('Ubuntu generates apt-get install preamble for make', () {
      final resolved = ToolchainService.resolveCommand('make', DistroFamily.ubuntu);
      expect(resolved, contains('command -v make'));
      expect(resolved, contains('apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential'));
      expect(resolved, contains('make 编译构建工具'));
      expect(resolved, endsWith('&& (make)'));
    });

    test('Debian generates apt-get install preamble for cmake', () {
      final resolved = ToolchainService.resolveCommand('cmake -B build', DistroFamily.debian);
      expect(resolved, contains('command -v cmake'));
      expect(resolved, contains('apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cmake build-essential'));
      expect(resolved, endsWith('&& (cmake -B build)'));
    });

    test('Arch generates pacman install preamble for gcc', () {
      final resolved = ToolchainService.resolveCommand('gcc main.c', DistroFamily.arch);
      expect(resolved, contains('command -v gcc'));
      expect(resolved, contains('pacman -Sy --noconfirm base-devel'));
      expect(resolved, endsWith('&& (gcc main.c)'));
    });

    test('Fedora generates dnf install preamble for python3', () {
      final resolved = ToolchainService.resolveCommand('python3 app.py', DistroFamily.fedora);
      expect(resolved, contains('command -v python3'));
      expect(resolved, contains('dnf install -y python3 python3-pip'));
      expect(resolved, endsWith('&& (python3 app.py)'));
    });

    test('Multiple tools generate multiple chained checks', () {
      final resolved = ToolchainService.resolveCommand('gcc main.c && python3 test.py', DistroFamily.ubuntu);
      expect(resolved, contains('command -v gcc'));
      expect(resolved, contains('command -v python3'));
      expect(resolved, contains('apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential'));
      expect(resolved, contains('apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip'));
      expect(resolved, endsWith('&& (gcc main.c && python3 test.py)'));
    });

    test('When tool is already physically installed in rootfs, resolveCommand returns raw command without any preamble', () {
      final tempRootfs = Directory.systemTemp.createTempSync('rootfs_installed_test_');
      try {
        final usrBin = Directory(p.join(tempRootfs.path, 'usr', 'bin'))..createSync(recursive: true);
        File(p.join(usrBin.path, 'make')).writeAsStringSync('#!/bin/sh\n');

        // make 已物理存在于 /usr/bin/make
        final resolved = ToolchainService.resolveCommand(
          'make',
          DistroFamily.debian,
          rootDir: tempRootfs,
        );

        // 核心断言：直接返回原命令 "make"，绝不包含任何多余脚本或回显！
        expect(resolved, equals('make'));
      } finally {
        if (tempRootfs.existsSync()) {
          try {
            tempRootfs.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('When tool is missing in rootfs, resolveCommand writes /root/.ce_setup.sh and executes it cleanly', () {
      final tempRootfs = Directory.systemTemp.createTempSync('rootfs_missing_test_');
      try {
        final resolved = ToolchainService.resolveCommand(
          'make',
          DistroFamily.debian,
          rootDir: tempRootfs,
        );

        // 生成了 /root/.ce_setup.sh
        final setupFile = File(p.join(tempRootfs.path, 'root', '.ce_setup.sh'));
        expect(setupFile.existsSync(), isTrue);
        expect(setupFile.readAsStringSync(), contains('build-essential'));

        // 终端仅执行简洁命令
        expect(resolved, equals('sh /root/.ce_setup.sh && (make)'));
      } finally {
        if (tempRootfs.existsSync()) {
          try {
            tempRootfs.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('When command is a multiline script, resolveCommand writes /root/.ce_task.sh and returns sh /root/.ce_task.sh', () {
      final tempRootfs = Directory.systemTemp.createTempSync('rootfs_multiline_test_');
      try {
        const multilineScript = '''
echo "Step 1: start"
mkdir -p output
echo "done" > output/result.txt
''';

        final resolved = ToolchainService.resolveCommand(
          multilineScript,
          DistroFamily.alpine,
          rootDir: tempRootfs,
        );

        expect(resolved, equals('sh /root/.ce_task.sh'));
        final taskFile = File(p.join(tempRootfs.path, 'root', '.ce_task.sh'));
        expect(taskFile.existsSync(), isTrue);
        final content = taskFile.readAsStringSync();
        expect(content, contains('#!/bin/sh'));
        expect(content, contains('set -e'));
        expect(content, contains('echo "Step 1: start"'));
        expect(content, contains('echo "done" > output/result.txt'));
        // 确保没有 Windows \r\n
        expect(content.contains('\r'), isFalse);
      } finally {
        if (tempRootfs.existsSync()) {
          try {
            tempRootfs.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('Multiline script with missing tools injects installer before script in .ce_task.sh', () {
      final tempRootfs = Directory.systemTemp.createTempSync('rootfs_multiline_tool_test_');
      try {
        const multilineScript = '''
gcc main.c -o app
./app
''';

        final resolved = ToolchainService.resolveCommand(
          multilineScript,
          DistroFamily.debian,
          rootDir: tempRootfs,
        );

        expect(resolved, equals('sh /root/.ce_task.sh'));
        final taskFile = File(p.join(tempRootfs.path, 'root', '.ce_task.sh'));
        expect(taskFile.existsSync(), isTrue);
        final content = taskFile.readAsStringSync();
        // 验证同时包含了安装引导与用户脚本
        expect(content, contains('build-essential'));
        expect(content, contains('gcc main.c -o app'));
      } finally {
        if (tempRootfs.existsSync()) {
          try {
            tempRootfs.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });
  });

  group('DistroManager detectDistroFamily Tests', () {
    late Directory tempBaseDir;
    late DistroManager manager;

    setUp(() {
      tempBaseDir = Directory.systemTemp.createTempSync('distro_detect_test_');
      manager = DistroManager();
      manager.customBaseDir = tempBaseDir;
    });

    tearDown(() {
      if (tempBaseDir.existsSync()) {
        try {
          tempBaseDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      manager.customBaseDir = null;
    });

    test('detects Alpine correctly from apk directory and release file', () async {
      final rootfs = Directory(p.join(tempBaseDir.path, 'my_alpine', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc', 'apk')).createSync(recursive: true);
      File(p.join(rootfs.path, 'etc', 'alpine-release')).writeAsStringSync('3.20.3\n');

      final family = await manager.detectDistroFamily('my_alpine');
      expect(family, equals(DistroFamily.alpine));
    });

    test('detects Ubuntu correctly from os-release and apt directory', () async {
      final rootfs = Directory(p.join(tempBaseDir.path, 'ubuntu_dev', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc', 'apt')).createSync(recursive: true);
      File(p.join(rootfs.path, 'etc', 'os-release')).writeAsStringSync('NAME="Ubuntu"\nID=ubuntu\nVERSION_ID="24.04"\n');

      final family = await manager.detectDistroFamily('ubuntu_dev');
      expect(family, equals(DistroFamily.ubuntu));
    });

    test('detects Debian correctly when apt is present without ubuntu markers', () async {
      final rootfs = Directory(p.join(tempBaseDir.path, 'debian_sys', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc', 'apt')).createSync(recursive: true);
      File(p.join(rootfs.path, 'etc', 'os-release')).writeAsStringSync('NAME="Debian GNU/Linux"\nID=debian\n');

      final family = await manager.detectDistroFamily('debian_sys');
      expect(family, equals(DistroFamily.debian));
    });

    test('detects Arch Linux correctly from pacman.d directory', () async {
      final rootfs = Directory(p.join(tempBaseDir.path, 'arch_sys', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc', 'pacman.d')).createSync(recursive: true);

      final family = await manager.detectDistroFamily('arch_sys');
      expect(family, equals(DistroFamily.arch));
    });

    test('detects Fedora correctly from yum.repos.d directory', () async {
      final rootfs = Directory(p.join(tempBaseDir.path, 'fedora_sys', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc', 'yum.repos.d')).createSync(recursive: true);

      final family = await manager.detectDistroFamily('fedora_sys');
      expect(family, equals(DistroFamily.fedora));
    });

    test('returns unknown for host system or unrecognized custom distro', () async {
      expect(await manager.detectDistroFamily('host'), equals(DistroFamily.unknown));

      final rootfs = Directory(p.join(tempBaseDir.path, 'custom_sys', 'rootfs'));
      Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
      expect(await manager.detectDistroFamily('custom_sys'), equals(DistroFamily.unknown));

      expect(await manager.detectDistroFamily('non_existent'), equals(DistroFamily.unknown));
    });
  });

  group('TerminalSession executeCommand Tests', () {
    test('executeCommand reports unstarted when PTY launch fails or is unstarted', () async {
      final session = TerminalSession(
        id: 'test_session',
        autoStartProcess: false,
      );

      await session.executeCommand('echo test');
      expect(session.bufferText, contains('无法执行命令：终端环境未启动或启动失败'));

      session.dispose();
    });

    test('clear resets terminal screen', () {
      final session = TerminalSession(
        id: 'test_clear_session',
        autoStartProcess: false,
      );
      session.write('Some previous output');
      session.clear();
      // clear emits VT100 ANSI sequences
      expect(session.bufferText.trim(), isEmpty);
      session.dispose();
    });
  });
}
