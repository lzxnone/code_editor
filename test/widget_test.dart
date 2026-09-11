import 'package:re_editor/re_editor.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/services/project_history_service.dart';
import 'package:code_editor/widgets/project_history_widget.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/widgets/virtual_keyboard_widget.dart';
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
import 'package:code_editor/widgets/code_editor_drawer.dart';
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

    expect(find.text("当前未打开项目"), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CodeEditorWidget(rootPath: '', filePath: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("当前未打开项目"), findsOneWidget);

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
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
          ChangeNotifierProvider(create: (_) => TabProvider()),
        ],
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
    final projectProvider = ProjectProvider();
    final tabProvider = TabProvider();
    projectProvider.copy(copiedFile);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
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

  test('ProjectProvider manages cut, copy, and paste states correctly', () {
    final provider = ProjectProvider();
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
    final provider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
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
    final wordWrapTile = find.ancestor(
      of: find.text('自动换行'),
      matching: find.byType(SwitchListTile),
    );
    expect(wordWrapTile, findsOneWidget);
    final switchFinder = find.descendant(
      of: wordWrapTile,
      matching: find.byType(Switch),
    );
    expect(switchFinder, findsOneWidget);
    expect(provider.wordWrap, isTrue);

    // Toggle word wrap
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(provider.wordWrap, isFalse);

    // Verify language section
    final langTile = find.text('应用语言');
    await tester.scrollUntilVisible(langTile, 300);
    // Drag slightly up to ensure it is nicely inside viewport
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(langTile, findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets);

    // Tap language tile to open modal
    await tester.tap(langTile);
    await tester.pumpAndSettle();

    expect(find.text('选择应用语言'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Select English
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(provider.locale, equals(const Locale('en')));
  });

  testWidgets('SettingsProvider wordWrap and locale can be updated', (WidgetTester tester) async {
    final provider = SettingsProvider();

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
    final provider = SettingsProvider();
    await provider.setFontSize(30.0);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
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

  testWidgets('TabProvider checkUnsavedChanges saves or discards correctly', (WidgetTester tester) async {
    final provider = TabProvider();
    provider.setModifiedForTesting(true);
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
    final projectProvider = ProjectProvider();
    final tabProvider = TabProvider();
    tabProvider.setModifiedForTesting(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
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
    expect(find.text('关闭所有标签'), findsOneWidget);
    expect(find.text('关闭当前项目'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // Tap 保存所有
    await tester.tap(find.text('保存所有'));
    await tester.pumpAndSettle();

    expect(saveAllTriggered, isTrue);
  });

  testWidgets('CodeEditorTabBar renders tabs and handles dirty close dialog', (WidgetTester tester) async {
    final provider = TabProvider();
    final tab1 = EditorTabItem(path: '/test/file1.dart', isModified: false);
    final tab2 = EditorTabItem(path: '/test/file2.dart', isModified: true);
    provider.setOpenTabsForTesting([tab1, tab2], activePath: '/test/file1.dart');

    await tester.pumpWidget(
      ChangeNotifierProvider<TabProvider>.value(
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

  testWidgets('Close all tabs from PopupMenu prompts for dirty tabs and closes tabs', (WidgetTester tester) async {
    final tabProvider = TabProvider();
    final projectProvider = ProjectProvider();
    final settingsProvider = SettingsProvider();

    await tabProvider.openFile(p.normalize('/ws/file1.dart'), content: 'code');
    tabProvider.updateActiveTabContent('modified code', isModified: true);

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

    expect(tabProvider.openTabs.length, equals(1));

    // Tap more menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap '关闭所有标签'
    await tester.tap(find.text('关闭所有标签'));
    await tester.pumpAndSettle();

    // Dirty prompt dialog should appear
    expect(find.text('保存所有更改？'), findsOneWidget);

    // Choose discard (不保存)
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    // All tabs should be closed
    expect(tabProvider.openTabs, isEmpty);
    expect(tabProvider.activeTab, isNull);
  });

  testWidgets('Deleting current project in ProjectHistoryWidget closes project first before confirming delete', (WidgetTester tester) async {
    final projectPath = p.normalize('/ws/current_proj');
    final otherPath = p.normalize('/ws/other_proj');

    final tabProvider = TabProvider();
    final projectProvider = ProjectProvider();
    final settingsProvider = SettingsProvider();

    // Set current project in ProjectProvider
    projectProvider.setHistoryForTesting(ProjectHistory(
      rootPath: projectPath,
      lastOpenedFilePath: p.normalize('$projectPath/main.dart'),
    ));

    await tabProvider.openFile(p.normalize('$projectPath/main.dart'), content: 'initial');
    tabProvider.updateActiveTabContent('dirty content', isModified: true);
    expect(tabProvider.isModified, isTrue);

    // Save history: record otherPath first, then projectPath so projectPath is at index 0
    await ProjectHistoryService.instance.recordHistory(
      rootPath: otherPath,
      lastOpenedFilePath: null,
    );
    await ProjectHistoryService.instance.recordHistory(
      rootPath: projectPath,
      lastOpenedFilePath: p.normalize('$projectPath/main.dart'),
    );

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
          home: const Scaffold(
            body: ProjectHistoryWidget(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find delete buttons in the history list (there should be 2 projects)
    final deleteButtons = find.byIcon(Icons.delete_outline);
    expect(deleteButtons, findsNWidgets(2));

    // Tap delete on current project
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // 1. Should first prompt to save dirty changes of current project!
    expect(find.text('保存所有更改？'), findsOneWidget);

    // Discard changes
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    // 2. The second dialog (delete history) should appear!
    expect(find.text('删除历史记录'), findsOneWidget);
    expect(find.text('确定要从历史记录中移除该项目吗？'), findsOneWidget);

    // Case A: User taps cancel in remove dialog -> project should NOT be closed!
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(projectProvider.rootPath, equals(projectPath));

    // Case B: User taps delete again, proceeds, and taps remove -> now project is closed!
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    if (find.text('保存所有更改？').evaluate().isNotEmpty) {
      await tester.tap(find.text('不保存'));
      await tester.pumpAndSettle();
    }

    expect(find.text('删除历史记录'), findsOneWidget);

    // Tap remove
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    // Both true -> Project is now closed and removed from history
    expect(projectProvider.rootPath, isNull);

    // Let toast timer finish
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('CodeEditorDrawer header renders new file and new folder buttons when project is open', (WidgetTester tester) async {
    final projectProvider = ProjectProvider();
    final tabProvider = TabProvider();
    projectProvider.setHistoryForTesting(const ProjectHistory(
      rootPath: '/workspace/demo_app',
      lastOpenedFilePath: null,
    ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            drawer: CodeEditorDrawer(),
            body: Center(child: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify root path text is displayed
    expect(find.text('/workspace/demo_app'), findsOneWidget);

    // Verify new file and new folder icon buttons exist
    final newFileBtn = find.byIcon(Icons.note_add_outlined);
    final newFolderBtn = find.byIcon(Icons.create_new_folder_outlined);
    expect(newFileBtn, findsOneWidget);
    expect(newFolderBtn, findsOneWidget);

    // Tap new file button -> should show input dialog
    await tester.tap(newFileBtn);
    await tester.pumpAndSettle();
    expect(find.text('新建文件'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // Cancel input dialog
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('新建文件'), findsNothing);

    // Tap new folder button -> should show input dialog
    await tester.tap(newFolderBtn);
    await tester.pumpAndSettle();
    expect(find.text('新建文件夹'), findsOneWidget);

    // Cancel
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  group('Virtual Keyboard (Accessory Keyboard) Tests', () {
    test('Pure string in JSON keys is strictly parsed as input without guessing', () {
      final key1 = KeyboardKeyItem.fromJson(';');
      expect(key1.label, ';');
      expect(key1.value, ';');
      expect(key1.action, 'input');
      expect(key1.icon, isNull);

      // Verify strings with command names like Tab or () are NOT magically guessed
      final key2 = KeyboardKeyItem.fromJson('Tab');
      expect(key2.label, 'Tab');
      expect(key2.value, 'Tab');
      expect(key2.action, 'input');

      final key3 = KeyboardKeyItem.fromJson('{}');
      expect(key3.label, '{}');
      expect(key3.value, '{}');
      expect(key3.action, 'input');
      expect(key3.cursorOffset, 0);

      // Verify object format is parsed correctly
      final keyObj = KeyboardKeyItem.fromJson({
        'label': 'Tab',
        'icon': 'tab',
        'action': 'command',
        'value': 'tab',
      });
      expect(keyObj.label, 'Tab');
      expect(keyObj.icon, 'tab');
      expect(keyObj.action, 'command');
      expect(keyObj.value, 'tab');
    });

    test('KeyboardIconHelper maps known icons and returns null for unknown/empty', () {
      expect(KeyboardIconHelper.getIcon('tab'), isNotNull);
      expect(KeyboardIconHelper.getIcon('undo'), isNotNull);
      expect(KeyboardIconHelper.getIcon('arrow_left'), isNotNull);
      expect(KeyboardIconHelper.getIcon(null), isNull);
      expect(KeyboardIconHelper.getIcon(''), isNull);
      expect(KeyboardIconHelper.getIcon('non_existent_xyz'), isNull);
    });

    test('VirtualKeyboardConfig validateJson strictly identifies syntax and schema errors', () {
      // Empty check
      expect(VirtualKeyboardConfig.validateJson(''), '配置内容不能为空');
      expect(VirtualKeyboardConfig.validateJson('   '), '配置内容不能为空');

      // Syntax check with line and column reporting
      final syntaxErr = VirtualKeyboardConfig.validateJson('{\n  "pages": [\n    invalid\n  ]\n}');
      expect(syntaxErr, contains('JSON 语法错误'));
      expect(syntaxErr, contains('第 3 行'));

      // Root map check
      expect(VirtualKeyboardConfig.validateJson('[]'), contains('根节点必须是 JSON 对象'));

      // Pages array check
      expect(VirtualKeyboardConfig.validateJson('{}'), contains('缺少必需的 "pages"'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": "invalid"}'), contains('"pages" 字段必须是一个数组'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": []}'), contains('至少需要包含 1 个页面配置'));

      // Page item check
      expect(VirtualKeyboardConfig.validateJson('{"pages": ["not-a-map"]}'), contains('第 1 页必须是一个 JSON 对象'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{}]}'), contains('缺少必需的 "count" 字段'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{"count": 0, "keys": []}]}'), contains('"count" 必须为大于 0 的正整数'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{"count": 6}]}'), contains('缺少必需的 "keys" 字段'));

      // Row check
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{"count": 6, "keys": ["not-a-list"]}]}'), contains('第 1 页第 1 行必须是一个按键数组'));

      // Key check
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{"count": 6, "keys": [[123]]}]}'), contains('只能是文本字符串或对象'));
      expect(VirtualKeyboardConfig.validateJson('{"pages": [{"count": 6, "keys": [[{}]]}]}'), contains('缺少 label、value 或 icon 属性'));

      // Valid check (default config)
      final validJson = VirtualKeyboardConfig.defaultJsonPretty();
      expect(VirtualKeyboardConfig.validateJson(validJson), isNull);

      // Valid check with shorthand pure strings
      const shorthandJson = '''
      {
        "pages": [
          {
            "count": 6,
            "keys": [
              [";", "=", "+", "-", "*", "/"],
              ["(", ")", "[", "]", "{", "}"]
            ]
          }
        ]
      }
      ''';
      expect(VirtualKeyboardConfig.validateJson(shorthandJson), isNull);
    });

    testWidgets('VirtualKeyboardWidget renders keys according to count and handles input/commands', (tester) async {
      final controller = CodeLineEditingController.fromText('hello');
      controller.selection = const CodeLineSelection.collapsed(index: 0, offset: 5);

      final config = VirtualKeyboardConfig.defaultConfiguration();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualKeyboardWidget(
              controller: controller,
              config: config,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PageView should be present
      expect(find.byType(PageView), findsOneWidget);

      // Tab icon exists
      expect(find.byIcon(Icons.keyboard_tab), findsOneWidget);

      // Tap ';' key
      final semicolonKey = find.text(';');
      expect(semicolonKey, findsOneWidget);
      await tester.tap(semicolonKey);
      await tester.pumpAndSettle();

      // Controller should have received ';'
      expect(controller.text, 'hello;');

      // Tap '(' pair key -> should insert () and place cursor inside
      final parenKey = find.text('(');
      expect(parenKey, findsOneWidget);
      await tester.tap(parenKey);
      await tester.pumpAndSettle();

      expect(controller.text, 'hello;()');
      expect(controller.selection.extentOffset, 7); // between '(' and ')'
    });

    testWidgets('SettingsView displays virtual keyboard toggle and config dialog with embedded CodeEditor and line-level error report', (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setEnableVirtualKeyboard(true);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settingsProvider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to virtual keyboard tiles
      final configTile = find.text('编辑键盘配置');
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(configTile, findsOneWidget);

      // Tap config tile to open dialog
      await tester.tap(configTile);
      await tester.pumpAndSettle();

      expect(find.text('小键盘配置 (JSON)'), findsOneWidget);
      expect(find.text('格式化'), findsOneWidget);
      expect(find.text('恢复默认'), findsOneWidget);

      // Verify embedded CodeEditor is present with line number gutter
      expect(find.byType(CodeEditor), findsOneWidget);
      expect(find.byType(DefaultCodeLineNumber), findsOneWidget);

      final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final editorController = codeEditor.controller!;

      // Edit controller with invalid json on line 3
      editorController.text = '{\n  "pages": [\n    error_here\n  ]\n}';
      await tester.pumpAndSettle();

      // Tap '保存'
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Dialog should still be open and display error message with line number
      expect(find.text('小键盘配置 (JSON)'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('第 3 行'), findsOneWidget);

      // Tap '恢复默认'
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();

      // Error message should clear
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(editorController.text, contains('"pages"'));

      // Tap '保存' with valid config -> dialog closes
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('小键盘配置 (JSON)'), findsNothing);

      // Let success toast timer complete
      await tester.pump(const Duration(seconds: 3));
    });
  });
}





