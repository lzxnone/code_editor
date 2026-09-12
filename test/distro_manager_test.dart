import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:code_editor/models/distro_info.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/services/distro_installer.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DistroManager manager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('distro_test_');
    manager = DistroManager();
    manager.customBaseDir = tempDir;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DistroManager & DistroInfo Tests', () {
    test('内置预设包含 Alpine, Debian, Ubuntu, Host', () {
      final distros = manager.listDistros();
      expect(distros.any((d) => d.id == 'alpine'), isTrue);
      expect(distros.any((d) => d.id == 'debian'), isTrue);
      expect(distros.any((d) => d.id == 'ubuntu'), isTrue);
      expect(distros.any((d) => d.id == 'host'), isTrue);

      final alpine = manager.getDistro('alpine');
      expect(alpine, isNotNull);
      expect(alpine!.packageManager, 'apk');
      expect(alpine.defaultShell, '/bin/sh');
      expect(alpine.assetPath, contains('alpine-minirootfs'));
    });

    test('支持动态扩展注册与注销自定义发行版', () {
      const customDistro = DistroInfo(
        id: 'archlinux',
        name: 'Arch Linux',
        version: 'Rolling',
        description: '滚动更新的极客发行版',
        packageManager: 'pacman',
        defaultShell: '/bin/bash',
        isBuiltin: false,
      );

      manager.registerDistro(customDistro);
      expect(manager.getDistro('archlinux'), isNotNull);
      expect(manager.getDistro('archlinux')!.name, 'Arch Linux');

      manager.unregisterDistro('archlinux');
      expect(manager.getDistro('archlinux'), isNull);
    });

    test('Host 本地环境默认视为已就绪', () async {
      final isInstalled = await manager.isInstalled('host');
      expect(isInstalled, isTrue);
    });

    test('未初始化的 Linux 容器返回 false', () async {
      final isInstalled = await manager.isInstalled('alpine');
      expect(isInstalled, isFalse);
    });
  });

  group('DistroInstaller 解压与网络配置测试', () {
    test('创建测试 tar.gz 并使用 DistroInstaller 解压与配置', () async {
      // 构造小型测试 tar.gz 镜像
      final archive = Archive();
      archive.addFile(ArchiveFile('bin/sh', 11, 'echo "sh"'.codeUnits));
      archive.addFile(ArchiveFile('etc/os-release', 18, 'NAME="Alpine Linux"'.codeUnits));

      final tarData = TarEncoder().encode(archive);
      final gzData = GZipEncoder().encode(tarData);

      final targetDir = Directory(p.join(tempDir.path, 'alpine', 'rootfs'));

      double lastProgress = 0.0;
      String lastMessage = '';

      await DistroInstaller.installFromBytes(
        tarGzBytes: Uint8List.fromList(gzData!),
        targetDir: targetDir,
        onProgress: (prog, msg) {
          lastProgress = prog;
          lastMessage = msg;
        },
      );

      expect(lastProgress, 1.0);
      expect(lastMessage, '系统初始化就绪！');

      // 验证文件解压成功
      expect(File(p.join(targetDir.path, 'bin', 'sh')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'etc', 'os-release')).existsSync(), isTrue);

      // 验证自动配置的 resolv.conf (DNS) 与 hosts
      final resolvFile = File(p.join(targetDir.path, 'etc', 'resolv.conf'));
      expect(resolvFile.existsSync(), isTrue);
      final resolvContent = resolvFile.readAsStringSync();
      expect(resolvContent, contains('nameserver 1.1.1.1'));
      expect(resolvContent, contains('nameserver 8.8.8.8'));

      final hostsFile = File(p.join(targetDir.path, 'etc', 'hosts'));
      expect(hostsFile.existsSync(), isTrue);
      expect(hostsFile.readAsStringSync(), contains('127.0.0.1 localhost'));

      // 验证 /workspace 挂载点目录被创建
      expect(Directory(p.join(targetDir.path, 'workspace')).existsSync(), isTrue);

      // 此时检测安装状态应为 true
      final isInstalled = await manager.isInstalled('alpine');
      expect(isInstalled, isTrue);
    });
  });

  group('ProotCommandBuilder 启动配置构建测试', () {
    test('构建 Host 本地启动配置', () async {
      final config = await manager.buildLaunchConfig(
        distroId: 'host',
        workspacePath: tempDir.path,
        customCommand: 'ls -la',
      );

      expect(config.executable, '/system/bin/sh');
      expect(config.arguments, ['-c', 'ls -la']);
      expect(config.workingDirectory, tempDir.path);
      expect(config.environment['TERM'], 'xterm-256color');
    });

    test('构建 Alpine PRoot 容器隔离启动配置与挂载参数', () async {
      final config = await manager.buildLaunchConfig(
        distroId: 'alpine',
        workspacePath: tempDir.path,
        prootPath: '/data/data/com.example/files/proot',
      );

      expect(config.executable, '/data/data/com.example/files/proot');
      expect(config.arguments, contains('-0'));
      expect(config.arguments, contains('-r'));
      expect(config.arguments, contains('-b'));
      expect(config.arguments, contains('/dev'));
      expect(config.arguments, contains('/proc'));
      expect(config.arguments, contains('/sys'));
      expect(config.arguments, contains('${tempDir.path}:/workspace'));
      expect(config.arguments, contains('-w'));
      expect(config.arguments, contains('/workspace'));
      expect(config.arguments, contains('/bin/sh'));
      expect(config.arguments, contains('-l'));

      expect(config.environment['HOME'], '/root');
      expect(config.environment['USER'], 'root');
      expect(config.environment['TERM'], 'xterm-256color');
      expect(config.environment['PATH'], isNotEmpty);

      final cmdLine = config.toCommandLine();
      expect(cmdLine, contains('/data/data/com.example/files/proot'));
      expect(cmdLine, contains('-0'));
    });
  });

  group('DistroProvider 状态测试', () {
    test('初始状态与切换默认发行版', () async {
      final provider = DistroProvider();
      expect(provider.defaultDistroId, 'alpine');

      provider.setDefaultDistro('host');
      expect(provider.defaultDistroId, 'host');

      await provider.checkAllStatuses();
      expect(provider.getStatus('host'), DistroStatus.installed);
    });
  });
}
