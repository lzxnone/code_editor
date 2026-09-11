import 'package:re_editor/re_editor.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/file_directory_history.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/widgets/code_editor_tab_bar.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/main.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/services/file_watcher_service.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SyntaxHighlightHelper maps file extensions and names to correct language IDs', () {
    expect(SyntaxHighlightHelper.getLanguageId('main.dart'), 'dart');
    expect(SyntaxHighlightHelper.getLanguageId('app.json'), 'json');
    expect(SyntaxHighlightHelper.getLanguageId('intl_zh.arb'), 'json');
    expect(SyntaxHighlightHelper.getLanguageId('script.js'), 'javascript');
    expect(SyntaxHighlightHelper.getLanguageId('app.ts'), 'typescript');
    expect(SyntaxHighlightHelper.getLanguageId('index.html'), 'xml');
    expect(SyntaxHighlightHelper.getLanguageId('style.css'), 'css');
    expect(SyntaxHighlightHelper.getLanguageId('pubspec.yaml'), 'yaml');
    expect(SyntaxHighlightHelper.getLanguageId('README.md'), 'markdown');
    expect(SyntaxHighlightHelper.getLanguageId('main.py'), 'python');
    expect(SyntaxHighlightHelper.getLanguageId('Dockerfile'), 'dockerfile');
    expect(SyntaxHighlightHelper.getLanguageId('Makefile'), 'makefile');
    expect(SyntaxHighlightHelper.getLanguageId('code_editor.iml'), 'xml');
    expect(SyntaxHighlightHelper.getLanguageId('unknown.xyz'), isNull);
    expect(SyntaxHighlightHelper.getLanguageId(null), isNull);

    // Verify all resolved languages exist in builtinAllLanguages
    final dartLanguages = SyntaxHighlightHelper.getLanguagesForFile('main.dart');
    expect(dartLanguages.keys, ['dart']);
    expect(dartLanguages['dart'], isNotNull);

    final imlLanguages = SyntaxHighlightHelper.getLanguagesForFile('code_editor.iml');
    expect(imlLanguages.keys, ['xml']);
    expect(imlLanguages['xml'], isNotNull);

    // Cache verification
    final dartLanguages2 = SyntaxHighlightHelper.getLanguagesForFile('test.dart');
    expect(identical(dartLanguages['dart'], dartLanguages2['dart']), isTrue);

    // Plain text returns empty map without loading 194 languages
    expect(SyntaxHighlightHelper.getLanguagesForFile('notes.txt'), isEmpty);
  });


  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('CodeEditorWidget shows empty directory message when rootPath is null or empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CodeEditorWidget(rootPath: null, filePath: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("当前未打开文件目录"), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CodeEditorWidget(rootPath: '', filePath: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("当前未打开文件目录"), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CodeEditorWidget(rootPath: '/workspace', filePath: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("当前未打开文件"), findsOneWidget);
  });

  testWidgets('FileItemWidget renders specific icons and untinted folder icon', (WidgetTester tester) async {
    final dartItem = FileItem(name: 'main.dart', path: '/test/main.dart', isDirectory: false);
    final jsonItem = FileItem(name: 'config.json', path: '/test/config.json', isDirectory: false);
    final txtItem = FileItem(name: 'notes.unknown', path: '/test/notes.unknown', isDirectory: false);
    final dirItem = FileItem(name: 'src', path: '/test/src', isDirectory: true);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EditorProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FileItemWidget(fileItem: dartItem),
                FileItemWidget(fileItem: jsonItem),
                FileItemWidget(fileItem: txtItem),
                FileItemWidget(fileItem: dirItem),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
    expect(find.byIcon(Icons.data_object), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });

  testWidgets('FileItemWidget enables paste when copiedItem is present', (WidgetTester tester) async {
    final dirItem = FileItem(name: 'src', path: '/test/src', isDirectory: true);
    final copiedFile = FileItem(name: 'main.dart', path: '/test/main.dart', isDirectory: false);
    final provider = EditorProvider();
    provider.copy(copiedFile);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: FileItemWidget(
              fileItem: dirItem,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Long press to open context menu
    await tester.longPress(find.text('src'));
    await tester.pumpAndSettle();

    // '粘贴' should be visible and enabled
    expect(find.text('粘贴'), findsOneWidget);
    final popupItem = tester.widget<PopupMenuItem<String>>(find.byWidgetPredicate(
      (w) => w is PopupMenuItem<String> && w.value == 'paste',
    ));
    expect(popupItem.enabled, isTrue);
  });

  test('EditorProvider manages cut, copy, and paste states correctly', () {
    final provider = EditorProvider();
    final file1 = FileItem(name: 'a.dart', path: '/test/a.dart', isDirectory: false);
    final file2 = FileItem(name: 'b.dart', path: '/test/b.dart', isDirectory: false);

    expect(provider.canPaste, isFalse);

    provider.cut(file1);
    expect(provider.cutItem, equals(file1));
    expect(provider.copiedItem, isNull);
    expect(provider.canPaste, isTrue);
    expect(provider.isItemCut(file1.path), isTrue);
    expect(provider.isItemCut(file2.path), isFalse);

    provider.copy(file2);
    expect(provider.copiedItem, equals(file2));
    expect(provider.cutItem, isNull);
    expect(provider.canPaste, isTrue);
    expect(provider.isItemCut(file1.path), isFalse);
  });

  test('FileItem provides name, extension, relativePath, and fullPath', () {
    final expectedRel = p.join('lib', 'main.dart');
    final wsPath = p.join('workspace', 'lib', 'main.dart');
    final item = FileItem(
      path: wsPath,
      relativePath: expectedRel,
      isDirectory: false,
    );

    expect(item.name, equals('main.dart'));
    expect(item.extension, equals('.dart'));
    expect(item.nameWithoutExtension, equals('main'));
    expect(item.relativePath, equals(expectedRel));
    expect(item.displayPath, equals(expectedRel));
    expect(item.getRelativePath('workspace'), equals(expectedRel));

    final dirItem = FileItem(
      path: p.join('workspace', 'lib'),
      isDirectory: true,
    );
    expect(dirItem.name, equals('lib'));
    expect(dirItem.extension, equals(''));
    expect(dirItem.nameWithoutExtension, equals('lib'));
  });

  testWidgets('CodeEditorAppBar uses onSurface foregroundColor and position under', (WidgetTester tester) async {
    bool settingsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          appBar: CodeEditorAppBar(
            filePath: '/workspace/main.dart',
            onSettings: () => settingsOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);
    final appBar = tester.widget<AppBar>(appBarFinder);
    expect(appBar.foregroundColor, isNotNull);

    // Verify PopupMenuButton has position under
    final popupBtnFinder = find.byType(PopupMenuButton<String>);
    expect(popupBtnFinder, findsOneWidget);
    final popupBtn = tester.widget<PopupMenuButton<String>>(popupBtnFinder);
    expect(popupBtn.position, equals(PopupMenuPosition.under));

    // Tap menu button
    await tester.tap(popupBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(settingsOpened, isTrue);
  });

  testWidgets('SettingsView renders word wrap switch and language options', (WidgetTester tester) async {
    final provider = EditorProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SettingsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify word wrap switch tile exists
    expect(find.text('自动换行'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(provider.wordWrap, isTrue);

    // Toggle word wrap
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(provider.wordWrap, isFalse);

    // Verify language section
    expect(find.text('应用语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets);

    // Tap language tile to open modal
    await tester.tap(find.text('应用语言'));
    await tester.pumpAndSettle();

    expect(find.text('选择应用语言'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Select English
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(provider.locale, equals(const Locale('en')));
  });

  testWidgets('EditorProvider wordWrap and locale can be updated', (WidgetTester tester) async {
    final provider = EditorProvider();

    expect(provider.wordWrap, isTrue);
    await provider.setWordWrap(false);
    expect(provider.wordWrap, isFalse);

    expect(provider.locale, isNull);
    await provider.setLocale(const Locale('en'));
    expect(provider.locale, equals(const Locale('en')));
    await provider.setLocale(null);
    expect(provider.locale, isNull);
  });

  testWidgets('SettingsView font size dialog allows maximum 30 without assertion error', (WidgetTester tester) async {
    final provider = EditorProvider();
    await provider.setFontSize(30.0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SettingsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap font size tile to open dialog with initial value 30.0
    expect(find.text('30'), findsWidgets);
    await tester.tap(find.text('代码字号缩放'));
    await tester.pumpAndSettle();

    // Dialog should be open without throwing Slider assertion error
    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, equals(30.0));
    expect(slider.value, equals(30.0));

    // Tap done button
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  });

  testWidgets('CodeEditorAppBar displays asterisk when isModified is true', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(
          appBar: CodeEditorAppBar(
            filePath: '/workspace/main.dart',
            isModified: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('* main.dart'), findsNothing);

    // Rebuild with isModified = true
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(
          appBar: CodeEditorAppBar(
            filePath: '/workspace/main.dart',
            isModified: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('* main.dart'), findsOneWidget);
  });

  testWidgets('EditorProvider checkUnsavedChanges saves or discards correctly', (WidgetTester tester) async {
    final provider = EditorProvider();
    provider.setHistoryForTesting(const FileDirectoryHistory(rootPath: '/test', lastOpenedFilePath: '/test/demo.txt'));
    provider.setModified(true);
    expect(provider.isModified, isTrue);

    bool saveCalled = false;
    provider.registerSaveHandler(() async {
      saveCalled = true;
      return true;
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final proceed = await provider.checkUnsavedChanges(context);
                expect(proceed, isTrue);
              },
              child: const Text('Check'),
            );
          },
        ),
      ),
    );

    // Tap button to trigger checkUnsavedChanges
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // Dialog should be displayed for saving all files in project
    expect(find.text('保存所有更改？'), findsOneWidget);
    expect(find.text('当前项目中有未保存的修改，是否保存所有文件？'), findsOneWidget);

    // Tap Save All
    await tester.tap(find.text('保存所有'));
    await tester.pumpAndSettle();

    expect(saveCalled, isTrue);

    // Advance timer to let toast disappear
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('FileItemWidget does not display asterisk even when isModified is true', (WidgetTester tester) async {
    final fileItem = FileItem(name: 'main.dart', path: '/test/main.dart', isDirectory: false);
    final provider = EditorProvider();
    provider.setHistoryForTesting(const FileDirectoryHistory(rootPath: '/test', lastOpenedFilePath: '/test/main.dart'));
    provider.setModified(true);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: FileItemWidget(fileItem: fileItem),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('* main.dart'), findsNothing);
  });

  test('EditorTabItem disambiguates duplicate file names with relative path', () {
    final tab1 = EditorTabItem(path: p.normalize('/workspace/lib/widgets/app_bar.dart'));
    final tab2 = EditorTabItem(path: p.normalize('/workspace/lib/views/app_bar.dart'));
    final tab3 = EditorTabItem(path: p.normalize('/workspace/lib/main.dart'));
    final tabs = [tab1, tab2, tab3];

    final root = p.normalize('/workspace');

    // Duplicate names display relative path
    expect(tab1.getDisplayName(tabs, root), equals(p.normalize('lib/widgets/app_bar.dart')));
    expect(tab2.getDisplayName(tabs, root), equals(p.normalize('lib/views/app_bar.dart')));

    // Unique name displays plain filename
    expect(tab3.getDisplayName(tabs, root), equals('main.dart'));

    // Formatted title with dirty marker
    tab3.isModified = true;
    expect(tab3.getFormattedTitle(tabs, root), equals('* main.dart'));
  });

  testWidgets('CodeEditorAppBar displays primary title, subtitle, and save all action', (WidgetTester tester) async {
    bool saveAllTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          appBar: CodeEditorAppBar(
            filePath: p.normalize('/workspace/main.dart'),
            rootPath: p.normalize('/workspace'),
            isModified: false,
            onSaveAll: () => saveAllTriggered = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Primary title: main.dart, Subtitle: /
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);

    // Rebuild with subfolder file
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          appBar: CodeEditorAppBar(
            filePath: p.normalize('/workspace/lib/views/home.dart'),
            rootPath: p.normalize('/workspace'),
            isModified: true,
            onSaveAll: () => saveAllTriggered = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('* home.dart'), findsOneWidget);
    expect(find.text('/lib/views'), findsOneWidget);

    // Open popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('保存所有'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // Tap 保存所有
    await tester.tap(find.text('保存所有'));
    await tester.pumpAndSettle();

    expect(saveAllTriggered, isTrue);
  });

  testWidgets('CodeEditorTabBar renders tabs and handles dirty close dialog', (WidgetTester tester) async {
    final provider = EditorProvider();
    final tab1 = EditorTabItem(path: '/test/file1.dart', isModified: false);
    final tab2 = EditorTabItem(path: '/test/file2.dart', isModified: true);
    provider.setOpenTabsForTesting([tab1, tab2], activePath: '/test/file1.dart');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: Column(
              children: [
                CodeEditorTabBar(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tabs rendered
    expect(find.text('file1.dart'), findsOneWidget);
    expect(find.text('file2.dart'), findsOneWidget);
    // Tab2 is dirty, so asterisk * is displayed
    expect(find.text('*'), findsOneWidget);

    // Click close on tab2 (dirty)
    final closeIcons = find.byIcon(Icons.close);
    expect(closeIcons, findsNWidgets(2));
    await tester.tap(closeIcons.at(1));
    await tester.pumpAndSettle();

    // Save prompt dialog should appear
    expect(find.text('保存更改'), findsOneWidget);
    expect(find.text('文件 "file2.dart" 已被修改，是否保存更改？'), findsOneWidget);

    // Tap Discard (不保存)
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    // Now tab2 should be closed, only tab1 left
    expect(provider.openTabs.length, equals(1));
    expect(provider.openTabs.first.path, equals('/test/file1.dart'));
  });

  test('SettingsProvider manages settings correctly', () async {
    final settings = SettingsProvider();
    expect(settings.fontSize, equals(14.0));
    expect(settings.wordWrap, isTrue);
    expect(settings.appThemeMode, equals(ThemeMode.system));

    await settings.setFontSize(18.0);
    expect(settings.fontSize, equals(18.0));

    await settings.setWordWrap(false);
    expect(settings.wordWrap, isFalse);

    await settings.setAppThemeMode(ThemeMode.dark);
    expect(settings.appThemeMode, equals(ThemeMode.dark));

    await settings.setLocale(const Locale('en'));
    expect(settings.locale, equals(const Locale('en')));
  });

  test('ProjectProvider manages cut/copy/paste and tree state', () {
    final project = ProjectProvider();
    final itemA = FileItem(name: 'a.dart', path: '/test/a.dart', isDirectory: false);
    final itemB = FileItem(name: 'b.dart', path: '/test/b.dart', isDirectory: false);

    expect(project.canPaste, isFalse);
    project.cut(itemA);
    expect(project.canPaste, isTrue);
    expect(project.isItemCut(itemA.path), isTrue);
    expect(project.isItemCut(itemB.path), isFalse);

    project.copy(itemB);
    expect(project.canPaste, isTrue);
    expect(project.isItemCut(itemA.path), isFalse);
    expect(project.copiedItem, equals(itemB));
  });

  test('TabProvider manages openTabs, activeTab, and dirty state', () {
    final tabProvider = TabProvider();
    final tab1 = EditorTabItem(path: '/ws/main.dart', content: 'void main() {}');
    tabProvider.setOpenTabsForTesting([tab1]);

    expect(tabProvider.openTabs.length, equals(1));
    expect(tabProvider.activeTab?.path, equals('/ws/main.dart'));
    expect(tabProvider.isModified, isFalse);

    tabProvider.updateActiveTabContent('void main() { print(1); }', isModified: true);
    expect(tabProvider.isModified, isTrue);
    expect(tabProvider.activeTab?.content, equals('void main() { print(1); }'));

    tabProvider.setModified(false);
    expect(tabProvider.isModified, isFalse);
  });

  test('EditorTabItem tracks isLoaded state and scroll offsets for in-memory caching', () {
    final tab = EditorTabItem(
      path: '/ws/test.dart',
      content: 'hello',
      isLoaded: true,
      verticalScrollOffset: 120.0,
      horizontalScrollOffset: 45.0,
    );
    expect(tab.isLoaded, isTrue);
    expect(tab.content, 'hello');
    expect(tab.verticalScrollOffset, 120.0);
    expect(tab.horizontalScrollOffset, 45.0);

    final tabUnloaded = EditorTabItem(path: '/ws/cold.dart');
    expect(tabUnloaded.isLoaded, isFalse);
    expect(tabUnloaded.verticalScrollOffset, 0.0);
    expect(tabUnloaded.horizontalScrollOffset, 0.0);
  });

  testWidgets('CodeEditorWidget tab switching does not falsely mark tabs as dirty', (WidgetTester tester) async {
    final tabProvider = TabProvider();
    final tabA = EditorTabItem(
      path: '/test/a.dart',
      content: 'void main() {\r\n  print("a");\r\n}',
      originalContent: 'void main() {\r\n  print("a");\r\n}',
      isLoaded: true,
      isModified: false,
    );
    final tabB = EditorTabItem(
      path: '/test/b.dart',
      content: 'void main() {\r\n  print("b");\r\n}',
      originalContent: 'void main() {\r\n  print("b");\r\n}',
      isLoaded: true,
      isModified: false,
    );
    tabProvider.setOpenTabsForTesting([tabA, tabB], activePath: tabA.path);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: '/test', filePath: '/test/a.dart'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tab A should not be dirty
    expect(tabA.isModified, isFalse);
    expect(tabProvider.isModified, isFalse);

    // Switch to Tab B
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: '/test', filePath: '/test/b.dart'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Neither Tab A nor Tab B should be dirty!
    expect(tabA.isModified, isFalse);
    expect(tabB.isModified, isFalse);
    expect(tabProvider.isModified, isFalse);
  });

  test('CodeLineEditingController text exact match with disk strings', () {
    final samples = [
      'void main() {\n  print("hello");\n}\n',
      'void main() {\r\n  print("hello");\r\n}\r\n',
      'class A {\n  int x = 1;\n}',
      'class A {\r\n  int x = 1;\r\n}',
      '',
      'single line',
      'single line\n',
      'single line\r\n',
      '   \n\t\t\n   \n',
      '<?xml version="1.0" encoding="UTF-8"?>\r\n<project version="4">\r\n  <component name="ProjectModuleManager">\r\n    <modules>\r\n      <module filepath="\$PROJECT_DIR\$/code_editor.iml" />\r\n    </modules>\r\n  </component>\r\n</project>\r\n',
    ];

    for (final raw in samples) {
      final normalized = raw.replaceAll('\r\n', '\n');
      final controller = CodeLineEditingController.fromText(normalized);
      final text = controller.text;
      final current = text.replaceAll('\r\n', '\n');
      final normalizedOriginal = normalized.replaceAll('\r\n', '\n');
      expect(current == normalizedOriginal, isTrue, reason: 'Failed on raw: $raw, current: $current, orig: $normalizedOriginal');
    }
  });

  testWidgets('CodeEditorTabBar tab width does not stretch across entire row for single tab', (WidgetTester tester) async {
    final tabProvider = TabProvider();
    final tab = EditorTabItem(path: '/test/main.dart', isModified: false);
    tabProvider.setOpenTabsForTesting([tab]);

    await tester.pumpWidget(
      ChangeNotifierProvider<TabProvider>.value(
        value: tabProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500.0,
              child: CodeEditorTabBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the Container corresponding to the tab
    final tabFinder = find.byKey(ValueKey(tab.path));
    expect(tabFinder, findsOneWidget);

    final RenderBox renderBox = tester.renderObject(tabFinder);
    // On a 500px width container, a single tab with name 'main.dart'
    // should NOT stretch to 500px, but be around ~80-140px.
    expect(renderBox.size.width, lessThan(200.0));
    expect(renderBox.size.width, greaterThan(36.0));
  });

  test('FileWatcherService filters ignored directories and handles self-save tracking', () {
    expect(FileWatcherService.shouldIgnore('/ws/.git/config'), isTrue);
    expect(FileWatcherService.shouldIgnore('/ws/.dart_tool/package_config.json'), isTrue);
    expect(FileWatcherService.shouldIgnore('/ws/build/app.apk'), isTrue);
    expect(FileWatcherService.shouldIgnore('/ws/lib/main.dart'), isFalse);

    final watcher = FileWatcherService.instance;
    watcher.clearRecentlySavedForTesting();

    expect(watcher.isRecentlySaved('/ws/lib/main.dart'), isFalse);
    watcher.markRecentlySaved('/ws/lib/main.dart');
    expect(watcher.isRecentlySaved('/ws/lib/main.dart'), isTrue);
  });

  test('TabProvider handles external file modified: clean tab reloads silently, dirty tab triggers conflict', () async {
    final tabProvider = TabProvider();
    final cleanTab = EditorTabItem(
      path: '/ws/clean.dart',
      content: 'old clean content',
      originalContent: 'old clean content',
      isModified: false,
    );
    final dirtyTab = EditorTabItem(
      path: '/ws/dirty.dart',
      content: 'user edited content',
      originalContent: 'baseline content',
      isModified: true,
    );
    tabProvider.setOpenTabsForTesting([cleanTab, dirtyTab]);

    // External file delete handling
    tabProvider.handleExternalFileDeleted('/ws/clean.dart');
    expect(tabProvider.openTabs.any((t) => t.path == '/ws/clean.dart'), isFalse);
    // Dirty tab should NOT be deleted automatically to protect code
    tabProvider.handleExternalFileDeleted('/ws/dirty.dart');
    expect(tabProvider.openTabs.any((t) => t.path == '/ws/dirty.dart'), isTrue);
    expect(dirtyTab.isDeletedOnDisk, isTrue);

    // Conflict resolution
    dirtyTab.hasExternalConflict = true;
    tabProvider.resolveConflict(dirtyTab, reloadFromDisk: false);
    expect(dirtyTab.hasExternalConflict, isFalse);
    expect(dirtyTab.content, equals('user edited content'));
  });

  testWidgets('Switching between .iml and .dart tabs preserves syntax highlight mapping and maintains clean dirty state', (WidgetTester tester) async {
    final tabProvider = TabProvider();
    final tabIml = EditorTabItem(
      path: p.normalize('/ws/code_editor.iml'),
      content: '<module type="JAVA_MODULE" version="4">\r\n</module>\r\n',
      originalContent: '<module type="JAVA_MODULE" version="4">\r\n</module>\r\n',
      isLoaded: true,
      isModified: false,
    );
    final tabDart1 = EditorTabItem(
      path: p.normalize('/ws/lib/main.dart'),
      content: 'void main() {\r\n  print("main");\r\n}\r\n',
      originalContent: 'void main() {\r\n  print("main");\r\n}\r\n',
      isLoaded: true,
      isModified: false,
    );
    final tabDart2 = EditorTabItem(
      path: p.normalize('/ws/lib/test.dart'),
      content: 'void testFunc() {\r\n  print("test");\r\n}\r\n',
      originalContent: 'void testFunc() {\r\n  print("test");\r\n}\r\n',
      isLoaded: true,
      isModified: false,
    );
    tabProvider.setOpenTabsForTesting([tabIml, tabDart1, tabDart2], activePath: tabIml.path);

    // 1. Initial build with .iml
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: p.normalize('/ws'), filePath: tabIml.path),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // .iml must have XML syntax mode
    final imlModes = SyntaxHighlightHelper.getLanguagesForFile(tabIml.path);
    expect(imlModes.keys, ['xml']);
    expect(tabIml.isModified, isFalse);
    expect(tabDart1.isModified, isFalse);
    expect(tabDart2.isModified, isFalse);

    // 2. Switch to main.dart
    await tabProvider.openFile(tabDart1.path);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: p.normalize('/ws'), filePath: tabDart1.path),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // main.dart must have Dart syntax mode
    final dart1Modes = SyntaxHighlightHelper.getLanguagesForFile(tabDart1.path);
    expect(dart1Modes.keys, ['dart']);
    expect(tabIml.isModified, isFalse, reason: 'Switching from .iml to .dart must not mark .iml dirty!');
    expect(tabDart1.isModified, isFalse, reason: 'Opening .dart tab must not mark it dirty!');

    // 3. Switch to test.dart
    await tabProvider.openFile(tabDart2.path);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: p.normalize('/ws'), filePath: tabDart2.path),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tabIml.isModified, isFalse);
    expect(tabDart1.isModified, isFalse);
    expect(tabDart2.isModified, isFalse);

    // 4. Switch back to main.dart
    await tabProvider.openFile(tabDart1.path);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CodeEditorWidget(rootPath: p.normalize('/ws'), filePath: tabDart1.path),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tabIml.isModified, isFalse);
    expect(tabDart1.isModified, isFalse);
    expect(tabDart2.isModified, isFalse);

    // 5. Simulate editing: update content to modified -> dirty
    tabProvider.updateActiveTabContent('void main() {\r\n  print("modified");\r\n}\r\n');
    expect(tabDart1.isModified, isTrue);
    expect(tabProvider.isModified, isTrue);

    // 6. Undo back to original content -> automatically clean!
    tabProvider.updateActiveTabContent(tabDart1.originalContent);
    expect(tabDart1.isModified, isFalse);
    expect(tabProvider.isModified, isFalse);
  });

  testWidgets('Opening another file from file list when active file is modified does not prompt save dialog', (WidgetTester tester) async {
    final tabProvider = TabProvider();
    final projectProvider = ProjectProvider();
    final settingsProvider = SettingsProvider();

    final file1 = FileItem(path: p.normalize('/ws/file1.dart'), name: 'file1.dart', isDirectory: false);
    final file2 = FileItem(path: p.normalize('/ws/file2.dart'), name: 'file2.dart', isDirectory: false);

    // Initial state: open file1 and modify it
    await tabProvider.openFile(file1.path, content: 'int a = 1;');
    tabProvider.updateActiveTabContent('int a = 2;', isModified: true);
    expect(tabProvider.isModified, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const MainView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify main view is rendered with modified file1
    expect(find.text('file1.dart'), findsWidgets);
    expect(tabProvider.isModified, isTrue);

    // Open file2 via selectFile (simulating user clicking file2 in file tree/drawer)
    await tabProvider.selectFile(file2);
    await tester.pumpAndSettle();

    // NO save prompt dialog should appear
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('保存所有更改？'), findsNothing);

    // Now file2 is active, file1 is still open and preserved in memory
    expect(tabProvider.activeTab?.path, equals(p.normalize('/ws/file2.dart')));
    expect(tabProvider.openTabs.length, equals(2));
    expect(tabProvider.openTabs[0].isModified, isTrue);
    expect(tabProvider.openTabs[0].content, equals('int a = 2;'));

    // Switch back to file1 via openFile (simulating clicking tab1)
    await tabProvider.openFile(file1.path);
    await tester.pumpAndSettle();

    // NO save prompt dialog should appear on tab switch either
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('保存所有更改？'), findsNothing);
    expect(tabProvider.activeTab?.path, equals(p.normalize('/ws/file1.dart')));
    expect(tabProvider.activeTab?.isModified, isTrue);
  });
}





