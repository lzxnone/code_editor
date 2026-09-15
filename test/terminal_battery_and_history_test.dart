import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/services/permission_service.dart';
import 'package:code_editor/services/project_history_service.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/project_history_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late InternalProjectService projectService;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;
  late TerminalProvider terminalProvider;
  late DistroProvider distroProvider;
  late RunProvider runProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('term_batt_test_');
    projectService = InternalProjectService.instance;
    projectService.customProjectsDir = Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    terminalProvider = TerminalProvider();
    distroProvider = DistroProvider();
    runProvider = RunProvider();
  });

  tearDown(() {
    projectService.customProjectsDir = null;
    if (tempBaseDir.existsSync()) {
      try {
        tempBaseDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Widget buildTestApp({required Widget child, Locale locale = const Locale('zh')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
        ChangeNotifierProvider<DistroProvider>.value(value: distroProvider),
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
        home: child,
      ),
    );
  }

  group('ProjectHistoryWidget 内部与外部项目展示测试', () {
    testWidgets('内部项目副标题显示项目名称，外部项目副标题显示绝对路径', (tester) async {
      // 创建一个内部项目路径
      final internalProjectsDir = projectService.customProjectsDir!;
      final internalDir = Directory(p.join(internalProjectsDir.path, 'my_internal_app'))..createSync(recursive: true);
      final internalFile = File(p.join(internalDir.path, 'lib', 'main.dart'))..createSync(recursive: true);

      // 创建一个外部项目路径
      final externalDir = Directory(p.join(tempBaseDir.path, 'outside', 'external_proj'))..createSync(recursive: true);
      final externalFile = File(p.join(externalDir.path, 'app.py'))..createSync(recursive: true);

      // 录入历史
      await ProjectHistoryService.instance.recordHistory(
        rootPath: internalDir.path,
        lastOpenedFilePath: internalFile.path,
      );
      await ProjectHistoryService.instance.recordHistory(
        rootPath: externalDir.path,
        lastOpenedFilePath: externalFile.path,
      );

      await tester.pumpWidget(buildTestApp(
        child: const Scaffold(
          body: ProjectHistoryWidget(),
        ),
      ));
      await tester.pumpAndSettle();

      // 验证内部项目：显示项目名 "my_internal_app"，而不显示绝对路径
      expect(find.text('my_internal_app'), findsOneWidget);
      expect(find.text(internalDir.path), findsNothing);

      // 验证外部项目：显示完整绝对路径
      expect(find.text(externalDir.path), findsOneWidget);
    });
  });

  group('TerminalView AppBar 副标题展示测试', () {
    testWidgets('内部项目工作区副标题显示项目名，外部项目工作区副标题显示完整路径', (tester) async {
      final internalProjectsDir = projectService.customProjectsDir!;
      final internalDir = Directory(p.join(internalProjectsDir.path, 'term_internal_proj'))..createSync(recursive: true);

      // 会话 1：绑定内部项目工作区
      terminalProvider.createSession(
        name: '会话1',
        distroId: 'ubuntu',
        workspacePath: internalDir.path,
        activate: true,
      );

      await tester.pumpWidget(buildTestApp(
        child: const TerminalView(),
      ));
      await tester.pumpAndSettle();

      // AppBar 标题与副标题
      expect(find.text('会话1'), findsOneWidget);
      // 内部项目：副标题应为项目名称 "term_internal_proj"，而不是绝对路径
      expect(find.text('term_internal_proj'), findsOneWidget);
      expect(find.text(internalDir.path), findsNothing);

      // 切换为外部项目工作区会话
      final externalPath = p.normalize('C:/workspace/my_ext_work');
      terminalProvider.createSession(
        name: '会话2',
        distroId: 'ubuntu',
        workspacePath: externalPath,
        activate: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('会话2'), findsOneWidget);
      // 外部项目：副标题应为完整路径
      expect(find.text(externalPath), findsOneWidget);
    });
  });

  group('进入终端前的电池优化检测与导航测试', () {
    testWidgets('点击 AppBar 更多菜单中的终端按钮触发进入终端', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const Scaffold(
          appBar: CodeEditorAppBar(filePath: null),
          body: Center(child: Text('Editor')),
        ),
      ));
      await tester.pumpAndSettle();

      // 点击右上角更多按钮
      final moreButton = find.byIcon(Icons.more_vert);
      expect(moreButton, findsOneWidget);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // 菜单弹出，找到“终端”选项
      final terminalItem = find.text('终端');
      expect(terminalItem, findsOneWidget);

      // 点击终端
      await tester.tap(terminalItem);
      await tester.pumpAndSettle();

      // 验证进入终端视图 TerminalView
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('非 Android 平台下 promptBatteryOptimizationIfNeeded 静默返回 false 且无弹窗', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final res = await PermissionService.instance.promptBatteryOptimizationIfNeeded(context);
              expect(res, isFalse);
            },
            child: const Text('Test'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
