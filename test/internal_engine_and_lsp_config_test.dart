import 'dart:convert';
import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
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
    test('Initial load creates default presets and writes to disk', () async {
      final configs = await lspConfigService.loadConfigs(forceReload: true);
      expect(configs.isNotEmpty, isTrue);
      expect(configs.any((c) => c.id == 'c_cpp'), isTrue);
      expect(configs.any((c) => c.id == 'rust'), isTrue);

      final file = await lspConfigService.getConfigFile();
      expect(file.existsSync(), isTrue);

      final content = jsonDecode(file.readAsStringSync()) as List;
      expect(content.length, equals(configs.length));
    });

    test('Incremental merge appends missing default presets without overwriting user configs', () async {
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
          'apkPackage': 'py3-lsp-server',
          'enabled': true,
        }
      ];
      file.writeAsStringSync(jsonEncode(customConfig));

      final configs = await lspConfigService.loadConfigs(forceReload: true);
      // User's custom python must be preserved
      final pyConfig = configs.firstWhere((c) => c.id == 'python');
      expect(pyConfig.name, equals('My Custom Python'));
      expect(pyConfig.serverCommand, equals('my_pylsp'));

      // Missing presets like c_cpp, rust must be incrementally added
      expect(configs.any((c) => c.id == 'c_cpp'), isTrue);
      expect(configs.any((c) => c.id == 'rust'), isTrue);
      expect(configs.any((c) => c.id == 'go'), isTrue);
    });

    test('findByExtension resolves language config correctly', () async {
      await lspConfigService.loadConfigs(forceReload: true);

      final cConfig = lspConfigService.findByExtension('.c');
      expect(cConfig, isNotNull);
      expect(cConfig!.id, equals('c_cpp'));

      final cppConfig = lspConfigService.findByExtension('cpp');
      expect(cppConfig, isNotNull);
      expect(cppConfig!.id, equals('c_cpp'));

      final pyConfig = lspConfigService.findByExtension('.py');
      expect(pyConfig, isNotNull);
      expect(pyConfig!.id, equals('python'));

      final unknown = lspConfigService.findByExtension('.unknown');
      expect(unknown, isNull);
    });

    test('updateConfig, deleteConfig and resetToDefaults work and persist to disk', () async {
      await lspConfigService.loadConfigs(forceReload: true);

      // 1. Update config
      final originalC = lspConfigService.configs.firstWhere((c) => c.id == 'c_cpp');
      final modifiedC = originalC.copyWith(serverCommand: 'clangd-18');
      await lspConfigService.updateConfig(modifiedC);

      expect(lspConfigService.configs.firstWhere((c) => c.id == 'c_cpp').serverCommand, equals('clangd-18'));

      // 2. Delete config
      await lspConfigService.deleteConfig('shell');
      expect(lspConfigService.configs.any((c) => c.id == 'shell'), isFalse);

      // 3. Reset to defaults
      await lspConfigService.resetToDefaults();
      expect(lspConfigService.configs.any((c) => c.id == 'shell'), isTrue);
      expect(lspConfigService.configs.firstWhere((c) => c.id == 'c_cpp').serverCommand, equals('clangd'));
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
    testWidgets('Management view renders all language items and engine card in Chinese', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('代码补全管理'), findsOneWidget);
      expect(find.text('内部代码智能引擎 (Alpine)'), findsOneWidget);
      expect(find.text('C / C++'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Rust'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('Management view renders without hardcoded text in English', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Code Completion Management'), findsOneWidget);
      expect(find.text('Internal Code Intelligence Engine (Alpine)'), findsOneWidget);
      expect(find.byTooltip('Reset to Defaults'), findsOneWidget);
      expect(find.byTooltip('Add Language Configuration'), findsOneWidget);
    });

    testWidgets('Edit button pops LspLanguageEditDialog and saves modifications', (tester) async {
      await lspConfigService.loadConfigs(forceReload: true);

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      // Tap first edit icon
      final editButtons = find.byIcon(Icons.edit_outlined);
      expect(editButtons, findsWidgets);

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

      await tester.pumpWidget(buildTestWidget(
        child: const CodeCompletionManagementView(),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Python'), findsOneWidget);

      // Find delete button for Python (index 1)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('删除语言配置'), findsOneWidget);
      expect(find.text('确定要删除 Python 的代码补全配置吗？'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Python should now be gone
      expect(find.text('Python'), findsNothing);
      expect(lspConfigService.configs.any((c) => c.id == 'python'), isFalse);

      // Settle SnackBar timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
