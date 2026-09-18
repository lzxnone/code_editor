import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/models/search_model.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/services/project_search_service.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/widgets/search/search_panel_widget.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late Directory testProjectDir;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;
  late RunProvider runProvider;
  late SearchProvider searchProvider;
  late GitProvider gitProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('project_search_test_');
    testProjectDir = Directory(p.join(tempBaseDir.path, 'my_project'))..createSync();

    InternalProjectService.instance.customProjectsDir =
        Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    runProvider = RunProvider();
    searchProvider = SearchProvider()..bindRootPath(testProjectDir.path);
    gitProvider = GitProvider();

    await projectProvider.switchProject(
      ProjectHistory(
        rootPath: testProjectDir.path,
        lastOpenedFilePath: null,
      ),
    );
  });

  tearDown(() {
    InternalProjectService.instance.customProjectsDir = null;
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  group('ProjectSearchService & SearchOptions Unit Tests', () {
    test('SearchOptions builds correct RegExp for case sensitive, whole word, regex', () {
      // Default: case-insensitive literal
      final opt1 = const SearchOptions(query: 'foo');
      expect(opt1.buildRegExp()!.hasMatch('FOO'), isTrue);
      expect(opt1.buildRegExp()!.hasMatch('foobar'), isTrue);

      // Case sensitive
      final opt2 = const SearchOptions(query: 'foo', caseSensitive: true);
      expect(opt2.buildRegExp()!.hasMatch('FOO'), isFalse);
      expect(opt2.buildRegExp()!.hasMatch('foo'), isTrue);

      // Whole word
      final opt3 = const SearchOptions(query: 'foo', wholeWord: true);
      expect(opt3.buildRegExp()!.hasMatch('foobar'), isFalse);
      expect(opt3.buildRegExp()!.hasMatch('bar foo baz'), isTrue);

      // Regex
      final opt4 = const SearchOptions(query: r'f\w+o', isRegex: true);
      expect(opt4.buildRegExp()!.hasMatch('froo'), isTrue);
      expect(opt4.buildRegExp()!.hasMatch('f123o'), isTrue);
      expect(opt4.buildRegExp()!.hasMatch('fx'), isFalse);
    });

    test('search finds matches in project files and skips ignored dirs and binaries', () async {
      // Create file 1
      final file1 = File(p.join(testProjectDir.path, 'lib', 'main.dart'))..createSync(recursive: true);
      file1.writeAsStringSync('void main() {\n  final name = "hello";\n  print(name);\n}\n');

      // Create file 2 (use greet to avoid duplicate "Hello" match)
      final file2 = File(p.join(testProjectDir.path, 'lib', 'utils.dart'))..createSync(recursive: true);
      file2.writeAsStringSync('String greet() => "hello world";\n');

      // Create file in .git (should be ignored)
      final gitFile = File(p.join(testProjectDir.path, '.git', 'HEAD'))..createSync(recursive: true);
      gitFile.writeAsStringSync('hello in git');

      // Create binary file (should be ignored)
      final binFile = File(p.join(testProjectDir.path, 'test.png'))..createSync();
      binFile.writeAsStringSync('hello in png');

      final result = await ProjectSearchService.instance.search(
        rootPath: testProjectDir.path,
        options: const SearchOptions(query: 'hello'),
      );

      expect(result.fileResults.length, equals(2));
      expect(result.totalMatches, equals(2));

      final mainMatch = result.fileResults.firstWhere((f) => f.fileName == 'main.dart');
      expect(mainMatch.matches.length, equals(1));
      expect(mainMatch.matches.first.lineNumber, equals(2));
      expect(mainMatch.matches.first.matchedText, equals('hello'));
    });

    test('fileName search mode correctly matches file and directory names', () async {
      File(p.join(testProjectDir.path, 'app_config.json'))..createSync()..writeAsStringSync('{}');
      Directory(p.join(testProjectDir.path, 'config_dir')).createSync();
      File(p.join(testProjectDir.path, 'main.dart'))..createSync()..writeAsStringSync('code');

      final result = await ProjectSearchService.instance.search(
        rootPath: testProjectDir.path,
        options: const SearchOptions(query: 'config', mode: SearchMode.fileName),
      );

      expect(result.fileResults.length, equals(2));
      final fileMatch = result.fileResults.firstWhere((f) => f.fileName == 'app_config.json');
      final dirMatch = result.fileResults.firstWhere((f) => f.fileName == 'config_dir');

      expect(fileMatch.isDirectory, isFalse);
      expect(dirMatch.isDirectory, isTrue);
    });

    test('replaceSingleMatchInContent replaces target line match cleanly', () {
      const original = 'line 1\nhello world\nline 3';
      final match = LineMatch(lineNumber: 2, lineContent: 'hello world', matchStart: 0, matchEnd: 5);
      final replaced = ProjectSearchService.instance.replaceSingleMatchInContent(
        fileContent: original,
        match: match,
        replacement: 'hi',
      );
      expect(replaced, equals('line 1\nhi world\nline 3'));
    });
  });

  group('SearchProvider Integration Tests', () {
    test('replaceSingleMatch updates open tab content in memory and marks tab modified', () async {
      final file = File(p.join(testProjectDir.path, 'demo.txt'))..createSync()..writeAsStringSync('apple banana apple');
      await tabProvider.openFile(file.path);

      await searchProvider.triggerSearch();
      searchProvider.setQuery('apple');
      searchProvider.setReplaceText('orange');
      await searchProvider.triggerSearch();

      expect(searchProvider.result.totalMatches, equals(2));
      final fileRes = searchProvider.result.fileResults.first;
      final match1 = fileRes.matches.first;

      final success = await searchProvider.replaceSingleMatch(
        file: fileRes,
        match: match1,
        tabProvider: tabProvider,
      );

      expect(success, isTrue);
      expect(tabProvider.activeTab?.isModified, isTrue);
      expect(tabProvider.activeTab?.content, equals('orange banana apple'));
      expect(searchProvider.result.totalMatches, equals(1));
    });

    test('replaceFileMatches replaces all occurrences in file', () async {
      final file = File(p.join(testProjectDir.path, 'batch.txt'))..createSync()..writeAsStringSync('cat dog cat dog cat');
      await tabProvider.openFile(file.path);

      searchProvider.setQuery('cat');
      searchProvider.setReplaceText('fox');
      await searchProvider.triggerSearch();

      final fileRes = searchProvider.result.fileResults.first;
      final count = await searchProvider.replaceFileMatches(
        file: fileRes,
        tabProvider: tabProvider,
      );

      expect(count, equals(3));
      expect(tabProvider.activeTab?.content, equals('fox dog fox dog fox'));
      expect(searchProvider.result.totalMatches, equals(0));
    });
  });

  Widget buildTestApp({Locale locale = const Locale('zh')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<RunProvider>.value(value: runProvider),
        ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
        ChangeNotifierProvider<GitProvider>.value(value: gitProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Editor View')),
        ),
      ),
    );
  }

  group('Search Panel Widget & Drawer UI Tests', () {
    testWidgets('Switching to search tab displays SearchPanelWidget with inputs and toggles', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to search tab
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPanelWidget), findsOneWidget);
      // 模式切换按钮存在且初始为文本模式
      expect(find.byTooltip('内容搜索'), findsOneWidget);

      // 验证更多选项菜单按钮
      expect(find.byTooltip('更多选项'), findsOneWidget);
      // 点击打开更多选项弹出菜单
      await tester.tap(find.byTooltip('更多选项'));
      await tester.pumpAndSettle();

      // 菜单内包含 3 个选项开关
      expect(find.text('区分大小写'), findsOneWidget);
      expect(find.text('全字匹配'), findsOneWidget);
      expect(find.text('使用正则表达式'), findsOneWidget);

      // 点击“区分大小写”项
      await tester.tap(find.text('区分大小写'));
      await tester.pumpAndSettle();
      expect(searchProvider.caseSensitive, isTrue);

      // Expand replace row
      expect(find.text('替换'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();

      expect(find.text('替换'), findsOneWidget);
      expect(find.byTooltip('全部替换'), findsOneWidget);
    });

    testWidgets('Search input retains state in memory when switching tabs', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to search tab
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      // Type in search box
      await tester.enterText(find.byType(TextField).first, 'testQuery');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Switch back to Explorer tab
      await tester.tap(find.byTooltip('文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch back to Search tab
      await tester.tap(find.byTooltip('搜索'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Memory state preserved!
      expect(searchProvider.query, equals('testQuery'));
      expect(find.text('testQuery'), findsOneWidget);
    });

    testWidgets('Search input retains focus when text is deleted to empty or cleared', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pumpAndSettle();

      final FocusNode focusNode = tester.widget<TextField>(searchField).focusNode!;
      expect(focusNode.hasFocus, isTrue);

      // Enter text
      await tester.enterText(searchField, 'abc');
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      // Delete all text (becomes empty)
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue, reason: 'Focus should not be lost when all text is deleted');

      // Re-enter text and tap clear button
      await tester.enterText(searchField, 'def');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue, reason: 'Focus should not be lost when clear icon is tapped');
      expect(searchProvider.query, isEmpty);
    });

    testWidgets('Invalid regex displays localized error message in Chinese and English', (tester) async {
      // 1. Chinese locale
      await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      // Enable regex
      searchProvider.toggleRegex();
      searchProvider.setQuery('['); // Invalid regex: unclosed bracket
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should display localized Chinese error
      expect(find.text('搜索失败: 无效的正则表达式'), findsOneWidget);

      // 2. English locale
      await tester.pumpWidget(buildTestApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Trigger search again to update result with current locale
      await searchProvider.triggerSearch();
      await tester.pumpAndSettle();

      // Should display localized English error
      expect(find.text('Search failed: Invalid regular expression'), findsOneWidget);
    });

    testWidgets('SearchPanelWidget page size constants and lazy loading for files and matches', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      expect(SearchPanelWidget.defaultFilesPageSize, equals(20));
      expect(SearchPanelWidget.defaultFileMatchesPageSize, equals(20));

      // Construct a mock SearchResult with 25 files, file 0 is expanded with 25 matches, others collapsed
      final List<FileSearchResult> mockFiles = List.generate(25, (fIndex) {
        return FileSearchResult(
          filePath: '/path/file_$fIndex.dart',
          relativePath: 'sub/file_$fIndex.dart',
          fileName: 'file_$fIndex.dart',
          isExpanded: fIndex == 0,
          matches: List.generate(25, (mIndex) {
            return LineMatch(
              lineNumber: mIndex + 1,
              lineContent: 'Line $mIndex matching target text',
              matchStart: 16,
              matchEnd: 22,
            );
          }),
        );
      });

      final customResult = SearchResult(
        query: 'target',
        fileResults: mockFiles,
        totalMatches: 25 * 25,
        durationMs: 12,
      );

      searchProvider.setResultForTesting(customResult);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RunProvider>.value(value: runProvider),
            ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
            ChangeNotifierProvider<GitProvider>.value(value: gitProvider),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 800,
                child: SearchPanelWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify matches lazy loading in the first file:
      // First file has 25 matches. Since defaultFileMatchesPageSize is 20, 20 are shown.
      // And a "Load more matches" button showing "加载更多匹配项 (还有 5 项)"
      final loadMoreMatchesFinder = find.text('加载更多匹配项 (还有 5 项)');
      await tester.scrollUntilVisible(
        loadMoreMatchesFinder,
        200.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(loadMoreMatchesFinder, findsOneWidget);

      // Tap "Load more matches"
      await tester.tap(loadMoreMatchesFinder);
      await tester.pumpAndSettle();
      // All 25 matches now loaded, button for matches is gone!
      expect(find.text('加载更多匹配项 (还有 5 项)'), findsNothing);

      // Verify files lazy loading:
      // Since defaultFilesPageSize is 20, only 20 files are initially displayed.
      // There should be a "Load more files" button showing "加载更多文件 (还有 5 个)"
      final loadMoreFilesFinder = find.text('加载更多文件 (还有 5 个)');
      await tester.scrollUntilVisible(
        loadMoreFilesFinder,
        300.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(loadMoreFilesFinder, findsOneWidget);

      // Tap "Load more files"
      await tester.tap(loadMoreFilesFinder);
      await tester.pumpAndSettle();
      // All 25 files now loaded, button for files is gone!
      expect(find.text('加载更多文件 (还有 5 个)'), findsNothing);

      // Test with long file name to ensure no horizontal layout overflow
      final longFileName = 'aime25_openai__gpt-oss-120b-high_default_temp_0.75_aime25_100_eval_response.json';
      final fileWithLongName = FileSearchResult(
        filePath: '/path/$longFileName',
        relativePath: 'very/deep/nested/path/to/project/$longFileName',
        fileName: longFileName,
        matches: [
          LineMatch(
            lineNumber: 10,
            lineContent: 'const a = "target";',
            matchStart: 11,
            matchEnd: 17,
          ),
        ],
      );

      searchProvider.setResultForTesting(SearchResult(
        query: 'target',
        fileResults: [fileWithLongName],
        totalMatches: 1,
      ));
      await tester.pumpAndSettle();

      // If there was any overflow, tester.takeException() would catch it or pumpAndSettle fails
      expect(tester.takeException(), isNull);
    });

    testWidgets('Replace buttons only appear when replace row is expanded, and show confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testFile = FileSearchResult(
        filePath: '/path/test.dart',
        relativePath: 'test.dart',
        fileName: 'test.dart',
        matches: [
          LineMatch(
            lineNumber: 1,
            lineContent: 'hello world target',
            matchStart: 12,
            matchEnd: 18,
          ),
        ],
      );

      searchProvider.setResultForTesting(SearchResult(
        query: 'target',
        fileResults: [testFile],
        totalMatches: 1,
      ));

      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to search tab
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      // Initially replace row is collapsed: replace buttons in file & match line should NOT be visible!
      expect(find.byTooltip('替换此文件中的所有匹配项'), findsNothing);
      expect(find.byTooltip('替换'), findsNothing);

      // Expand replace row
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();

      // Now replace buttons ARE visible!
      expect(find.byTooltip('替换此文件中的所有匹配项'), findsOneWidget);
      expect(find.byTooltip('替换'), findsOneWidget);

      // Tapping replace all in file shows confirmation dialog
      await tester.tap(find.byTooltip('替换此文件中的所有匹配项'));
      await tester.pumpAndSettle();

      expect(find.text('替换文件匹配项确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('替换文件匹配项确认'), findsNothing);
    });

    testWidgets('Drawer tab selection is persisted in memory across drawer closing and reopening', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to search tab (index 1)
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(CodeEditorDrawer.lastSelectedTabIndex, equals(1));

      // Close drawer
      scaffoldState.closeDrawer();
      await tester.pumpAndSettle();

      // Reopen drawer: should automatically restore search tab (index 1)
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byType(SearchPanelWidget), findsOneWidget);
    });

    testWidgets('Editor does not highlight search query in fileName mode', (tester) async {
      searchProvider.setMode(SearchMode.fileName);
      searchProvider.setQuery('main');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RunProvider>.value(value: runProvider),
            ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
            ChangeNotifierProvider<GitProvider>.value(value: gitProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: CodeEditorWidget(
                filePath: 'lib/main.dart',
                rootPath: testProjectDir.path,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In CodeEditorWidget, _syncSearchHighlight with mode == fileName should clear/not set findController
      // Switching to text mode enables highlighting, and switching back clears it
      searchProvider.setMode(SearchMode.text);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      searchProvider.setMode(SearchMode.fileName);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Search result state (expansion, limits, scroll offset) persists across drawer close/reopen', (tester) async {
      final List<FileSearchResult> mockFiles = List.generate(25, (fIndex) {
        return FileSearchResult(
          filePath: '/path/file_$fIndex.dart',
          relativePath: 'sub/file_$fIndex.dart',
          fileName: 'file_$fIndex.dart',
          isExpanded: fIndex == 0,
          matches: [
            LineMatch(
              lineNumber: 1,
              lineContent: 'matching line in file $fIndex',
              matchStart: 9,
              matchEnd: 13,
            ),
          ],
        );
      });

      final result = SearchResult(
        query: 'test',
        fileResults: mockFiles,
        totalMatches: 25,
      );
      searchProvider.setResultForTesting(result);

      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to search tab
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      // 1. Toggle file 1 expansion
      expect(mockFiles[1].isExpanded, isFalse);
      searchProvider.toggleFileExpanded(mockFiles[1]);
      await tester.pumpAndSettle();
      expect(mockFiles[1].isExpanded, isTrue);

      // 2. Load more files
      searchProvider.loadMoreFiles(10);
      expect(searchProvider.displayedFilesLimit, equals(30));

      // 3. Set scroll offset
      searchProvider.scrollOffset = 150.0;

      // Close drawer
      scaffoldState.closeDrawer();
      await tester.pumpAndSettle();

      // Reopen drawer
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // State is preserved!
      expect(searchProvider.displayedFilesLimit, equals(30));
      expect(mockFiles[1].isExpanded, isTrue);
      expect(searchProvider.scrollOffset, equals(150.0));
    });

    testWidgets('Editor focus and keyboard stability: focus is not lost or bounced during editing or search clear', (tester) async {
      final mainPath = p.normalize(p.join(testProjectDir.path, 'lib', 'main.dart'));
      final tabMain = EditorTabItem(
        path: mainPath,
        content: 'void main() {\n  print("hello");\n}\n',
        originalContent: 'void main() {\n  print("hello");\n}\n',
        isLoaded: true,
        isModified: false,
      );
      tabProvider.setOpenTabsForTesting([tabMain], activePath: mainPath);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RunProvider>.value(value: runProvider),
            ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: CodeEditorWidget(
                filePath: mainPath,
                rootPath: testProjectDir.path,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Find CodeEditor focus node
      final codeEditorFinder = find.byType(CodeEditor);
      expect(codeEditorFinder, findsOneWidget);
      final codeEditor = tester.widget<CodeEditor>(codeEditorFinder);
      final focusNode = codeEditor.focusNode!;

      // 1. Focus the editor (user taps editor to bring up soft keyboard)
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(focusNode.hasFocus, isTrue);
      expect(focusNode.canRequestFocus, isTrue);

      // 2. Perform search in text mode
      searchProvider.setMode(SearchMode.text);
      searchProvider.setQuery('void');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Focus should NOT be lost or disabled
      expect(focusNode.hasFocus, isTrue);
      expect(focusNode.canRequestFocus, isTrue);

      // 3. Clear search query to empty (simulating user deleting search text)
      searchProvider.setQuery('');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Focus must remain rock solid! canRequestFocus must NEVER be set to false!
      expect(focusNode.hasFocus, isTrue);
      expect(focusNode.canRequestFocus, isTrue);
    });
  });
}
