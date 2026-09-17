import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('drawer_tab_test_');
    testProjectDir = Directory(p.join(tempBaseDir.path, 'my_project'))..createSync();

    InternalProjectService.instance.customProjectsDir =
        Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    runProvider = RunProvider();

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

  Widget buildTestWidget({Locale locale = const Locale('zh')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<RunProvider>.value(value: runProvider),
      ],
      child: MaterialApp(
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
        home: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Editor Body')),
        ),
      ),
    );
  }

  testWidgets('Activity Bar renders 3 vertical tab buttons and switches pages correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('zh')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // 1. Initial state: Explorer is active
    expect(find.byIcon(Icons.folder_copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.alt_route_rounded), findsOneWidget);

    // Initial page shows file tree and directory title ("项目")
    expect(find.byType(FileTreeWidget), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);

    // Tooltips
    expect(find.byTooltip('文件'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.byTooltip('源代码管理'), findsOneWidget);

    // 2. Tap Search tab
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    // IndexedStack index is 1 -> Search page header is visible
    final searchHeader = find.text('搜索');
    expect(searchHeader, findsWidgets); // tooltip & header title

    // 3. Tap Git tab
    await tester.tap(find.byTooltip('源代码管理'));
    await tester.pumpAndSettle();

    // Git header is visible
    final gitHeader = find.text('源代码管理');
    expect(gitHeader, findsWidgets); // tooltip & header title

    // 4. Tap back to Explorer
    await tester.tap(find.byTooltip('文件'));
    await tester.pumpAndSettle();

    expect(find.byType(FileTreeWidget), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);
  });

  testWidgets('Activity Bar tooltips follow English locale', (tester) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Explorer'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Source Control'), findsOneWidget);
  });
}
