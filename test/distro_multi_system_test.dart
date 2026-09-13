import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/distro_installer.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/widgets/distro_selector_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late DistroManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('distro_multi_test_');
    manager = DistroManager();
    manager.customBaseDir = tempBaseDir;
  });

  tearDown(() {
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  Uint8List createMockRootfsTarGz() {
    final archive = Archive();
    archive.addFile(ArchiveFile('bin/sh', 11, 'echo "sh"'.codeUnits));
    archive.addFile(ArchiveFile('etc/os-release', 18, 'NAME="Alpine Linux"'.codeUnits));
    final tarData = TarEncoder().encode(archive);
    final gzData = GZipEncoder().encode(tarData);
    return Uint8List.fromList(gzData!);
  }

  group('DistroManager 多系统实例管理测试', () {
    test('初始状态系统列表为空', () async {
      final systems = await manager.listInstalledSystems();
      expect(systems, isEmpty);
      expect(await manager.hasAnySystem(), isFalse);
    });

    test('同一 Rootfs 包支持导入并创建多个独立系统实例', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'source_rootfs.tar.gz'));
      tempGzFile.writeAsBytesSync(gzBytes);

      // 导入系统 1: alpine
      await manager.importFromCustomTarGz(
        systemName: 'alpine',
        tarGzFile: tempGzFile,
      );

      // 导入系统 2: alpine_dev
      await manager.importFromCustomTarGz(
        systemName: 'alpine_dev',
        tarGzFile: tempGzFile,
      );

      final systems = await manager.listInstalledSystems();
      expect(systems.length, equals(2));
      expect(systems, containsAll(['alpine', 'alpine_dev']));

      // 验证各自根目录独立存在
      final alpineRootDir = await manager.getSystemRootDir('alpine');
      final devRootDir = await manager.getSystemRootDir('alpine_dev');
      expect(File(p.join(alpineRootDir.path, 'bin', 'sh')).existsSync(), isTrue);
      expect(File(p.join(devRootDir.path, 'bin', 'sh')).existsSync(), isTrue);
      expect(alpineRootDir.path != devRootDir.path, isTrue);

      // 验证网络配置 (resolv.conf / hosts) 与挂载点 (/workspace, /tmp)
      final resolvFile = File(p.join(alpineRootDir.path, 'etc', 'resolv.conf'));
      expect(resolvFile.existsSync(), isTrue);
      expect(resolvFile.readAsStringSync(), contains('1.1.1.1'));

      final hostsFile = File(p.join(alpineRootDir.path, 'etc', 'hosts'));
      expect(hostsFile.existsSync(), isTrue);
      expect(hostsFile.readAsStringSync(), contains('127.0.0.1 localhost'));

      expect(Directory(p.join(alpineRootDir.path, 'workspace')).existsSync(), isTrue);
      expect(Directory(p.join(alpineRootDir.path, 'tmp')).existsSync(), isTrue);

      // 验证已就绪状态检测
      expect(await manager.isSystemInstalled('alpine'), isTrue);
    });

    test('系统名称校验：非法字符与同名防重', () async {
      expect(
        () => manager.validateSystemName(''),
        throwsArgumentError,
      );

      expect(
        () => manager.validateSystemName('bad/name*here'),
        throwsArgumentError,
      );

      // 创建一个系统后，同名抛出异常
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'temp.tar.gz'))..writeAsBytesSync(gzBytes);
      await manager.importFromCustomTarGz(systemName: 'my_sys', tarGzFile: tempGzFile);

      expect(
        () => manager.validateSystemName('my_sys'),
        throwsArgumentError,
      );
    });

    test('解压取消时抛出异常并自动回滚清理残余目录', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'cancel_test.tar.gz'))..writeAsBytesSync(gzBytes);

      bool cancelTriggered = false;

      try {
        await manager.importFromCustomTarGz(
          systemName: 'cancelled_sys',
          tarGzFile: tempGzFile,
          onProgress: (prog, msg) {
            cancelTriggered = true;
          },
          isCancelled: () => cancelTriggered, // 模拟用户在解压循环中点击了取消
        );
        fail('应当抛出 DistroInstallCancelledException');
      } catch (e) {
        expect(e, isA<DistroInstallCancelledException>());
      }

      // 验证未导入成功的脏目录被清理
      final sysRootDir = await manager.getSystemRootDir('cancelled_sys');
      expect(sysRootDir.existsSync(), isFalse);
      expect((await manager.listInstalledSystems()).contains('cancelled_sys'), isFalse);
    });

    test('高危删除系统实例物理清除文件', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'del_test.tar.gz'))..writeAsBytesSync(gzBytes);

      await manager.importFromCustomTarGz(systemName: 'to_delete', tarGzFile: tempGzFile);
      expect((await manager.listInstalledSystems()).contains('to_delete'), isTrue);

      await manager.deleteSystem('to_delete');
      expect((await manager.listInstalledSystems()).contains('to_delete'), isFalse);

      final sysDir = Directory(p.join(tempBaseDir.path, 'to_delete'));
      expect(sysDir.existsSync(), isFalse);
    });

    test('buildLaunchConfig 准确指向对应系统根目录', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'cfg.tar.gz'))..writeAsBytesSync(gzBytes);

      await manager.importFromCustomTarGz(systemName: 'prod_env', tarGzFile: tempGzFile);

      final launchConfig = await manager.buildLaunchConfig(
        systemName: 'prod_env',
        workspacePath: tempBaseDir.path,
      );

      expect(launchConfig.arguments, contains('-r'));
      final rootDir = await manager.getSystemRootDir('prod_env');
      expect(launchConfig.arguments, contains(rootDir.path));
      expect(launchConfig.arguments, contains('-k'));
      expect(launchConfig.arguments, contains('5.4.0-proot'));
      expect(launchConfig.environment['PROOT_L2S_DIR'], isNotNull);
    });
  });

  group('DistroProvider 状态持久化与系统切换测试', () {
    test('默认系统自动选取与持久化切换', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'provider_test.tar.gz'))..writeAsBytesSync(gzBytes);

      final provider = DistroProvider();
      await provider.init();
      expect(provider.selectedSystem, isNull);

      // 导入首个系统，自动选为当前系统
      await provider.importFromCustomTarGz(systemName: 'sys_a', tarGzFile: tempGzFile);
      expect(provider.selectedSystem, equals('sys_a'));
      expect(provider.installedSystems, contains('sys_a'));

      // 导入第二个系统，自动切换到新系统
      await provider.importFromCustomTarGz(systemName: 'sys_b', tarGzFile: tempGzFile);
      expect(provider.selectedSystem, equals('sys_b'));

      // 手动切换回 sys_a 并持久化
      await provider.selectSystem('sys_a');
      expect(provider.selectedSystem, equals('sys_a'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('terminal_default_system'), equals('sys_a'));

      // 删除当前选中的系统，自动平滑退回到另一个系统
      await provider.deleteSystem('sys_a');
      expect(provider.installedSystems, equals(['sys_b']));
      expect(provider.selectedSystem, equals('sys_b'));

      // 删除仅剩的系统，回到 null
      await provider.deleteSystem('sys_b');
      expect(provider.installedSystems, isEmpty);
      expect(provider.selectedSystem, isNull);
    });

    test('删除系统实例时联动清理对应系统的全部终端会话', () async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'session_clean_test.tar.gz'))..writeAsBytesSync(gzBytes);

      final distroProvider = DistroProvider();
      await distroProvider.init();

      await distroProvider.importFromCustomTarGz(systemName: 'sys_1', tarGzFile: tempGzFile);
      await distroProvider.importFromCustomTarGz(systemName: 'sys_2', tarGzFile: tempGzFile);

      final terminalProvider = TerminalProvider();
      distroProvider.onSystemDeleted = (deleted) {
        terminalProvider.removeSessionsForDistro(deleted);
        if (!distroProvider.hasAnySystem) {
          terminalProvider.clearAllSessions();
        }
      };

      // 创建 sys_1 的两个会话，sys_2 的一个会话
      final s1 = terminalProvider.createSession(name: '会话1', distroId: 'sys_1');
      final s2 = terminalProvider.createSession(name: '会话2', distroId: 'sys_1');
      final s3 = terminalProvider.createSession(name: '会话3', distroId: 'sys_2');

      expect(terminalProvider.sessions.length, equals(3));

      // 删除 sys_1：应当仅删除 s1 与 s2，保留 s3
      await distroProvider.deleteSystem('sys_1');

      expect(terminalProvider.sessions.length, equals(1));
      expect(terminalProvider.sessions.first.id, equals(s3.id));
      expect(terminalProvider.sessions.first.distroId, equals('sys_2'));
      expect(terminalProvider.sessions.any((s) => s.id == s1.id), isFalse);
      expect(terminalProvider.sessions.any((s) => s.id == s2.id), isFalse);

      // 删除最后一个系统 sys_2：所有会话均被清理清空
      await distroProvider.deleteSystem('sys_2');
      expect(terminalProvider.sessions, isEmpty);
    });

    testWidgets('DistroSelectorDialog 列表项仅显示名称，无副标题与前置勾选图标', (tester) async {
      final gzBytes = createMockRootfsTarGz();
      final tempGzFile = File(p.join(tempBaseDir.path, 'dialog_ui_test.tar.gz'))..writeAsBytesSync(gzBytes);

      final distroProvider = DistroProvider();
      await tester.runAsync(() async {
        await distroProvider.init();
        await distroProvider.importFromCustomTarGz(systemName: 'my_alpine', tarGzFile: tempGzFile);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DistroProvider>.value(value: distroProvider),
            ChangeNotifierProvider<TerminalProvider>(create: (_) => TerminalProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: DistroSelectorDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证系统管理标题来自 l10n
      expect(find.text('系统管理'), findsOneWidget);

      // 验证系统名称正常显示
      expect(find.text('my_alpine'), findsOneWidget);

      // 验证无旧版副标题文字（如“当前默认系统”、“点击切换为默认”）
      expect(find.text('当前默认系统'), findsNothing);
      expect(find.text('点击切换为默认'), findsNothing);

      // 验证无前置勾选图标
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);

      // 验证存在高危删除按钮
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
