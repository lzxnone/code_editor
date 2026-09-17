import 'dart:io';
import 'dart:ui';
import 'package:re_editor/re_editor.dart';
import 'package:code_editor/models/app_font.dart';
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
import 'package:xterm/xterm.dart';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/l10n/app_localizations_en.dart';
import 'package:code_editor/l10n/app_localizations_zh.dart';
import 'package:code_editor/main.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:code_editor/views/virtual_keyboard_config_view.dart';
import 'package:code_editor/widgets/virtual_keyboard_key_edit_dialog.dart';
import 'package:code_editor/widgets/color_palette_dialog.dart';
import 'package:code_editor/utils/app_theme.dart';
import 'package:code_editor/utils/terminal_theme_helper.dart';
import 'package:code_editor/widgets/terminal_keyboard_sink.dart';
import 'package:code_editor/widgets/terminal_modifier_state.dart';
import 'package:code_editor/widgets/virtual_keyboard_sink.dart';
import 'package:code_editor/widgets/virtual_keyboard_page_config_section.dart';
import 'package:code_editor/widgets/virtual_keyboard_page_drawer.dart';
import 'package:code_editor/widgets/terminal_session_item_widget.dart';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/services/file_watcher_service.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录调用参数的测试用 sink，用于断言键盘组件把什么语义交给了下方实现
class _RecordingSink implements VirtualKeyboardSink {
  final List<({String text, bool appendEnter})> texts = [];
  final List<({String name, KeyboardKeyMods mods})> namedKeys = [];
  final List<String> commands = [];
  int hideCount = 0;

  @override
  void sendText(String text, {bool appendEnter = false}) {
    texts.add((text: text, appendEnter: appendEnter));
  }

  @override
  void sendPair(String pairText, int cursorOffset) {}

  @override
  void sendCommand(String command) {
    commands.add(command);
  }

  @override
  void sendNamedKey(String keyName, {KeyboardKeyMods mods = KeyboardKeyMods.none}) {
    namedKeys.add((name: keyName, mods: mods));
  }

  @override
  void hideKeyboard() {
    hideCount++;
  }
}

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

    // Verify more menu button exists
    final moreBtnFinder = find.byIcon(Icons.more_vert);
    expect(moreBtnFinder, findsOneWidget);

    // Tap menu button
    await tester.tap(moreBtnFinder);
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

    // Scroll until word wrap switch is visible
    await tester.scrollUntilVisible(find.text('自动换行'), 200);

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
    expect(provider.wordWrap, isFalse);

    // Toggle word wrap
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(provider.wordWrap, isTrue);

    // Verify indent size tile（列表变长后需向上滚动重新定位）
    await tester.scrollUntilVisible(find.text('缩进大小'), -200);
    expect(find.text('缩进大小'), findsOneWidget);
    expect(find.text('4 个空格'), findsOneWidget);

    // Tap indent size tile to open modal
    await tester.tap(find.text('缩进大小'));
    await tester.pumpAndSettle();

    expect(find.text('选择缩进空格数'), findsOneWidget);
    expect(find.text('2 个空格'), findsOneWidget);

    // Select 2 spaces
    await tester.tap(find.text('2 个空格'));
    await tester.pumpAndSettle();

    expect(provider.indentSize, equals(2));

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

    expect(provider.wordWrap, isFalse);
    await provider.setWordWrap(true);
    expect(provider.wordWrap, isTrue);

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
    await tester.tap(find.byIcon(Icons.more_vert));
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

  testWidgets('DialogUtils.showToast adapts position above soft keyboard when viewInsets.bottom > 0', (WidgetTester tester) async {
    addTearDown(tester.view.resetViewInsets);
    late BuildContext targetContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              targetContext = ctx;
              return const Text('Target');
            },
          ),
        ),
      ),
    );

    // 1. 无软键盘时显示 Toast
    DialogUtils.showSuccessToast(targetContext, '保存成功');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('保存成功'), findsOneWidget);
    final initialCenter = tester.getCenter(find.text('保存成功'));

    // 等待第一个 Toast 自动卸载
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('保存成功'), findsNothing);

    // 2. 模拟系统软键盘弹出时 (viewInsets.bottom: 260 逻辑像素)
    tester.view.viewInsets = FakeViewPadding(bottom: 260 * tester.view.devicePixelRatio);
    DialogUtils.showSuccessToast(targetContext, '有键盘');
    await tester.pump(const Duration(milliseconds: 50));

    final keyboardCenter = tester.getCenter(find.text('有键盘'));
    // 键盘弹出后，Toast 中心点必须往上移（dy 变小）至少 200 像素以上，远离键盘遮挡区
    expect(keyboardCenter.dy, lessThan(initialCenter.dy - 200));

    // 等待 Toast 动画与定时器自动卸载
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('有键盘'), findsNothing);
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
    // Tab2 is dirty，脏标记 * 与文件名同处一个富文本中
    expect(find.text('*file2.dart'), findsOneWidget);

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
    expect(settings.indentSize, equals(4));
    expect(settings.wordWrap, isFalse);
    expect(settings.appThemeMode, equals(ThemeMode.system));

    await settings.setFontSize(18.0);
    expect(settings.fontSize, equals(18.0));

    await settings.setIndentSize(2);
    expect(settings.indentSize, equals(2));

    await settings.setWordWrap(true);
    expect(settings.wordWrap, isTrue);

    await settings.setAppThemeMode(ThemeMode.dark);
    expect(settings.appThemeMode, equals(ThemeMode.dark));

    await settings.setLocale(const Locale('en'));
    expect(settings.locale, equals(const Locale('en')));
  });

  test('SettingsProvider persists theme color and terminal background color', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.init();

    // 默认值：主题色为蓝色，终端背景为 xterm 默认深色
    expect(settings.appThemeColor.toARGB32(), Colors.blue.toARGB32());
    expect(settings.terminalBackgroundColor.toARGB32(), const Color(0xFF1E1E1E).toARGB32());

    await settings.setAppThemeColor(const Color(0xFFFF5722));
    await settings.setTerminalBackgroundColor(const Color(0xFF002B36));
    expect(settings.appThemeColor.toARGB32(), 0xFFFF5722);
    expect(settings.terminalBackgroundColor.toARGB32(), 0xFF002B36);

    // 落盘后能读回
    final reloaded = SettingsProvider();
    await reloaded.init();
    expect(reloaded.appThemeColor.toARGB32(), 0xFFFF5722);
    expect(reloaded.terminalBackgroundColor.toARGB32(), 0xFF002B36);
  });

  test('buildAppTheme derives the color scheme from the seed color', () {
    final blue = buildAppTheme(seedColor: Colors.blue, brightness: Brightness.light);
    final orange = buildAppTheme(seedColor: Colors.deepOrange, brightness: Brightness.light);

    expect(blue.colorScheme.primary, isNot(orange.colorScheme.primary));
    expect(blue.colorScheme.primary, ColorScheme.fromSeed(seedColor: Colors.blue).primary);
    expect(
      buildAppTheme(seedColor: Colors.blue, brightness: Brightness.dark).brightness,
      Brightness.dark,
    );
  });

  test('terminalThemeWithBackground switches foreground on light backgrounds', () {
    final dark = terminalThemeWithBackground(const Color(0xFF1E1E1E));
    expect(dark.background.toARGB32(), 0xFF1E1E1E);
    expect(dark.foreground.toARGB32(), TerminalThemes.defaultTheme.foreground.toARGB32());

    final light = terminalThemeWithBackground(const Color(0xFFFFFFFF));
    expect(light.background.toARGB32(), 0xFFFFFFFF);
    expect(light.foreground.computeLuminance(), lessThan(0.5));
    expect(light.cursor.computeLuminance(), lessThan(0.5));
  });

  testWidgets('color palette dialog returns the tapped swatch', (tester) async {
    Color? picked;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await ColorPaletteDialog.show(
                    context,
                    title: '选择主题颜色',
                    current: Colors.blue,
                    palette: ColorPaletteDialog.uiPalette,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 当前颜色带对勾
    expect(find.byIcon(Icons.check), findsOneWidget);

    final swatch = find.byKey(ValueKey<int>(const Color(0xFF009688).toARGB32()));
    await tester.ensureVisible(swatch);
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(picked?.toARGB32(), 0xFF009688);
  });

  testWidgets('SettingsView color tiles open the palette and apply the choice', (tester) async {
    final provider = SettingsProvider();
    await provider.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: SettingsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 主题颜色
    await tester.tap(find.text('主题颜色'));
    await tester.pumpAndSettle();
    expect(find.text('选择主题颜色'), findsOneWidget);
    final themeSwatch = find.byKey(ValueKey<int>(const Color(0xFF4CAF50).toARGB32()));
    await tester.ensureVisible(themeSwatch);
    await tester.pumpAndSettle();
    await tester.tap(themeSwatch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.appThemeColor.toARGB32(), 0xFF4CAF50);
    expect(find.text('#4CAF50'), findsWidgets);

    // 终端背景颜色（位于终端分组，需先滚动使其构建、再滚入可视区域）
    await tester.scrollUntilVisible(find.text('终端背景颜色'), 200);
    await tester.ensureVisible(find.text('终端背景颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('终端背景颜色'));
    await tester.pumpAndSettle();
    expect(find.text('选择终端背景颜色'), findsOneWidget);
    final termSwatch = find.byKey(ValueKey<int>(const Color(0xFF263238).toARGB32()));
    await tester.ensureVisible(termSwatch);
    await tester.pumpAndSettle();
    await tester.tap(termSwatch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.terminalBackgroundColor.toARGB32(), 0xFF263238);
    expect(find.text('#263238'), findsWidgets);
  });

  test('SettingsProvider keeps editor and terminal keyboard configs independent', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.init();

    // 默认预设不同：编辑区是代码符号，终端是两行特殊键 + 修饰键
    expect(settings.keyboardConfigFor(KeyboardScope.editor).pages.first.keys.first.first.value, 'tab');
    final terminalPage = settings.keyboardConfigFor(KeyboardScope.terminal).pages.first;
    expect(terminalPage.keys.first.first.value, 'escape');
    expect(terminalPage.keys.length, equals(2));
    expect(terminalPage.keys[0].any((k) => k.action == 'modifier'), isTrue);
    expect(terminalPage.keys[1].any((k) => k.action == 'modifier'), isTrue);

    // 写入终端配置不影响编辑区
    final editorJsonBefore = settings.keyboardConfigJsonFor(KeyboardScope.editor);
    const terminalJson = '{"pages":[{"count":7,"keys":[[{"label":"^C","action":"key","value":"keyC",'
        '"mods":{"ctrl":true}}]]}]}';
    expect(await settings.setKeyboardConfig(KeyboardScope.terminal, terminalJson), isTrue);
    expect(settings.keyboardConfigJsonFor(KeyboardScope.editor), editorJsonBefore);
    expect(
      settings.keyboardConfigFor(KeyboardScope.terminal).pages.first.keys.first.first.value,
      'keyC',
    );

    // 作用域校验生效：编辑区动作写进终端配置应被拒绝，且不产生副作用
    const editorOnlyJson = '{"pages":[{"count":7,"keys":[[{"label":"()","action":"pair","value":"()"}]]}]}';
    expect(await settings.setKeyboardConfig(KeyboardScope.terminal, editorOnlyJson), isFalse);
    expect(settings.keyboardConfigFor(KeyboardScope.terminal).pages.first.keys.first.first.value, 'keyC');

    // 两个开关相互独立
    await settings.setKeyboardEnabled(KeyboardScope.terminal, false);
    expect(settings.keyboardEnabledFor(KeyboardScope.terminal), isFalse);
    expect(settings.keyboardEnabledFor(KeyboardScope.editor), isTrue);

    // 恢复默认只影响对应作用域
    await settings.resetKeyboardConfig(KeyboardScope.terminal);
    expect(settings.keyboardConfigFor(KeyboardScope.terminal).pages.first.keys.first.first.value, 'escape');
    expect(settings.keyboardConfigJsonFor(KeyboardScope.editor), editorJsonBefore);
  });

  test('SettingsProvider loads both keyboard configs from storage', () async {
    const terminalJson = '{"pages":[{"count":6,"keys":[[{"label":"Tab","action":"key","value":"tab"}]]}]}';
    SharedPreferences.setMockInitialValues({
      'virtual_keyboard_config': VirtualKeyboardConfig.defaultJsonPretty(),
      'terminal_virtual_keyboard_config': terminalJson,
      'enable_terminal_virtual_keyboard': false,
    });

    final settings = SettingsProvider();
    await settings.init();

    expect(settings.keyboardConfigFor(KeyboardScope.terminal).pages.first.count, 6);
    expect(settings.keyboardConfigFor(KeyboardScope.terminal).pages.first.keys.first.first.value, 'tab');
    expect(settings.keyboardEnabledFor(KeyboardScope.terminal), isFalse);
    // 编辑区配置仍是自己的那份
    expect(settings.keyboardConfigFor(KeyboardScope.editor).pages.first.count, 7);

    // 终端配置非法（用了编辑区动作）时应被丢弃并回退到终端默认预设
    SharedPreferences.setMockInitialValues({
      'terminal_virtual_keyboard_config':
          '{"pages":[{"count":6,"keys":[[{"label":"x","action":"command","value":"undo"}]]}]}',
    });
    final fallback = SettingsProvider();
    await fallback.init();
    expect(fallback.keyboardConfigFor(KeyboardScope.terminal).pages.first.keys.first.first.value, 'escape');
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
    final tempDir = Directory.systemTemp.createTempSync('widget_test_tab_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final tabProvider = TabProvider();
    final projectProvider = ProjectProvider();
    final settingsProvider = SettingsProvider();

    final file1 = FileItem(path: p.join(tempDir.path, 'file1.dart'), name: 'file1.dart', isDirectory: false);
    final file2 = FileItem(path: p.join(tempDir.path, 'file2.dart'), name: 'file2.dart', isDirectory: false);
    File(file2.path).writeAsStringSync('int b = 2;');

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify main view is rendered with modified file1
    expect(find.textContaining('file1.dart'), findsWidgets);
    expect(tabProvider.isModified, isTrue);

    // Open file2 via openFile (with content specified, or selectFile)
    await tabProvider.openFile(file2.path, content: 'int b = 2;');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // NO save prompt dialog should appear
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('保存所有更改？'), findsNothing);

    // Now file2 is active, file1 is still open and preserved in memory
    expect(tabProvider.activeTab?.path, equals(p.normalize(file2.path)));
    expect(tabProvider.openTabs.length, equals(2));
    expect(tabProvider.openTabs[0].isModified, isTrue);
    expect(tabProvider.openTabs[0].content, equals('int a = 2;'));

    // Switch back to file1 via openFile (simulating clicking tab1)
    await tabProvider.openFile(file1.path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // NO save prompt dialog should appear on tab switch either
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('保存所有更改？'), findsNothing);
    expect(tabProvider.activeTab?.path, equals(p.normalize(file1.path)));
    expect(tabProvider.activeTab?.isModified, isTrue);

    // Unmount MainView so cursor blinking timer cancels cleanly
    await tester.pumpWidget(const SizedBox());
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tabProvider.openTabs.length, equals(1));

    // Tap more menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap '关闭所有标签'
    await tester.tap(find.text('关闭所有标签'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Dirty prompt dialog should appear
    expect(find.text('保存所有更改？'), findsOneWidget);

    // Choose discard (不保存)
    await tester.tap(find.text('不保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // All tabs should be closed
    expect(tabProvider.openTabs, isEmpty);
    expect(tabProvider.activeTab, isNull);

    await tester.pumpWidget(const SizedBox());
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

    test('terminal scope validation accepts the three terminal actions and rejects the rest', () {
      String? check(String keyJson) =>
          VirtualKeyboardConfig.validateJson('{"pages":[{"count":6,"keys":[[$keyJson]]}]}', KeyboardScope.terminal);

      // input（指令快捷键）+ autoEnter
      expect(check('{"label":"cd ..","action":"input","value":"cd ..","autoEnter":true}'), isNull);
      expect(check('{"label":"cd","action":"input"}'), contains('缺少文本内容'));

      // key（特殊键）：31 个命名键任意修饰组合都合法
      expect(check('{"label":"Esc","action":"key","value":"escape"}'), isNull);
      expect(check('{"label":"↑","action":"key","value":"arrowUp","mods":{"ctrl":true}}'), isNull);
      expect(check('{"label":"⇤","action":"key","value":"backtab","mods":{"shift":true}}'), isNull);

      // key + 字母键：不受修饰符约束，单独成格就是该字母
      expect(check('{"label":"^C","action":"key","value":"keyC","mods":{"ctrl":true}}'), isNull);
      expect(check('{"label":"Alt+.","action":"key","value":"keyZ","mods":{"alt":true}}'), isNull);
      expect(check('{"label":"c","action":"key","value":"keyC"}'), isNull);
      expect(check('{"label":"^C","action":"key","value":"keyC","mods":{"ctrl":true,"shift":true}}'), isNull);

      // key：默认 keytab 里没有的键必须被拦下（否则运行时静默无输出）
      expect(check('{"label":"1","action":"key","value":"digit1"}'), contains('不会产生任何输出'));
      expect(check('{"label":"Home","action":"key","value":"homeKey"}'), contains('不会产生任何输出'));
      expect(check('{"label":"Esc","action":"key"}'), contains('缺少特殊键值'));

      // modifier：只能 ctrl / alt / shift，且不允许再挂 mods
      expect(check('{"label":"Ctrl","action":"modifier","value":"ctrl"}'), isNull);
      expect(check('{"label":"Shift","action":"modifier","value":"shift"}'), isNull);
      expect(check('{"label":"Meta","action":"modifier","value":"meta"}'), contains('修饰键取值'));
      expect(check('{"label":"Ctrl","action":"modifier","value":"ctrl","mods":{"alt":true}}'), contains('不应再附带'));

      // 文本通道附加 mods 不会生效 → 直接拦下
      expect(check('{"label":"x","action":"input","value":"ls","mods":{"ctrl":true}}'), contains('"mods" 不会生效'));

      // 编辑区动作在终端里非法
      expect(check('{"label":"()","action":"pair","value":"()"}'), contains('不适用于终端'));
      expect(check('{"label":"Tab","action":"command","value":"tab"}'), contains('不适用于终端'));

      // 默认终端预设自身必须能通过终端作用域校验（否则写入存储后会被 init 丢弃）
      expect(
        VirtualKeyboardConfig.validateJson(
          VirtualKeyboardConfig.defaultTerminalJsonPretty(),
          KeyboardScope.terminal,
        ),
        isNull,
      );
    });

    test('editor scope validation rejects terminal-only actions', () {
      String? check(String keyJson) =>
          VirtualKeyboardConfig.validateJson('{"pages":[{"count":6,"keys":[[$keyJson]]}]}');

      expect(check('{"label":"()","action":"pair","value":"()","cursorOffset":-1}'), isNull);
      expect(check('{"label":"Tab","action":"command","value":"tab"}'), isNull);
      expect(check('{"label":"Esc","action":"key","value":"escape"}'), contains('不适用于编辑区'));
      expect(check('{"label":"Ctrl","action":"modifier","value":"ctrl"}'), contains('不适用于编辑区'));
    });

    test('KeyboardKeyItem round-trips mods / autoEnter and omits empty values', () {
      final item = KeyboardKeyItem.fromJson({
        'label': '^C',
        'action': 'key',
        'value': 'keyC',
        'mods': {'ctrl': true, 'alt': false},
        'autoEnter': true,
      });
      expect(item.mods.ctrl, isTrue);
      expect(item.mods.alt, isFalse);
      expect(item.mods.shift, isFalse);
      expect(item.autoEnter, isTrue);
      expect(item.toJson()['mods'], {'ctrl': true});
      expect(item.toJson()['autoEnter'], true);

      // 无修饰、非自动回车时，两个字段都不出现在 JSON 中（编辑区配置保持零变化）
      const plain = KeyboardKeyItem(label: ';', value: ';');
      expect(plain.toJson().containsKey('mods'), isFalse);
      expect(plain.toJson().containsKey('autoEnter'), isFalse);
      expect(plain.mods.isEmpty, isTrue);

      // 非法 mods 输入一律视为无修饰，不抛异常
      expect(KeyboardKeyMods.fromJson('not-a-map').isEmpty, isTrue);
      expect(KeyboardKeyMods.fromJson(null).isEmpty, isTrue);
    });

    test('terminal named key table matches xterm TerminalKey exactly', () {
      // 白名单必须全部是真实存在的 TerminalKey 枚举名，反之运行时才能解析
      final available = TerminalKey.values.map((k) => k.name).toSet();
      for (final key in KeyboardScopeHelper.terminalNamedKeys) {
        expect(available, contains(key.value), reason: 'xterm 中不存在 TerminalKey.${key.value}');
      }
      expect(KeyboardScopeHelper.terminalNamedKeys.length, equals(31));
      // 下拉可选集合 = 31 命名键 + 26 字母键
      expect(KeyboardScopeHelper.terminalSelectableKeys.length, equals(31 + 26));

      // 字母键不再受修饰符约束：单独就是该字母
      expect(KeyboardScopeHelper.isSupportedTerminalKey('keyC'), isTrue);
      expect(KeyboardScopeHelper.isSupportedTerminalKey('escape'), isTrue);
      expect(KeyboardScopeHelper.isSupportedTerminalKey('digit1'), isFalse);
      expect(KeyboardScopeHelper.isSupportedTerminalKey('keyAB'), isFalse);

      // 支持集合 = 31 命名键 + 26 字母键
      expect(KeyboardScopeHelper.terminalSupportedKeyNames.length, equals(31 + 26));
    });

    test('every selectable terminal key carries a valid icon', () {
      for (final option in KeyboardScopeHelper.terminalSelectableKeys) {
        expect(option.icon, isNotNull, reason: '缺少图标: ${option.value}');
        expect(
          KeyboardIconHelper.getIcon(option.icon),
          isNotNull,
          reason: '图标常量不存在: ${option.icon} (${option.value})',
        );
      }
    });

    test('every named terminal key has a localized name in zh and en', () {
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();
      for (final key in KeyboardScopeHelper.terminalNamedKeys) {
        expect(zh.keyboardKeyName(key.value), isNot(key.value), reason: 'zh 缺少特殊键名称: ${key.value}');
        expect(en.keyboardKeyName(key.value), isNot(key.value), reason: 'en 缺少特殊键名称: ${key.value}');
      }
      // 动作改名后（terminal_key → key）三个终端动作都要有名字
      for (final option in KeyboardScopeHelper.terminalActions) {
        expect(zh.keyboardActionName(option.action), isNot(option.action));
        expect(en.keyboardActionName(option.action), isNot(option.action));
      }
      expect(zh.keyboardActionInputTerminal, '指令快捷键');
      expect(en.keyboardActionInputTerminal, 'Command Shortcut');
    });

    test('TerminalKeyboardSink emits real escape sequences through onOutput', () {
      final terminal = Terminal();
      final emitted = <String>[];
      terminal.onOutput = emitted.add;
      final sink = TerminalKeyboardSink(terminal: terminal);

      // 文本指令：无回车 / 自动回车 / 已含回车不重复补
      sink.sendText('cd ..');
      expect(emitted.last, 'cd ..');
      sink.sendText('cd ..', appendEnter: true);
      expect(emitted.last, 'cd ..\r');
      sink.sendText('ls\r', appendEnter: true);
      expect(emitted.last, 'ls\r');

      // 命名特殊键：keytab 中的真实序列
      sink.sendNamedKey('escape');
      expect(emitted.last, '\x1b');
      sink.sendNamedKey('arrowUp');
      expect(emitted.last, '\x1b[A');
      sink.sendNamedKey('tab', mods: const KeyboardKeyMods(shift: true));
      expect(emitted.last, '\x1b[Z');

      // 字母键 + 单独 Ctrl / Alt
      sink.sendNamedKey('keyC', mods: const KeyboardKeyMods(ctrl: true));
      expect(emitted.last, '\x03');
      sink.sendNamedKey('keyD', mods: const KeyboardKeyMods(ctrl: true));
      expect(emitted.last, '\x04');
      sink.sendNamedKey('keyZ', mods: const KeyboardKeyMods(alt: true));
      // 注意：xterm 的 AltInputHandler 输出的是大写字母（ESC + 'Z'）
      expect(emitted.last, '\x1bZ');

      // 无修饰的字母键会发送该字母本身；keytab 之外的键仍必须无输出
      sink.sendNamedKey('keyC');
      expect(emitted.last, 'c');
      final countBefore = emitted.length;
      sink.sendNamedKey('digit1');
      sink.sendNamedKey('not_a_key');
      expect(emitted.length, countBefore);
    });

    testWidgets('VirtualKeyboardWidget applies one-shot and locked modifiers', (tester) async {
      // 注入假时钟：确定性地控制"单击"与"双击"，不依赖真实时间
      var fakeNow = DateTime(2024, 1, 1);
      final modifierState = TerminalModifierState(clock: () => fakeNow);

      final sink = _RecordingSink();
      final config = VirtualKeyboardConfig(pages: [
        KeyboardPageItem(count: 4, keys: [
          [
            const KeyboardKeyItem(label: 'Ctrl', action: 'modifier', value: 'ctrl'),
            const KeyboardKeyItem(label: 'C', action: 'key', value: 'keyC'),
            const KeyboardKeyItem(label: 'x', action: 'input', value: 'x'),
            const KeyboardKeyItem(label: '^', action: 'key', value: 'keyC', mods: KeyboardKeyMods(ctrl: true)),
          ],
        ]),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualKeyboardWidget(
              controller: null,
              sink: sink,
              modifierState: modifierState,
              config: config,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 一次性：点 Ctrl 后下一次按键带 ctrl，之后自动清除
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      // 状态写在共享对象上（终端据此改写软键盘输入）
      expect(modifierState.mods.ctrl, isTrue);
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.name, 'keyC');
      expect(sink.namedKeys.last.mods.ctrl, isTrue);
      expect(modifierState.mods.isEmpty, isTrue, reason: '一次性状态应被下一次按键消耗');

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.mods.ctrl, isFalse);

      // 一次性状态也会被"不产生字符"的其它按键消耗：点 Ctrl 后按文本键 x
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();
      expect(sink.texts.last.text, 'x');
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.mods.ctrl, isFalse, reason: '一次性 Ctrl 应已被文本键消耗');

      // 双击锁定：连续两次按键都带 ctrl，再点 Ctrl 解除
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.tap(find.text('Ctrl'));
      await tester.pump(const Duration(milliseconds: 50));
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.mods.ctrl, isTrue);
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.mods.ctrl, isTrue, reason: '锁定状态应持续生效');

      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(sink.namedKeys.last.mods.ctrl, isFalse, reason: '再次点击应解除锁定');
    });

    testWidgets('VirtualKeyboardWidget merges per-key mods with active modifiers', (tester) async {
      final sink = _RecordingSink();
      final config = VirtualKeyboardConfig(pages: [
        KeyboardPageItem(count: 2, keys: [
          [
            const KeyboardKeyItem(label: 'Alt', action: 'modifier', value: 'alt'),
            const KeyboardKeyItem(label: '^', action: 'key', value: 'keyC', mods: KeyboardKeyMods(ctrl: true)),
          ],
        ]),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualKeyboardWidget(
              controller: null,
              sink: sink,
              modifierState: TerminalModifierState(),
              config: config,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('^'));
      await tester.pumpAndSettle();

      // 按键自带 ctrl 与运行时激活的 alt 叠加
      expect(sink.namedKeys.last.mods.ctrl, isTrue);
      expect(sink.namedKeys.last.mods.alt, isTrue);
    });

    testWidgets('letter keys show a keyboard icon inside the special-key dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: KeyEditDialog(
              scope: KeyboardScope.terminal,
              initialKey: KeyboardKeyItem(label: 'C', action: 'key', value: 'keyC'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开特殊键下拉（会自动滚动到当前选中的 keyC，字母键分组随之可见）
      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await tester.pumpAndSettle();
      expect(find.text('字母键'), findsWidgets);

      final aItem = find.ancestor(
        of: find.text('A').last,
        matching: find.byType(DropdownMenuItem<String?>),
      );
      expect(
        find.descendant(of: aItem, matching: find.byIcon(Icons.keyboard_outlined)),
        findsWidgets,
        reason: '字母键 A 在下拉里应带键盘图标',
      );
      // F 键的图标数据由 'every selectable terminal key carries a valid icon' 覆盖
      // （F1 不在当前滚动位置，菜单只渲染可见项）
    });

    testWidgets('KeyEditDialog terminal form builds command shortcut / special key / modifier keys', (tester) async {
      KeyboardKeyItem? saved;
      KeyboardKeyItem? initialKey;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<KeyboardKeyItem>(
                      context: context,
                      builder: (ctx) => KeyEditDialog(scope: KeyboardScope.terminal, initialKey: initialKey),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      // ① 指令快捷键 + 自动回车
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 终端作用域的 input 显示为“指令快捷键”
      expect(find.text('指令快捷键'), findsWidgets);

      await tester.enterText(find.widgetWithText(TextFormField, '输入文本内容'), 'git status');
      await tester.tap(find.text('发送后自动回车'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(saved!.action, 'input');
      expect(saved!.value, 'git status');
      expect(saved!.autoEnter, isTrue);
      // 标签留空时回退为文本本身
      expect(saved!.label, 'git status');

      // ② 编辑已有特殊键 Ctrl+C（下拉选字母键 + 下方修饰键控件叠加）
      initialKey = const KeyboardKeyItem(
        label: 'Ctrl+C',
        action: 'key',
        value: 'keyC',
        mods: KeyboardKeyMods(ctrl: true),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('特殊键'), findsWidgets);
      // 下拉按钮显示当前选中的键名，修饰键控件状态与配置一致
      expect(find.text('C'), findsWidgets);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Ctrl 键')).selected, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Shift 键')).selected, isFalse);

      // 下拉会自动滚动到当前选中项，字母键分组标题随之可见
      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await tester.pumpAndSettle();
      expect(find.text('字母键'), findsWidgets);
      // 改选另一个字母键 keyD
      await tester.tap(find.text('D').last);
      await tester.pumpAndSettle();
      expect(find.text('D'), findsWidgets);

      // 取消 Ctrl 后就是一枚普通字母键（不再被拦截），标签留空则用紧凑键名
      await tester.tap(find.text('Ctrl 键'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '显示文本'), '');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(saved!.action, 'key');
      expect(saved!.value, 'keyD');
      expect(saved!.mods.isEmpty, isTrue);
      expect(saved!.label, 'D');

      // ④ 修饰键动作（Ctrl / Alt / Shift 三选一）
      initialKey = null;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('修饰键').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shift 键').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(saved!.action, 'modifier');
      expect(saved!.value, 'shift');
      expect(saved!.mods.isEmpty, isTrue);
    });

    testWidgets('SettingsView terminal keyboard entry edits the terminal config only', (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
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

      // 终端分组有独立开关，默认与编辑区开关互不影响
      await tester.scrollUntilVisible(find.text('终端小键盘'), 200);
      expect(find.text('终端小键盘'), findsOneWidget);

      // 关闭终端小键盘后，配置入口被禁用但编辑区的仍可用
      final terminalSwitch = find.descendant(
        of: find.widgetWithText(SwitchListTile, '终端小键盘'),
        matching: find.byType(Switch),
      );
      await tester.tap(terminalSwitch);
      await tester.pumpAndSettle();
      expect(settingsProvider.keyboardEnabledFor(KeyboardScope.terminal), isFalse);
      expect(settingsProvider.keyboardEnabledFor(KeyboardScope.editor), isTrue);
      await tester.tap(terminalSwitch);
      await tester.pumpAndSettle();
      expect(settingsProvider.keyboardEnabledFor(KeyboardScope.terminal), isTrue);

      await tester.scrollUntilVisible(find.text('编辑终端键盘配置'), 200);
      expect(find.text('编辑终端键盘配置'), findsOneWidget);

      // 进入终端键盘配置页：副标题显示“终端”
      final editorJsonBefore = settingsProvider.keyboardConfigJsonFor(KeyboardScope.editor);
      await tester.tap(find.text('编辑终端键盘配置'));
      await tester.pumpAndSettle();

      expect(find.byType(VirtualKeyboardConfigView), findsOneWidget);
      expect(find.text('终端:(第 1 页)'), findsOneWidget);

      // 改一行按钮数 → 只写终端那份 JSON
      await tester.tap(find.byTooltip('增加每行按键数'));
      await tester.pumpAndSettle();
      expect(settingsProvider.keyboardConfigFor(KeyboardScope.terminal).pages[0].count, 8);
      expect(settingsProvider.keyboardConfigJsonFor(KeyboardScope.editor), editorJsonBefore);

      // 恢复默认只作用于终端那份（回到 escape 开头的终端预设）
      await tester.tap(find.byTooltip('恢复默认预设'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(settingsProvider.keyboardConfigFor(KeyboardScope.terminal).pages[0].count, 7);
      expect(settingsProvider.keyboardConfigJsonFor(KeyboardScope.editor), editorJsonBefore);

      // 等 toast 定时器结束，避免测试结束时仍有 pending timer
      await tester.pump(const Duration(seconds: 3));
    });

    test('TerminalKeyboardSink sends bare letters and modifier combos', () {
      final terminal = Terminal();
      final emitted = <String>[];
      terminal.onOutput = emitted.add;
      final sink = TerminalKeyboardSink(terminal: terminal);

      // 字母键不再要求修饰符：单独成格时就是该字母
      sink.sendNamedKey('keyC');
      expect(emitted.last, 'c');
      sink.sendNamedKey('keyC', mods: const KeyboardKeyMods(shift: true));
      expect(emitted.last, 'C');
      sink.sendNamedKey('keyC', mods: const KeyboardKeyMods(ctrl: true));
      expect(emitted.last, '\x03');
      sink.sendNamedKey('keyZ', mods: const KeyboardKeyMods(ctrl: true));
      expect(emitted.last, '\x1a');
      sink.sendNamedKey('keyC', mods: const KeyboardKeyMods(alt: true));
      expect(emitted.last, '\x1bC');
    });

    test('applyModifierToTypedText mirrors charInput rules for soft-keyboard input', () {
      const none = KeyboardKeyMods();
      const ctrl = KeyboardKeyMods(ctrl: true);
      const alt = KeyboardKeyMods(alt: true);
      const shift = KeyboardKeyMods(shift: true);

      // 无修饰 → 不需要改写
      expect(applyModifierToTypedText('c', none), isNull);
      // Ctrl
      expect(applyModifierToTypedText('c', ctrl), '\x03');
      expect(applyModifierToTypedText('C', ctrl), '\x03');
      expect(applyModifierToTypedText('[', ctrl), '\x1b');
      // Alt / Shift
      expect(applyModifierToTypedText('c', alt), '\x1bC');
      expect(applyModifierToTypedText('c', shift), 'C');
      // 多字符（粘贴 / 指令快捷键）与不可改写的字符原样放过
      expect(applyModifierToTypedText('cd ..', ctrl), isNull);
      expect(applyModifierToTypedText('1', ctrl), isNull);
      expect(applyModifierToTypedText('中', ctrl), isNull);
      expect(applyModifierToTypedText('', ctrl), isNull);
    });

    test('TerminalModifierState implements one-shot / lock / consume', () {
      var now = DateTime(2024, 1, 1);
      final state = TerminalModifierState(clock: () => now);

      state.toggle('ctrl');
      expect(state.mods.ctrl, isTrue);
      state.consume();
      expect(state.mods.isEmpty, isTrue);

      // 双击锁定：消耗后仍生效
      now = now.add(const Duration(seconds: 1));
      state.toggle('ctrl');
      now = now.add(const Duration(milliseconds: 50));
      state.toggle('ctrl');
      state.consume();
      expect(state.mods.ctrl, isTrue, reason: '锁定状态不应被消耗');

      state.toggle('ctrl');
      expect(state.mods.isEmpty, isTrue, reason: '再次点击解除锁定');
      expect(state.isEmpty, isTrue);
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

      // Untab button icon exists in row 1
      expect(find.byIcon(Icons.format_indent_decrease), findsOneWidget);

      // Tap '()' pair key -> should insert () and place cursor inside
      final parenKey = find.text('()');
      expect(parenKey, findsOneWidget);
      await tester.tap(parenKey);
      await tester.pumpAndSettle();

      expect(controller.text, 'hello()');
      expect(controller.selection.extentOffset, 6); // between '(' and ')'
    });

    testWidgets('VirtualKeyboardWidget hides completely when no keys, hides dots in single row, and expands smoothly on drag', (tester) async {
      final controller = CodeLineEditingController.fromText('');

      // 1. 无按键配置下完全不显示 (SizedBox.shrink)
      const emptyConfig = VirtualKeyboardConfig(pages: []);
      expect(emptyConfig.hasKeys, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualKeyboardWidget(
              controller: controller,
              config: emptyConfig,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);

      // 2. 正常多页多行配置
      final config = VirtualKeyboardConfig.defaultConfiguration();
      expect(config.hasKeys, isTrue);

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

      // 默认只显示一行，初始高度为 30，且分页指示圆点不显示
      final keyboardFinder = find.byType(VirtualKeyboardWidget);
      expect(keyboardFinder, findsOneWidget);
      final initialSize = tester.getSize(keyboardFinder);
      expect(initialSize.height, closeTo(30.0, 1.0));

      // 向上拖动上拉手势测试
      await tester.drag(keyboardFinder, const Offset(0, -60));
      await tester.pumpAndSettle();

      // 展开后高度增加（多行 + 分页圆点）
      final expandedSize = tester.getSize(keyboardFinder);
      expect(expandedSize.height, greaterThan(65.0));

      // 再次向下拉收起
      await tester.drag(keyboardFinder, const Offset(0, 60));
      await tester.pumpAndSettle();

      final collapsedSize = tester.getSize(keyboardFinder);
      expect(collapsedSize.height, closeTo(30.0, 1.0));
    });

    testWidgets('KeyEditDialog pair action takes free-form pair text with validation', (tester) async {
      KeyboardKeyItem? saved;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<KeyboardKeyItem>(
                      context: context,
                      builder: (ctx) => const KeyEditDialog(scope: KeyboardScope.editor),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyEditDialog), findsOneWidget);

      // 动作类型下拉中不再有“成对符号预设”列表，只有动作本身
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('成对符号').last);
      await tester.pumpAndSettle();

      // 成对符号为自由输入框，默认填入 ()，且不再显示光标偏移的辅助说明文本
      final pairField = find.widgetWithText(TextFormField, '成对符号');
      expect(pairField, findsOneWidget);
      expect(find.text('()'), findsOneWidget);
      expect(find.textContaining('插入后光标'), findsNothing);

      // 左右完全相同的符号应被拦截
      await tester.enterText(pairField, '<<');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyEditDialog), findsOneWidget);
      expect(find.textContaining('左右不同'), findsOneWidget);

      // 旧预设列表之外的任意成对符号均可保存
      await tester.enterText(pairField, '/**/');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyEditDialog), findsNothing);
      expect(saved, isNotNull);
      expect(saved!.action, 'pair');
      expect(saved!.value, '/**/');
      expect(saved!.cursorOffset, -1);
      // 标签留空时回退为成对符号内容
      expect(saved!.label, '/**/');
    });

    testWidgets('KeyEditDialog icon dropdown shows localized icon names', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: KeyEditDialog(scope: KeyboardScope.editor)),
        ),
      );
      await tester.pumpAndSettle();

      // 展开图标下拉
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // 图标名称已本地化，不再直接展示内部英文 key
      expect(find.text('撤销'), findsWidgets); // undo
      expect(find.text('重做'), findsWidgets); // redo
      expect(find.text('向右缩进'), findsWidgets); // tab
      expect(find.text('undo'), findsNothing);
      expect(find.text('redo'), findsNothing);
    });

    test('every supported icon key has a localized name in zh and en', () {
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();
      for (final iconKey in KeyboardIconHelper.supportedIconKeys) {
        // 未在 ARB 的 select 中登记时会回退成原始 key，这里据此兜底校验
        expect(zh.keyboardIconName(iconKey), isNot(iconKey), reason: 'zh 缺少图标名称: $iconKey');
        expect(en.keyboardIconName(iconKey), isNot(iconKey), reason: 'en 缺少图标名称: $iconKey');
      }
    });

    testWidgets('KeyEditDialog command dropdown prefixes an icon for each option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: KeyEditDialog(scope: KeyboardScope.editor)),
        ),
      );
      await tester.pumpAndSettle();

      // 动作类型切换为“编辑器命令”
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑器命令').last);
      await tester.pumpAndSettle();

      // 字段文案已去掉“预设”，当前选中项（向右缩进）带图标
      expect(find.text('预设编辑器命令'), findsNothing);
      expect(find.byIcon(Icons.keyboard_tab), findsWidgets);
      expect(find.text('向右缩进'), findsWidgets);

      // 展开命令下拉，各项前均有图标
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.undo), findsWidgets);
      expect(find.text('撤销'), findsWidgets);
    });

    test('every action / command / modifier / terminal key value has a localized name', () {
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();

      for (final option in [...KeyboardScopeHelper.editorActions, ...KeyboardScopeHelper.terminalActions]) {
        expect(zh.keyboardActionName(option.action), isNot(option.action), reason: 'zh 缺少动作名称: ${option.action}');
        expect(en.keyboardActionName(option.action), isNot(option.action), reason: 'en 缺少动作名称: ${option.action}');
      }
      for (final cmd in KeyboardScopeHelper.editorCommands) {
        expect(zh.keyboardCommandName(cmd.value), isNot(cmd.value), reason: 'zh 缺少命令名称: ${cmd.value}');
        expect(en.keyboardCommandName(cmd.value), isNot(cmd.value), reason: 'en 缺少命令名称: ${cmd.value}');
      }
      for (final modifier in KeyboardScopeHelper.terminalModifierValues) {
        expect(zh.keyboardModifierName(modifier), isNot(modifier), reason: 'zh 缺少修饰键名称: $modifier');
        expect(en.keyboardModifierName(modifier), isNot(modifier), reason: 'en 缺少修饰键名称: $modifier');
      }
    });

    testWidgets('KeyEditDialog action and command dropdowns follow the locale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: KeyEditDialog(scope: KeyboardScope.editor)),
        ),
      );
      await tester.pumpAndSettle();

      // 动作下拉为英文，不再回落到硬编码中文
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Plain Text'), findsWidgets);
      expect(find.text('Pair Symbols'), findsWidgets);
      expect(find.text('Editor Command'), findsWidgets);
      expect(find.text('普通文本'), findsNothing);

      await tester.tap(find.text('Editor Command').last);
      await tester.pumpAndSettle();

      // 命令下拉同样为英文
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('Indent'), findsWidgets);
      expect(find.text('Undo'), findsWidgets);
      expect(find.text('向右缩进'), findsNothing);
    });

    testWidgets('VirtualKeyboardPageConfigSection does not overflow on narrow layouts', (tester) async {
      tester.view.physicalSize = const Size(240, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: VirtualKeyboardPageConfigSection(count: 7, onCountChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 行按钮数一行曾把定宽控件挤出右边界，此处断言不再发生 RenderFlex 溢出
      expect(tester.takeException(), isNull);
      expect(find.text('行按钮数'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('SettingsView navigates to VirtualKeyboardConfigView with full visual config controls', (tester) async {
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
      await tester.scrollUntilVisible(configTile, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(configTile, findsOneWidget);

      // Tap config tile to navigate to VirtualKeyboardConfigView
      await tester.tap(configTile);
      await tester.pumpAndSettle();

      // Verify VirtualKeyboardConfigView is rendered
      expect(find.byType(VirtualKeyboardConfigView), findsOneWidget);
      expect(find.text('小键盘配置'), findsOneWidget);
      expect(find.text('编辑区:(第 1 页)'), findsOneWidget);
      expect(find.text('页面配置'), findsOneWidget);
      expect(find.text('页面按键'), findsOneWidget);
      expect(find.text('行按钮数'), findsOneWidget);

      // Test increasing/decreasing count
      final addCountButton = find.byTooltip('增加每行按键数');
      expect(addCountButton, findsOneWidget);
      await tester.tap(addCountButton);
      await tester.pumpAndSettle();
      expect(settingsProvider.virtualKeyboardConfig.pages[0].count, equals(8));

      // Test decreasing count below maxKeysInRows constraint (Requirement 8)
      // Page 0 default rows have 7 keys. Trying to decrease count down to 6 should be blocked and show Toast
      final removeCountButton = find.byTooltip('减少每行按键数');
      await tester.tap(removeCountButton); // 8 -> 7 (allowed, max keys is 7)
      await tester.pumpAndSettle();
      expect(settingsProvider.virtualKeyboardConfig.pages[0].count, equals(7));

      await tester.tap(removeCountButton); // 7 -> 6 (blocked! row has 7 keys)
      await tester.pumpAndSettle();
      expect(settingsProvider.virtualKeyboardConfig.pages[0].count, equals(7)); // Still 7!
      expect(find.textContaining('行按钮数不能小于 7'), findsOneWidget);

      // Test Drawer: Open EndDrawer
      final drawerButton = find.byTooltip('页面管理');
      expect(drawerButton, findsOneWidget);
      await tester.tap(drawerButton);
      await tester.pumpAndSettle();

      expect(find.text('页面'), findsOneWidget);
      expect(find.text('第 1 页'), findsOneWidget);
      expect(find.text('第 2 页'), findsOneWidget);

      // Add a page from drawer (Requirement 5: 新建页面 button)
      final addPageButton = find.text('新建页面');
      await tester.tap(addPageButton);
      await tester.pumpAndSettle();

      // Drawer closed, navigated to new page 3
      expect(settingsProvider.virtualKeyboardConfig.pages.length, equals(3));
      expect(find.text('编辑区:(第 3 页)'), findsOneWidget);
      expect(find.text('页面配置'), findsOneWidget);

      // 新建页面时不再自动新增按键行，页面初始为空
      expect(settingsProvider.virtualKeyboardConfig.pages[2].keys, isEmpty);
      expect(find.text('当前页面暂无按键行'), findsOneWidget);

      // 手动添加一行（Requirement 1: 空页面由用户自行添加行）
      await tester.tap(find.text('添加新行').first);
      await tester.pumpAndSettle();
      expect(settingsProvider.virtualKeyboardConfig.pages[2].keys.length, equals(1));

      // Add a key in row 1
      final addKeyButton = find.byTooltip('添加按键').first;
      await tester.tap(addKeyButton);
      await tester.pumpAndSettle();

      // KeyEditDialog is open
      expect(find.byType(KeyEditDialog), findsOneWidget);
      expect(find.text('添加按键'), findsOneWidget);

      // Enter label & value
      await tester.enterText(find.widgetWithText(TextFormField, '显示文本'), 'TestKey');
      await tester.enterText(find.widgetWithText(TextFormField, '输入文本内容'), 'test_val');
      await tester.pumpAndSettle();

      // Tap '确定' to save key
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // Dialog closed and key is added to page 3
      expect(find.byType(KeyEditDialog), findsNothing);
      expect(settingsProvider.virtualKeyboardConfig.pages[2].keys[0].any((k) => k.label == 'TestKey'), isTrue);

      // Expand the row ExpansionTile and verify TestKey widget is rendered
      await tester.tap(find.text('1 个按键'));
      await tester.pumpAndSettle();
      expect(find.text('TestKey'), findsWidgets);

      // Tap back button to return to SettingsView
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();

      expect(find.byType(VirtualKeyboardConfigView), findsNothing);
      expect(find.byType(SettingsView), findsOneWidget);
    });

    testWidgets('VirtualKeyboardConfigView enforces row key limits and preserves expansion across page navigation', (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settingsProvider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: VirtualKeyboardConfigView(scope: KeyboardScope.editor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify row 1 has 7 keys and count is 7
      expect(settingsProvider.virtualKeyboardConfig.pages[0].count, equals(7));
      expect(settingsProvider.virtualKeyboardConfig.pages[0].keys[0].length, equals(7));

      // Attempt to add a key to row 1 (which already has 7 keys == count)
      final addKeyButton = find.byTooltip('添加按键').first;
      await tester.tap(addKeyButton);
      await tester.pumpAndSettle();

      // Toast shown, KeyEditDialog not opened
      expect(find.byType(KeyEditDialog), findsNothing);
      expect(find.textContaining('当前行按键数已达到上限'), findsOneWidget);

      // Verify ExpansionTile starts collapsed
      expect(find.text('7 个按键'), findsWidgets);

      // Tap first row ExpansionTile to expand
      await tester.tap(find.text('7 个按键').first);
      await tester.pumpAndSettle();

      // Open drawer, switch to page 2, verify expansion state isolation
      await tester.tap(find.byTooltip('页面管理'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 页'), findsOneWidget);

      await tester.tap(find.text('第 2 页'));
      await tester.pumpAndSettle();

      // On page 2, verify subtitle updated
      expect(find.text('编辑区:(第 2 页)'), findsOneWidget);

      // Switch back to page 1 via drawer, verify row 1 state persisted
      await tester.tap(find.byTooltip('页面管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 1 页'));
      await tester.pumpAndSettle();
      expect(find.text('编辑区:(第 1 页)'), findsOneWidget);

      // Test row deletion confirmation dialog
      final deleteRowButton = find.byTooltip('删除整行').first;
      await tester.tap(deleteRowButton);
      await tester.pumpAndSettle();

      expect(find.text('删除按键行'), findsOneWidget);
      expect(find.textContaining('确定要删除“第 1 行”'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('删除按键行'), findsNothing);

      // Test key deletion confirmation dialog
      final deleteKeyButton = find.byTooltip('删除按键').first;
      await tester.tap(deleteKeyButton);
      await tester.pumpAndSettle();

      expect(find.text('删除按键'), findsOneWidget);
      expect(find.textContaining('确定要删除按键'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('删除按键'), findsNothing);
    });

    testWidgets('CodeEditorWidget pinch-to-zoom adjusts font size dynamically and saves to settings', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('editor_zoom_test');
      final testFile = File('${tempDir.path}/test.dart')..writeAsStringSync('void main() {}');

      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setFontSize(14.0);

      final tabProvider = TabProvider();
      await tabProvider.init();
      tabProvider.openTabs.add(
        EditorTabItem(
          path: testFile.path,
          content: 'void main() {}',
          originalContent: 'void main() {}',
          isLoaded: true,
          isModified: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CodeEditorWidget(
                rootPath: tempDir.path,
                filePath: testFile.path,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
      expect(settingsProvider.fontSize, 14.0);

      // Simulate 2-pointer pinch gesture
      final gesture1 = await tester.createGesture();
      final gesture2 = await tester.createGesture();

      await gesture1.down(const Offset(200, 300));
      await gesture2.down(const Offset(200, 350)); // Initial distance: 50.0
      await tester.pump();

      // Move fingers apart to distance 100.0 (2x scale) -> target font size: 14 * 2 = 28.0
      await gesture2.moveTo(const Offset(200, 400));
      await tester.pump();

      // Verify pinch HUD is NOT shown (per user requirement: no font size prompt on screen)
      expect(find.text('28 pt'), findsNothing);

      // Release pointers
      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      // Verify HUD is removed and settingsProvider font size is updated to 28
      expect(find.text('28 pt'), findsNothing);
      expect(settingsProvider.fontSize, 28.0);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('CodeEditorWidget pinch-to-zoom preserves text selection and handles', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('editor_zoom_selection_test');
      final testFile = File('${tempDir.path}/test.dart')..writeAsStringSync('void main() {\n  print("hello");\n}');

      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setFontSize(14.0);

      final tabProvider = TabProvider();
      await tabProvider.init();
      tabProvider.openTabs.add(
        EditorTabItem(
          path: testFile.path,
          content: 'void main() {\n  print("hello");\n}',
          originalContent: 'void main() {\n  print("hello");\n}',
          isLoaded: true,
          isModified: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CodeEditorWidget(
                rootPath: tempDir.path,
                filePath: testFile.path,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final controller = codeEditor.controller!;

      // Select 'void' (0..4 on line 0)
      controller.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 4,
      );
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);

      // Simulate 2-pointer pinch gesture
      final gesture1 = await tester.createGesture();
      final gesture2 = await tester.createGesture();

      await gesture1.down(const Offset(200, 300));
      await gesture2.down(const Offset(200, 350));
      await tester.pump();

      await gesture2.moveTo(const Offset(200, 400));
      await tester.pump();

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      // Selection must NOT be collapsed or lost!
      expect(controller.selection.isCollapsed, isFalse);
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 4);
      expect(settingsProvider.fontSize, 28.0);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('CodeEditorWidget pinch-to-zoom anchors zoom to focal point (compensates scroll offset)', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('editor_zoom_focal_test');
      final lines = List.generate(100, (i) => 'Line $i: abcdefghijklmnopqrstuvwxyz').join('\n');
      final testFile = File('${tempDir.path}/test.dart')..writeAsStringSync(lines);

      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setFontSize(14.0);

      final tabProvider = TabProvider();
      await tabProvider.init();
      tabProvider.openTabs.add(
        EditorTabItem(
          path: testFile.path,
          content: lines,
          originalContent: lines,
          isLoaded: true,
          isModified: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: CodeEditorWidget(
                  rootPath: tempDir.path,
                  filePath: testFile.path,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final scrollController = codeEditor.scrollController!;
      final vScroller = scrollController.verticalScroller;

      expect(vScroller.offset, 0.0);

      // Simulate 2-pointer pinch gesture near the bottom of the editor viewport
      // Focal point dy = (350 + 450) / 2 = 400.0
      final gesture1 = await tester.createGesture();
      final gesture2 = await tester.createGesture();

      await gesture1.down(const Offset(200, 350));
      await gesture2.down(const Offset(200, 450)); // Initial distance: 100.0
      await tester.pump();

      // Zoom in by increasing distance to 150.0 (1.5x scale) -> target font size: 14 * 1.5 = 21.0
      // Focal point moves from 400.0 to (350 + 500) / 2 = 425.0
      // Target scrollV = (0 + 400.0) * 1.5 - 425.0 = 600.0 - 425.0 = 175.0
      await gesture2.moveTo(const Offset(200, 500));
      await tester.pump();

      // Real-time live continuous zoom updates both scroll offset and displays HUD badge
      expect(find.text('21 px'), findsOneWidget);
      expect(vScroller.offset, greaterThan(100.0));

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      // On gesture completion, font size is committed and scroll offset is compensated to anchor focal point.
      expect(settingsProvider.fontSize, 21.0);
      expect(vScroller.offset, greaterThan(100.0));
      expect(find.text('21 px'), findsNothing);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('CodeEditorWidget pinch-to-zoom out does not jump or teleport when lines scroll into or out of viewport', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('editor_zoom_out_smooth_test');
      final lines = List.generate(100, (i) => 'Line $i: const value = "test-$i";').join('\n');
      final testFile = File('${tempDir.path}/test.dart')..writeAsStringSync(lines);

      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setFontSize(20.0);

      final tabProvider = TabProvider();
      await tabProvider.init();
      tabProvider.openTabs.add(
        EditorTabItem(
          path: testFile.path,
          content: lines,
          originalContent: lines,
          isLoaded: true,
          isModified: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: CodeEditorWidget(
                  rootPath: tempDir.path,
                  filePath: testFile.path,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final scrollController = codeEditor.scrollController!;
      final vScroller = scrollController.verticalScroller;

      // Scroll down to line 20 first
      vScroller.jumpTo(300.0);
      await tester.pumpAndSettle();
      expect(vScroller.offset, 300.0);

      final gesture1 = await tester.createGesture();
      final gesture2 = await tester.createGesture();

      // Down with 2 fingers distance 200.0
      await gesture1.down(const Offset(200, 150));
      await gesture2.down(const Offset(200, 350));
      await tester.pump();

      // Zoom out gradually in multiple steps crossing multiple line boundaries
      double prevOffset = vScroller.offset;
      for (int step = 1; step <= 5; step++) {
        final newY = 350.0 - step * 15.0; // Distance decreases from 200 -> 185 -> 170 -> 155...
        await gesture2.moveTo(Offset(200, newY));
        await tester.pump();

        final currentOffset = vScroller.offset;
        // As we zoom out, text shrinks so focal anchor moves offset downward smoothly (less scroll offset needed)
        expect(currentOffset, lessThanOrEqualTo(prevOffset));
        // Ensure no sudden teleportation jump (each step moves smoothly and never jumps by a full line height reversal)
        expect(prevOffset - currentOffset, lessThan(100.0));
        prevOffset = currentOffset;
      }

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(settingsProvider.fontSize, lessThan(20.0));

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });

  // ============================================================
  // 溢出审计：在窄屏 + 大字体下渲染各主要界面，断言没有 RenderFlex 溢出
  // ============================================================
  group('Narrow layout overflow audit (320x640 @ 1.3x text)', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget app,
        {bool settle = true, double textScale = 1.3}) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(app);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: '窄屏 + ${textScale}x 字体下不应发生布局溢出');
    }

    /// 列表类界面需要滚动到底，才能让懒加载的子项全部参与布局
    Future<void> scrollAll(WidgetTester tester) async {
      for (int i = 0; i < 12; i++) {
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isEmpty) break;
        await tester.drag(scrollable.first, const Offset(0, -280), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '滚动构建列表项时不应发生布局溢出');
    }

    Widget localizedApp(Widget home, {Locale locale = const Locale('zh')}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: home,
        );

    testWidgets('MainView with a long file name', (tester) async {
      final tabProvider = TabProvider();
      await tabProvider.openFile(
        p.normalize('/workspace/a_very_long_file_name_that_stresses_the_layout.dart'),
        content: 'void main() {}',
      );

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
            ChangeNotifierProvider<ProjectProvider>.value(value: ProjectProvider()),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
          ],
          child: localizedApp(const MainView()),
        ),
        settle: false,
      );

      // 卸载以取消光标闪烁定时器
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SettingsView (zh)', (tester) async {
      await pumpNarrow(
        tester,
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: localizedApp(const SettingsView()),
        ),
      );
      await scrollAll(tester);
    });

    testWidgets('SettingsView (en)', (tester) async {
      await pumpNarrow(
        tester,
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: localizedApp(const SettingsView(), locale: const Locale('en')),
        ),
      );
      await scrollAll(tester);
    });

    testWidgets('CodeEditorAppBar with a long path', (tester) async {
      await pumpNarrow(
        tester,
        localizedApp(
          Scaffold(
            appBar: CodeEditorAppBar(
              filePath: '/workspace/deeply/nested/directory/structure/with/a/very_long_file_name.dart',
              onSettings: () {},
            ),
          ),
        ),
      );
    });

    testWidgets('CodeEditorAppBar disables run button and runTasks menu item when isDetecting is true', (tester) async {
      bool runCalled = false;
      bool runTasksCalled = false;

      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            appBar: CodeEditorAppBar(
              filePath: '/test/main.dart',
              isDetecting: true,
              onRun: () => runCalled = true,
              onRunTasks: () => runTasksCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 运行按钮 (Play) 处于禁用状态
      final playBtnFinder = find.widgetWithIcon(IconButton, Icons.play_arrow);
      expect(playBtnFinder, findsOneWidget);
      final playBtn = tester.widget<IconButton>(playBtnFinder);
      expect(playBtn.onPressed, isNull);

      // 2. 打开右上角更多菜单
      final moreBtnFinder = find.byIcon(Icons.more_vert);
      expect(moreBtnFinder, findsOneWidget);
      await tester.tap(moreBtnFinder);
      await tester.pumpAndSettle();

      // 3. 点击运行任务菜单项，验证不会触发回调
      final runTasksItemFinder = find.byIcon(Icons.playlist_play);
      expect(runTasksItemFinder, findsOneWidget);
      await tester.tap(runTasksItemFinder);
      await tester.pumpAndSettle();
      expect(runTasksCalled, isFalse);
      expect(runCalled, isFalse);
    });

    testWidgets('VirtualKeyboardConfigView', (tester) async {
      await pumpNarrow(
        tester,
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: localizedApp(const VirtualKeyboardConfigView(scope: KeyboardScope.editor)),
        ),
      );
      await scrollAll(tester);
    });

    testWidgets('KeyEditDialog (editor + terminal scope)', (tester) async {
      await pumpNarrow(
        tester,
        localizedApp(const Scaffold(body: KeyEditDialog(scope: KeyboardScope.editor))),
      );
      await pumpNarrow(
        tester,
        localizedApp(const Scaffold(body: KeyEditDialog(scope: KeyboardScope.terminal))),
      );
    });

    testWidgets('VirtualKeyboardPageDrawer', (tester) async {
      await pumpNarrow(
        tester,
        localizedApp(
          Scaffold(
            body: VirtualKeyboardPageDrawer(
              pages: const [
                KeyboardPageItem(count: 7, keys: []),
                KeyboardPageItem(count: 12, keys: []),
              ],
              currentPageIndex: 0,
              onAddNewPage: () {},
              onSelectPage: (_) {},
              onDeletePage: (_) {},
              onReorderPages: (_, _) {},
            ),
          ),
        ),
      );
    });

    testWidgets('CodeEditorDrawer with a long project path', (tester) async {
      final projectProvider = ProjectProvider();
      projectProvider.setHistoryForTesting(const ProjectHistory(
        rootPath: '/workspace/a_very_long_project_directory_name_for_layout_stress',
        lastOpenedFilePath: null,
      ));

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: TabProvider()),
          ],
          child: localizedApp(
            const Scaffold(
              drawer: CodeEditorDrawer(),
              body: Center(child: Text('Home')),
            ),
          ),
        ),
      );

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '抽屉展开后不应溢出');
    });

    testWidgets('FileItemWidget with a very long file name', (tester) async {
      final fileItem = FileItem(
        path: '/workspace/this_is_an_extremely_long_file_name_that_would_never_fit_on_screen.dart',
        name: 'this_is_an_extremely_long_file_name_that_would_never_fit_on_screen.dart',
        isDirectory: false,
      );

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: ProjectProvider()),
            ChangeNotifierProvider<TabProvider>.value(value: TabProvider()),
          ],
          child: localizedApp(Scaffold(body: FileItemWidget(fileItem: fileItem))),
        ),
      );
    });

    testWidgets('TerminalSessionItemWidget with a long custom system name', (tester) async {
      final session = TerminalSession(
        id: 'session-1',
        name: 'a_very_long_session_name_that_could_overflow_the_row',
        distroId: 'a_very_long_custom_system_name_imported_by_the_user',
      );

      await pumpNarrow(
        tester,
        ChangeNotifierProvider<TerminalProvider>.value(
          value: TerminalProvider(),
          child: localizedApp(
            Scaffold(
              body: TerminalSessionItemWidget(session: session, index: 0, isSelected: false),
            ),
          ),
        ),
      );
    });

    testWidgets('VirtualKeyboardConfigView (en, 1.5x)', (tester) async {
      await pumpNarrow(
        tester,
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: localizedApp(const VirtualKeyboardConfigView(scope: KeyboardScope.editor), locale: const Locale('en')),
        ),
        textScale: 1.5,
      );
      await scrollAll(tester);
    });

    testWidgets('MainView overflow menu (en)', (tester) async {
      final tabProvider = TabProvider();
      await tabProvider.openFile(p.normalize('/ws/a.dart'), content: 'void main() {}');

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
            ChangeNotifierProvider<ProjectProvider>.value(value: ProjectProvider()),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
          ],
          child: localizedApp(const MainView(), locale: const Locale('en')),
        ),
        settle: false,
      );

      // 展开右上角“更多”菜单（此前未被任何窄屏测试覆盖）
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '更多菜单展开后不应溢出');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CodeEditorTabBar with many modified tabs', (tester) async {
      final tabProvider = TabProvider();
      for (int i = 0; i < 12; i++) {
        await tabProvider.openFile(p.normalize('/ws/some_long_file_name_$i.dart'), content: 'x');
        tabProvider.updateActiveTabContent('modified_$i', isModified: true);
      }

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: ProjectProvider()),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
          ],
          child: localizedApp(const Scaffold(body: CodeEditorTabBar())),
        ),
      );
    });

    testWidgets('CodeEditorDrawer header at 2x text', (tester) async {
      final projectProvider = ProjectProvider();
      projectProvider.setHistoryForTesting(const ProjectHistory(
        rootPath: '/workspace/demo_app',
        lastOpenedFilePath: null,
      ));

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: TabProvider()),
          ],
          child: localizedApp(
            const Scaffold(
              drawer: CodeEditorDrawer(),
              body: Center(child: Text('Home')),
            ),
          ),
        ),
        textScale: 2.0,
      );

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '抽屉展开后不应溢出');
    });

    testWidgets('VirtualKeyboardConfigView (terminal, en, 1.5x)', (tester) async {
      await pumpNarrow(
        tester,
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: localizedApp(
            const VirtualKeyboardConfigView(scope: KeyboardScope.terminal),
            locale: const Locale('en'),
          ),
        ),
        textScale: 1.5,
      );
      await scrollAll(tester);
    });

    testWidgets('KeyEditDialog (terminal) with special key dropdown and modifier controls', (tester) async {
      await pumpNarrow(
        tester,
        localizedApp(
          const Scaffold(body: KeyEditDialog(scope: KeyboardScope.terminal)),
          locale: const Locale('en'),
        ),
      );

      // 切到“特殊键”动作：下拉 + 下方三个修饰键控件
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Special Key').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '特殊键表单不应溢出');
      expect(find.widgetWithText(FilterChip, 'Ctrl Key'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Alt Key'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Shift Key'), findsOneWidget);

      // 展开分组键下拉（分组标题 + 字母键）
      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '特殊键下拉不应溢出');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // 切回“指令快捷键”：出现自动回车开关
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Command Shortcut').last);
      await tester.pumpAndSettle();
      expect(find.text('Send Enter after'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '指令快捷键表单不应溢出');
    });

    testWidgets('ProjectHistoryWidget with a long path', (tester) async {
      final projectProvider = ProjectProvider();
      projectProvider.setHistoryForTesting(const ProjectHistory(
        rootPath: '/workspace/a_very_long_project_directory_name_for_layout_stress',
        lastOpenedFilePath: null,
      ));

      await pumpNarrow(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: TabProvider()),
          ],
          child: localizedApp(const Scaffold(body: ProjectHistoryWidget())),
        ),
      );
      await scrollAll(tester);
    });
  });

  // ============================================================
  // 字体选择弹窗的 l10n：字体显示名不应硬编码在 models 里
  // ============================================================
  group('Font selector l10n', () {
    test('every font id has a localized display name', () {
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();
      final allFonts = <AppFontItem>{
        ...AppFonts.uiFonts,
        ...AppFonts.editorFonts,
        ...AppFonts.terminalFonts,
      };

      for (final font in allFonts) {
        // 未在 ARB 的 select 中登记时会回退成原始 id，这里据此兜底校验
        expect(zh.fontName(font.id), isNot(font.id), reason: 'zh 缺少字体名称: ${font.id}');
        expect(en.fontName(font.id), isNot(font.id), reason: 'en 缺少字体名称: ${font.id}');
      }
    });

    testWidgets('font selector sheet follows the locale', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 界面字体选择弹窗
      await tester.scrollUntilVisible(find.text('Interface Font'), 200);
      await tester.tap(find.text('Interface Font'));
      await tester.pumpAndSettle();

      expect(find.text('System Default'), findsWidgets);
      expect(find.text('Sans-Serif'), findsWidgets);
      expect(find.text('Serif (Songti)'), findsWidgets);
      expect(find.text('JetBrains Mono'), findsWidgets);
      // 不再出现硬编码中文
      expect(find.textContaining('系统'), findsNothing);
      expect(find.textContaining('推荐'), findsNothing);
      expect(find.textContaining('宋体'), findsNothing);

      // 关闭弹窗后打开代码字体选择弹窗
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Code Font'), 200);
      await tester.tap(find.text('Code Font'));
      await tester.pumpAndSettle();

      expect(find.text('System Monospace'), findsWidgets);
      expect(find.text('JetBrains Mono (Recommended)'), findsWidgets);
    });
  });

  group('Editor Line Numbers Settings', () {
    test('SettingsProvider line numbers defaults, setters, and persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();

      // Defaults
      expect(provider.showLineNumbers, isTrue);
      expect(provider.pinLineNumbers, isFalse);

      // Setters
      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setShowLineNumbers(false);
      expect(provider.showLineNumbers, isFalse);
      expect(notified, isTrue);

      notified = false;
      await provider.setPinLineNumbers(true);
      expect(provider.pinLineNumbers, isTrue);
      expect(notified, isTrue);

      // Verify loaded from SharedPreferences
      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.showLineNumbers, isFalse);
      expect(provider2.pinLineNumbers, isTrue);
    });

    test('Localization strings exist in both zh and en without hardcoding', () {
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();

      expect(zh.showLineNumbers, '显示行号');
      expect(zh.showLineNumbersSubtitle, '在代码左侧显示行号与折叠标记');
      expect(zh.pinLineNumbers, '固定行号');
      expect(zh.pinLineNumbersSubtitle, '水平滚动代码时行号固定在左侧');

      expect(en.showLineNumbers, 'Show Line Numbers');
      expect(en.showLineNumbersSubtitle, 'Display line numbers and code folding markers on the left');
      expect(en.pinLineNumbers, 'Pin Line Numbers');
      expect(en.pinLineNumbersSubtitle, 'Keep line numbers pinned to the left during horizontal scroll');
    });

    testWidgets('SettingsView displays line numbers tiles and disables pin when show is false', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: provider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('显示行号'), findsOneWidget);
      expect(find.text('在代码左侧显示行号与折叠标记'), findsOneWidget);
      expect(find.text('固定行号'), findsOneWidget);
      expect(find.text('水平滚动代码时行号固定在左侧'), findsOneWidget);

      // showSwitch should be true, pinSwitch should initially be enabled and false
      final switchesBefore = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      final showSwitchBefore = switchesBefore.firstWhere((s) => (s.title as Text).data == '显示行号');
      final pinSwitchBefore = switchesBefore.firstWhere((s) => (s.title as Text).data == '固定行号');
      expect(showSwitchBefore.value, isTrue);
      expect(showSwitchBefore.onChanged, isNotNull);
      expect(pinSwitchBefore.value, isFalse);
      expect(pinSwitchBefore.onChanged, isNotNull);

      // Turn off showLineNumbers
      await tester.tap(find.text('显示行号'));
      await tester.pumpAndSettle();

      expect(provider.showLineNumbers, isFalse);

      // Now pinLineNumbers should be disabled (onChanged == null)
      final switchesAfter = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      final pinSwitchAfter = switchesAfter.firstWhere((s) => (s.title as Text).data == '固定行号');
      expect(pinSwitchAfter.onChanged, isNull);

      // Tapping disabled pinLineNumbers does nothing
      await tester.tap(find.text('固定行号'));
      await tester.pumpAndSettle();
      expect(provider.pinLineNumbers, isFalse); // unchanged

      // Re-enabling showLineNumbers re-enables pinLineNumbers
      await tester.tap(find.text('显示行号'));
      await tester.pumpAndSettle();
      expect(provider.showLineNumbers, isTrue);

      final switchesReenabled = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      final pinSwitchReenabled = switchesReenabled.firstWhere((s) => (s.title as Text).data == '固定行号');
      expect(pinSwitchReenabled.onChanged, isNotNull);
    });

    testWidgets('CodeEditor renders without line numbers when indicatorBuilder is null', (tester) async {
      final controller = CodeLineEditingController.fromText('const x = 1;\nconst y = 2;');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 400,
              child: CodeEditor(
                controller: controller,
                wordWrap: false,
                pinLineNumbers: true,
                indicatorBuilder: null,
                leadingDivider: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
      expect(find.byType(DefaultCodeLineNumber), findsNothing);
    });

    testWidgets('CodeEditor with pinLineNumbers: false scrolls line numbers horizontally', (tester) async {
      final longText = 'const aLongVariableNameThatIsVeryLong = 1234567890 + 987654321;';
      final controller = CodeLineEditingController.fromText('$longText\nline2');
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: CodeEditor(
                controller: controller,
                scrollController: scrollController,
                wordWrap: false,
                pinLineNumbers: false,
                leadingDivider: const SizedBox(width: 1.0),
                indicatorBuilder: (context, c, ch, n) {
                  return DefaultCodeLineNumber(
                    controller: c,
                    notifier: n,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
      expect(find.byType(DefaultCodeLineNumber), findsOneWidget);

      // Initially at offset 0
      expect(scrollController.horizontalScroller.offset, 0.0);

      // Scroll horizontally
      scrollController.horizontalScroller.jumpTo(50.0);
      await tester.pumpAndSettle();

      expect(scrollController.horizontalScroller.offset, 50.0);
    });

    testWidgets('CodeEditor continuous bidirectional gesture scrolls horizontally then vertically without lifting finger', (tester) async {
      final text = List.generate(50, (i) => 'Line $i: const aLongVariableNameThatIsVeryLong = 1234567890 + 987654321;').join('\n');
      final controller = CodeLineEditingController.fromText(text);
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: CodeEditor(
                controller: controller,
                scrollController: scrollController,
                wordWrap: false,
                pinLineNumbers: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(scrollController.horizontalScroller.offset, 0.0);
      expect(scrollController.verticalScroller.offset, 0.0);

      // Start drag gesture with touch
      final gesture = await tester.startGesture(const Offset(200, 200), kind: PointerDeviceKind.touch);
      // Exceed touch slop to trigger onStart
      await gesture.moveBy(const Offset(-30, 0));
      // Subsequent movement triggers onUpdate
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();

      expect(scrollController.horizontalScroller.offset, greaterThan(0.0));
      final hOffsetAfterHorizontal = scrollController.horizontalScroller.offset;

      // Now scroll vertically without lifting finger
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      expect(scrollController.verticalScroller.offset, greaterThan(0.0));
      // Horizontal offset should still be preserved
      expect(scrollController.horizontalScroller.offset, closeTo(hOffsetAfterHorizontal, 1.0));

      // Diagonal movement scrolls both
      await gesture.moveBy(const Offset(-30, -30));
      await tester.pump();

      expect(scrollController.horizontalScroller.offset, greaterThan(hOffsetAfterHorizontal));
      expect(scrollController.verticalScroller.offset, greaterThan(50.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}





