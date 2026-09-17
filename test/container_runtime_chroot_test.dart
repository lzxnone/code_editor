import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/services/chroot_mount_manager.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/root_service.dart';
import 'package:code_editor/views/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RootService.instance.mockRootCapable = null;
    RootService.instance.mockRootGranted = null;
    ChrootMountManager.instance.mockPrepareSuccess = null;
  });

  tearDown(() {
    RootService.instance.mockRootCapable = null;
    RootService.instance.mockRootGranted = null;
    ChrootMountManager.instance.mockPrepareSuccess = null;
  });

  group('RootService Tests', () {
    test('isDeviceRootCapable defaults to false on non-rooted/desktop test environment', () {
      expect(RootService.instance.isDeviceRootCapable(), isFalse);
    });

    test('isDeviceRootCapable honors mockRootCapable', () {
      RootService.instance.mockRootCapable = true;
      expect(RootService.instance.isDeviceRootCapable(), isTrue);

      RootService.instance.mockRootCapable = false;
      expect(RootService.instance.isDeviceRootCapable(), isFalse);
    });

    test('requestRootPermissionOnce does not prompt if device is not root capable', () async {
      final settings = SettingsProvider();
      await settings.init();
      expect(settings.hasPromptedRootRequest, isFalse);

      RootService.instance.mockRootCapable = false;
      final result = await RootService.instance.requestRootPermissionOnce(settings);

      expect(result, isFalse);
      expect(settings.hasPromptedRootRequest, isTrue);
    });

    test('requestRootPermissionOnce prompts once on root capable device, never prompts again', () async {
      final settings = SettingsProvider();
      await settings.init();

      RootService.instance.mockRootCapable = true;
      RootService.instance.mockRootGranted = true;

      // First call prompts and grants
      final firstResult = await RootService.instance.requestRootPermissionOnce(settings);
      expect(firstResult, isTrue);
      expect(settings.hasPromptedRootRequest, isTrue);

      // Second call does nothing (never prompts again)
      RootService.instance.mockRootGranted = false;
      final secondResult = await RootService.instance.requestRootPermissionOnce(settings);
      expect(secondResult, isFalse);
    });
  });

  group('SettingsProvider ContainerRuntimeMode Tests', () {
    test('containerRuntimeMode defaults to auto and persists changes', () async {
      final settings = SettingsProvider();
      await settings.init();

      expect(settings.containerRuntimeMode, equals(ContainerRuntimeMode.auto));

      await settings.setContainerRuntimeMode(ContainerRuntimeMode.chroot);
      expect(settings.containerRuntimeMode, equals(ContainerRuntimeMode.chroot));

      await settings.setContainerRuntimeMode(ContainerRuntimeMode.proot);
      expect(settings.containerRuntimeMode, equals(ContainerRuntimeMode.proot));

      // Re-init from SharedPreferences
      final newSettings = SettingsProvider();
      await newSettings.init();
      expect(newSettings.containerRuntimeMode, equals(ContainerRuntimeMode.proot));
    });
  });

  group('ChrootMountManager Tests', () {
    test('resolveTargetShell resolves zsh > bash > sh', () {
      final tempDir = Directory.systemTemp.createTempSync('chroot_test_');
      try {
        final binDir = Directory('${tempDir.path}/bin')..createSync(recursive: true);

        // Neither exists -> /bin/sh
        expect(ChrootMountManager.instance.resolveTargetShell(tempDir), equals('/bin/sh'));

        // bash exists -> /bin/bash
        final bashFile = File('${binDir.path}/bash')..writeAsStringSync('');
        expect(ChrootMountManager.instance.resolveTargetShell(tempDir), equals('/bin/bash'));

        // zsh exists -> /bin/zsh (preferred over bash)
        final zshFile = File('${binDir.path}/zsh')..writeAsStringSync('');
        expect(ChrootMountManager.instance.resolveTargetShell(tempDir), equals('/bin/zsh'));

        zshFile.deleteSync();
        bashFile.deleteSync();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('DistroManager Double-Track Dispatch & Fallback Tests', () {
    late Directory mockRootDir;

    setUp(() {
      mockRootDir = Directory.systemTemp.createTempSync('distro_dispatch_test_');
      Directory('${mockRootDir.path}/etc').createSync(recursive: true);
      Directory('${mockRootDir.path}/bin').createSync(recursive: true);
    });

    tearDown(() {
      try {
        mockRootDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('buildLaunchConfig returns PRoot when mode is proot', () async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.proot);

      final config = await DistroManager().buildLaunchConfig(
        systemName: 'test_system',
        customRootDir: mockRootDir,
        settingsProvider: settings,
      );

      // PRoot configuration does not use su
      expect(config.executable, isNot(equals('su')));
      expect(config.arguments, contains('--kill-on-exit'));
    });

    test('buildLaunchConfig returns Chroot when mode is chroot and prepare succeeds', () async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.chroot);

      ChrootMountManager.instance.mockPrepareSuccess = true;

      final config = await DistroManager().buildLaunchConfig(
        systemName: 'test_system',
        customRootDir: mockRootDir,
        settingsProvider: settings,
        customCommand: 'echo hello',
      );

      // Chroot configuration uses su and passes chroot command
      expect(config.executable.endsWith('su'), isTrue);
      expect(config.arguments, contains('-c'));
      expect(config.arguments.last, contains('/system/bin/chroot'));
      expect(config.arguments.last, contains('echo hello'));
    });

    test('buildLaunchConfig smoothly falls back to PRoot when chroot prepare fails', () async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.chroot);

      // Chroot mount or check fails (e.g. root denied)
      ChrootMountManager.instance.mockPrepareSuccess = false;

      final config = await DistroManager().buildLaunchConfig(
        systemName: 'test_system',
        customRootDir: mockRootDir,
        settingsProvider: settings,
      );

      // Should automatically fall back to PRoot
      expect(config.arguments, contains('--kill-on-exit'));
    });

    test('buildLaunchConfig in auto mode uses Chroot when Root available, falls back to PRoot when not', () async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.auto);

      // 1. Root not available -> PRoot
      RootService.instance.mockRootGranted = false;
      final prootConfig = await DistroManager().buildLaunchConfig(
        systemName: 'test_system',
        customRootDir: mockRootDir,
        settingsProvider: settings,
      );
      expect(prootConfig.arguments, contains('--kill-on-exit'));

      // 2. Root available & Chroot prepare success -> Chroot
      RootService.instance.mockRootGranted = true;
      ChrootMountManager.instance.mockPrepareSuccess = true;
      final chrootConfig = await DistroManager().buildLaunchConfig(
        systemName: 'test_system',
        customRootDir: mockRootDir,
        settingsProvider: settings,
      );
      expect(chrootConfig.executable.endsWith('su'), isTrue);
      expect(chrootConfig.arguments.last, contains('/system/bin/chroot'));
    });

    testWidgets('detectAndApplyRuntime auto mode: falls back to proot and shows toast if root denied', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.auto);

      RootService.instance.mockRootCapable = true;
      RootService.instance.mockRootGranted = false;

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final result = await DistroManager().detectAndApplyRuntime(
        context: testContext,
        settings: settings,
        showToast: true,
      );

      expect(result, equals(ContainerRuntimeType.proot));
      await tester.pump();
      expect(find.text('当前容器运行环境：PRoot'), findsOneWidget);
    });

    testWidgets('detectAndApplyRuntime auto mode: selects chroot and shows toast if root granted and mount ok', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.auto);

      RootService.instance.mockRootCapable = true;
      RootService.instance.mockRootGranted = true;
      ChrootMountManager.instance.mockPrepareSuccess = true;

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final result = await DistroManager().detectAndApplyRuntime(
        context: testContext,
        settings: settings,
        showToast: true,
      );

      expect(result, equals(ContainerRuntimeType.chroot));
      await tester.pump();
      expect(find.text('当前容器运行环境：Chroot'), findsOneWidget);
    });

    testWidgets('detectAndApplyRuntime chroot mode: prompts explicit and falls back to proot if mount fails', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setContainerRuntimeMode(ContainerRuntimeMode.chroot);

      RootService.instance.mockRootCapable = true;
      RootService.instance.mockRootGranted = true;
      ChrootMountManager.instance.mockPrepareSuccess = false; // Mount fails

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final result = await DistroManager().detectAndApplyRuntime(
        context: testContext,
        settings: settings,
        showToast: true,
      );

      // Should smoothly fall back to proot
      expect(result, equals(ContainerRuntimeType.proot));
      await tester.pump();
      expect(find.text('当前容器运行环境：PRoot'), findsOneWidget);
    });
  });

  group('SettingsView Container Runtime UI Tests', () {
    testWidgets('SettingsView disables Chroot when root is not granted', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      RootService.instance.mockRootGranted = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SettingsView(),
            ),
          ),
        ),
      );

      final runtimeTileFinder = find.text('容器运行模式');
      await tester.scrollUntilVisible(runtimeTileFinder, 300.0);
      expect(runtimeTileFinder, findsOneWidget);
      expect(find.text('自动'), findsOneWidget);

      await tester.tap(runtimeTileFinder);
      await tester.pumpAndSettle();

      expect(find.text('选择容器运行模式'), findsOneWidget);
      expect(find.text('PRoot'), findsOneWidget);
      expect(find.text('Chroot'), findsOneWidget);

      // Chroot should be disabled (has lock outline icon)
      final chrootTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Chroot'), matching: find.byType(ListTile)),
      );
      expect(chrootTile.enabled, isFalse);

      // Tapping disabled Chroot does not change mode
      await tester.tap(find.text('Chroot'));
      await tester.pumpAndSettle();
      expect(settings.containerRuntimeMode, equals(ContainerRuntimeMode.auto));
    });

    testWidgets('SettingsView allows Chroot selection when root is granted and shows toast', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      RootService.instance.mockRootGranted = true;
      ChrootMountManager.instance.mockPrepareSuccess = true;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SettingsView(),
            ),
          ),
        ),
      );

      final runtimeTileFinder = find.text('容器运行模式');
      await tester.scrollUntilVisible(runtimeTileFinder, 300.0);
      await tester.tap(runtimeTileFinder);
      await tester.pumpAndSettle();

      final chrootTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Chroot'), matching: find.byType(ListTile)),
      );
      expect(chrootTile.enabled, isTrue);

      await tester.tap(find.text('Chroot'));
      await tester.pumpAndSettle();

      expect(settings.containerRuntimeMode, equals(ContainerRuntimeMode.chroot));
      expect(find.text('当前容器运行环境：Chroot'), findsOneWidget);
    });
  });
}
