import 'dart:convert';
import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/lsp_language_config.dart';
import 'package:code_editor/services/internal_engine_service.dart';
import 'package:code_editor/services/lsp_config_service.dart';
import 'package:code_editor/views/code_completion_management_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late LspConfigService lspConfigService;
  late InternalEngineService engineService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('lsp_engine_test_');

    lspConfigService = LspConfigService.instance;
    lspConfigService.customBaseDir = tempBaseDir;

    engineService = InternalEngineService.instance;
    engineService.customEngineDir = Directory(p.join(tempBaseDir.path, 'alpine'));
  });

  tearDown(() {
    lspConfigService.customBaseDir = null;
    engineService.customEngineDir = null;
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget({
    required Widget child,
    Locale locale = const Locale('zh'),
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      locale: locale,
      home: child,
    );
  }

  group('LspConfigService Tests', () {
    test('Initial load returns empty list and writes empty json to disk', () async {
      final configs = await lspConfigService.loadConfigs(forceReload: true);
      expect(configs.isEmpty, isTrue);

      final file = await lspConfigService.getConfigFile();
      expect(file.existsSync(), isTrue);

      final content = jsonDecode(file.readAsStringSync()) as List;
      expect(content.isEmpty, isTrue);
    });

    test('Loads pre-existing custom configs from disk without auto-injecting uninstalled presets', () async {
      final file = await lspConfigService.getConfigFile();
      // Write only custom Python config
      const customConfig = [
        {
          'id': 'python',
          'name': 'My Custom Python',
          'languageId': 'python',
          'fileExtensions': ['.py', '.pyw'],
          'serverCommand': 'my_pylsp',
          'serverArgs': ['--verbose'],
          'package': 'python3-pylsp',
          'enabled': true,
        }
      ];
      file.writeAsStringSync(jsonEncode(customConfig));

      final configs = await lspConfigService.loadConfigs(forceReload: true);
      expect(configs.length, equals(1));
      final pyConfig = configs.first;
      expect(pyConfig.id, equals('python'));
      expect(pyConfig.name, equals('My Custom Python'));
      expect(pyConfig.serverCommand, equals('my_pylsp'));

      // Missing presets like c_cpp, rust are NOT automatically added to installed list
      expect(configs.any((c) => c.id == 'c_cpp'), isFalse);
      expect(configs.any((c) => c.id == 'rust'), isFalse);
      expect(configs.any((c) => c.id == 'go'), isFalse);
    });

    test('LspLanguageConfig.findBuiltinByExtension resolves builtin templates correctly', () {
      final cPreset = LspLanguageConfig.findBuiltinByExtension('.c');
      expect(cPreset, isNotNull);
      expect(cPreset!.id, equals('c_cpp'));

      final cppPreset = LspLanguageConfig.findBuiltinByExtension('cpp');
      expect(cppPreset, isNotNull);
      expect(cppPreset!.id, equals('c_cpp'));

      final pyPreset = LspLanguageConfig.findBuiltinByExtension('.py');
      expect(pyPreset, isNotNull);
      expect(pyPreset!.id, equals('python'));

      final unknown = LspLanguageConfig.findBuiltinByExtension('.unknown');
      expect(unknown, isNull);
    });

    test('LspConfigService.findByExtension only returns installed and enabled configs', () async {
      await lspConfigService.loadConfigs(forceReload: true);

      // When no configs are installed, findByExtension must return null (not builtin preset)
      expect(lspConfigService.findByExtension('.cpp'), isNull);
      expect(lspConfigService.findByExtension('cpp'), isNull);
      expect(lspConfigService.findByExtension('.py'), isNull);

      // Install C/C++ config
      const sample = LspLanguageConfig(
        id: 'c_cpp',
        name: 'C / C++',
        languageId: 'cpp',
        fileExtensions: ['.c', '.cpp', '.h'],
        serverCommand: 'clangd',
        package: 'clangd',
      );
      await lspConfigService.updateConfig(sample);

      // Now it should resolve
      expect(lspConfigService.findByExtension('.cpp'), isNotNull);
      expect(lspConfigService.findByExtension('cpp')!.id, equals('c_cpp'));

      // If disabled, it should return null
      final disabledSample = sample.copyWith(enabled: false);
      await lspConfigService.updateConfig(disabledSample);
      expect(lspConfigService.findByExtension('.cpp'), isNull);
    });

    test('updateConfig, deleteConfig and resetToDefaults work and persist to disk', () async {
      await lspConfigService.loadConfigs(forceReload: true);

      // 1. Add / Update config
      const sample = LspLanguageConfig(
        id: 'c_cpp',
        name: 'C / C++',
        languageId: 'cpp',
        fileExtensions: ['.c', '.cpp', '.h'],
        serverCommand: 'clangd',
        package: 'clangd',
      );
      await lspConfigService.updateConfig(sample);
      expect(lspConfigService.configs.any((c) => c.id == 'c_cpp'), isTrue);

      final modifiedC = sample.copyWith(serverCommand: 'clangd-18');
      await lspConfigService.updateConfig(modifiedC);
      expect(lspConfigService.configs.firstWhere((c) => c.id == 'c_cpp').serverCommand, equals('clangd-18'));

      // 2. Delete config
      await lspConfigService.deleteConfig('c_cpp');
      expect(lspConfigService.configs.any((c) => c.id == 'c_cpp'), isFalse);

      // 3. Reset to defaults (clears configs)
      await lspConfigService.updateConfig(sample);
      expect(lspConfigService.configs.isNotEmpty, isTrue);
      await lspConfigService.resetToDefaults();
      expect(lspConfigService.configs.isEmpty, isTrue);
    });
  });

  group('InternalEngineService Tests', () {
    test('isEngineInstalled returns false when not installed', () async {
      final installed = await engineService.isEngineInstalled();
      expect(installed, isFalse);
    });

    test('isEngineInstalled returns true when .installed and rootfs exist', () async {
      final engineDir = await engineService.getEngineDir();
      final rootfs = await engineService.getRootfsDir();
      Directory(p.join(rootfs.path, 'bin')).createSync(recursive: true);
      Directory(p.join(rootfs.path, 'etc')).createSync(recursive: true);
      File(p.join(engineDir.path, '.installed')).writeAsStringSync('ready');

      final installed = await engineService.isEngineInstalled();
      expect(installed, isTrue);
    });
  });

  group('CodeCompletionManagementView & LspLanguageEditDialog Widget Tests', () {
    testWidgets('Management view renders empty placeholder when no language is installed', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('代码补全管理'), findsOneWidget);
      expect(find.text('引擎未启动'), findsOneWidget);
      expect(find.text('暂无已安装的代码智能组件'), findsOneWidget);
    });

    testWidgets('Management view renders installed language items in Chinese', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);
      await lspConfigService.updateConfig(const LspLanguageConfig(
        id: 'c_cpp',
        name: 'C / C++',
        languageId: 'cpp',
        fileExtensions: ['.c', '.cpp', '.h'],
        serverCommand: 'clangd',
        package: 'clangd',
      ));
      await lspConfigService.updateConfig(const LspLanguageConfig(
        id: 'python',
        name: 'Python',
        languageId: 'python',
        fileExtensions: ['.py'],
        serverCommand: 'pylsp',
        package: 'python3-pylsp',
      ));

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('代码补全管理'), findsOneWidget);
      expect(find.text('引擎未启动'), findsOneWidget);
      expect(find.text('C / C++'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('Management view renders without hardcoded text in English', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Code Completion Management'), findsOneWidget);
      expect(find.text('Engine Not Started'), findsOneWidget);
      expect(find.byTooltip('Add Language Configuration'), findsOneWidget);
      expect(find.text('No code intelligence components installed'), findsOneWidget);
    });

    testWidgets('Edit button pops LspLanguageEditDialog and saves modifications', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);
      await lspConfigService.updateConfig(const LspLanguageConfig(
        id: 'c_cpp',
        name: 'C / C++',
        languageId: 'cpp',
        fileExtensions: ['.c', '.cpp', '.h'],
        serverCommand: 'clangd',
        package: 'clangd',
      ));

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      // Click C / C++ card to expand it
      await tester.tap(find.text('C / C++'));
      await tester.pumpAndSettle();

      // Tap edit button in the expanded menu
      final editButtons = find.byIcon(Icons.edit_outlined);
      expect(editButtons, findsOneWidget);

      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.text('编辑语言配置'), findsOneWidget);
      expect(find.text('语言名称'), findsOneWidget);

      // Modify language name
      final nameField = find.widgetWithText(TextFormField, 'C / C++');
      await tester.enterText(nameField, 'C / C++ (Clang)');

      // Tap Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Updated name is shown in list
      expect(find.text('C / C++ (Clang)'), findsOneWidget);
      expect(lspConfigService.configs.any((c) => c.name == 'C / C++ (Clang)'), isTrue);

      // Settle SnackBar timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Delete button prompts confirmation and removes language', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);
      await lspConfigService.updateConfig(const LspLanguageConfig(
        id: 'python',
        name: 'Python',
        languageId: 'python',
        fileExtensions: ['.py'],
        serverCommand: 'pylsp',
        package: 'python3-pylsp',
      ));

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Python'), findsOneWidget);

      // Click Python card to expand it
      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();

      // Find delete button in the expanded Python card
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('删除语言配置'), findsOneWidget);
      expect(find.text('确定要删除 Python 的代码补全配置吗？'), findsOneWidget);

      // Confirm delete in dialog
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      // Python should now be gone
      expect(find.text('Python'), findsNothing);
      expect(lspConfigService.configs.any((c) => c.id == 'python'), isFalse);

      // Settle SnackBar timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('CodeCompletionManagementView renders without overflow on narrow device (320px width)', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Narrow layout in English should not have any RenderFlex overflow');
    });
  });
}
