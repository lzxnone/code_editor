import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/views/project_management_view.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFilePicker extends FilePicker {
  String? pickedPath;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (pickedPath == null) return null;
    return FilePickerResult([
      PlatformFile(name: p.basename(pickedPath!), size: 10, path: pickedPath),
    ]);
  }

  @override
  Future<bool?> clearTemporaryFiles() async => true;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late InternalProjectService projectService;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;
  late RunProvider runProvider;
  late MockFilePicker mockFilePicker;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('project_mgmt_widget_test_');
    projectService = InternalProjectService.instance;
    projectService.customProjectsDir = Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    runProvider = RunProvider();

    mockFilePicker = MockFilePicker();
    FilePicker.platform = mockFilePicker;
  });

  tearDown(() {
    projectService.customProjectsDir = null;
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget({
    required Widget child,
    Locale locale = const Locale('zh'),
  }) {
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
        home: child,
      ),
    );
  }

  group('Drawer Open Project Menu Tests', () {
    testWidgets('Clicking open project button pops up menu with two options (zh & en)', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Main')),
        ),
        locale: const Locale('zh'),
      ));

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Find the folder_open popup menu button
      final openButton = find.byIcon(Icons.folder_open);
      expect(openButton, findsOneWidget);

      await tester.tap(openButton);
      await tester.pumpAndSettle();

      // Check popup menu items
      expect(find.text('从软件内打开'), findsOneWidget);
      expect(find.text('从外部打开'), findsOneWidget);
    });

    testWidgets('Clicking open from app navigates to ProjectManagementView', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Main')),
        ),
      ));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      await tester.tap(find.text('从软件内打开'));
      await tester.pumpAndSettle();

      // Should now be on ProjectManagementView
      expect(find.byType(ProjectManagementView), findsOneWidget);
      expect(find.text('项目'), findsOneWidget);
      expect(find.byTooltip('新建项目'), findsOneWidget);
      expect(find.byTooltip('从外部导入'), findsOneWidget);
    });

    testWidgets('Drawer header subtitle shows project name for internal projects, root path for external projects', (tester) async {
      final internalProj = await projectService.createProject('my_internal_app');

      // 1. 设置内部项目
      projectProvider.setHistoryForTesting(ProjectHistory(
        rootPath: internalProj.path,
        lastOpenedFilePath: null,
      ));

      await tester.pumpWidget(buildTestWidget(
        child: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Main')),
        ),
      ));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // 内部项目应当只显示项目名称，而非完整根路径
      expect(find.text('my_internal_app'), findsOneWidget);
      expect(find.text(internalProj.path), findsNothing);

      // 2. 切换为外部项目
      final externalPath = p.normalize('C:/outside/external_project');
      projectProvider.setHistoryForTesting(ProjectHistory(
        rootPath: externalPath,
        lastOpenedFilePath: null,
      ));
      await tester.pumpAndSettle();

      // 外部项目应显示完整根路径
      expect(find.text(externalPath), findsOneWidget);
    });
  });

  group('ProjectManagementView Feature Tests', () {
    testWidgets('Empty state displays placeholder icon and text', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无项目，点击右上角新建项目'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
      expect(find.text('项目'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
      expect(find.byTooltip('从外部导入'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byTooltip('新建项目'), findsOneWidget);
    });

    testWidgets('Creating a new project via dialog adds item to the list', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      // Tap "新建项目" button (IconButton with tooltip '新建项目')
      await tester.tap(find.byTooltip('新建项目'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('请输入项目名称'), findsOneWidget);

      // Enter project name
      await tester.enterText(find.byType(TextFormField), 'my_flutter_app');
      await tester.pumpAndSettle();

      // Tap confirm button ("确定")
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Project item should now exist in list
      expect(find.text('my_flutter_app'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify directory was actually created
      final projects = await projectService.listProjects();
      expect(projects.length, 1);
      expect(p.basename(projects.first.path), 'my_flutter_app');
    });

    testWidgets('Renaming a project updates folder and UI', (tester) async {
      await projectService.createProject('initial_proj');

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('initial_proj'), findsOneWidget);

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Dialog should appear with 'initial_proj'
      expect(find.text('重命名项目'), findsOneWidget);
      expect(find.text('initial_proj'), findsWidgets);

      // Enter new name
      await tester.enterText(find.byType(TextFormField), 'renamed_proj');
      await tester.pumpAndSettle();

      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Check UI updated
      expect(find.text('renamed_proj'), findsOneWidget);
      expect(find.text('initial_proj'), findsNothing);

      // Verify on disk
      final projects = await projectService.listProjects();
      expect(projects.length, 1);
      expect(p.basename(projects.first.path), 'renamed_proj');
    });

    testWidgets('Deleting a project pops confirmation dialog and deletes folder on confirm', (tester) async {
      await projectService.createProject('project_to_remove');

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('project_to_remove'), findsOneWidget);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('删除项目'), findsOneWidget);
      expect(find.text('确定要删除项目 "project_to_remove" 吗？此操作不可逆。'), findsOneWidget);

      // Tap cancel first
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Item should still be there
      expect(find.text('project_to_remove'), findsOneWidget);

      // Tap delete again and confirm
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Should now be empty
      expect(find.text('project_to_remove'), findsNothing);
      expect(find.text('暂无项目，点击右上角新建项目'), findsOneWidget);

      // Verify on disk
      final projects = await projectService.listProjects();
      expect(projects, isEmpty);
    });

    testWidgets('Tapping project item opens project and returns to main view', (tester) async {
      final projDir = await projectService.createProject('opened_project');
      // Create a dummy file in the project
      File(p.join(projDir.path, 'hello.txt')).writeAsStringSync('world');

      await tester.pumpWidget(buildTestWidget(
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectManagementView()),
              ),
              child: const Text('Go to PM'),
            ),
          ),
        ),
      ));

      // Navigate to ProjectManagementView
      await tester.tap(find.text('Go to PM'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectManagementView), findsOneWidget);
      expect(find.text('opened_project'), findsOneWidget);

      // Tap the project item inside runAsync so FileService buildTree stream can complete
      await tester.runAsync(() async {
        await tester.tap(find.text('opened_project'));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Should have popped back to previous view
      expect(find.byType(ProjectManagementView), findsNothing);
      expect(find.text('Go to PM'), findsOneWidget);

      // Verify ProjectProvider opened the project
      expect(projectProvider.rootPath, p.normalize(projDir.path));
    });

    testWidgets('Full English locale validation (no hardcoded Chinese)', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // English texts in AppBar and empty state
      expect(find.text('Projects'), findsOneWidget);
      expect(find.byTooltip('New Project'), findsOneWidget);
      expect(find.byTooltip('Import from External'), findsOneWidget);
      expect(find.text('No projects yet, click top right to create one'), findsOneWidget);

      // Tap New Project
      await tester.tap(find.byTooltip('New Project'));
      await tester.pumpAndSettle();

      expect(find.text('Enter project name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('Importing project from external archive prompts for name and extracts upon confirmation', (tester) async {
      // Create a test zip
      final zipFilePath = p.join(tempBaseDir.path, 'imported_pkg.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      final dummyFile = File(p.join(tempBaseDir.path, 'info.txt'));
      dummyFile.writeAsStringSync('package contents');
      encoder.addFile(dummyFile);
      encoder.close();

      mockFilePicker.pickedPath = zipFilePath;

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      // Tap import button
      await tester.tap(find.byTooltip('从外部导入'));
      await tester.pumpAndSettle();

      // Dialog should appear with default name from filename "imported_pkg"
      expect(find.text('确认项目名称'), findsOneWidget);
      expect(find.text('imported_pkg'), findsOneWidget);

      // Confirm project name inside runAsync so extractFileToDisk file streams can complete
      await tester.runAsync(() async {
        await tester.tap(find.text('确定'));
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (await projectService.projectExists('imported_pkg')) {
            break;
          }
        }
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Should now show in list
      expect(find.text('imported_pkg'), findsOneWidget);

      // Verify directory on disk
      final projects = await projectService.listProjects();
      expect(projects.length, 1);
      expect(p.basename(projects.first.path), 'imported_pkg');
      expect(File(p.join(projects.first.path, 'info.txt')).existsSync(), isTrue);
    });

    testWidgets('Canceling import dialog does not import or create project', (tester) async {
      final zipFilePath = p.join(tempBaseDir.path, 'cancel_test.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      encoder.close();

      mockFilePicker.pickedPath = zipFilePath;

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('从外部导入'));
      await tester.pumpAndSettle();

      expect(find.text('确认项目名称'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // No projects created
      expect(find.text('cancel_test'), findsNothing);
      expect(find.text('暂无项目，点击右上角新建项目'), findsOneWidget);
      final projects = await projectService.listProjects();
      expect(projects, isEmpty);
    });

    testWidgets('Project items do not have Divider separators', (tester) async {
      await projectService.createProject('project_1');
      await projectService.createProject('project_2');
      await projectService.createProject('project_3');

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('project_1'), findsOneWidget);
      expect(find.text('project_2'), findsOneWidget);
      expect(find.text('project_3'), findsOneWidget);

      // Verify no Divider widgets exist between items
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('Selecting unsupported file format shows error toast and aborts import', (tester) async {
      final invalidFile = File(p.join(tempBaseDir.path, 'unsupported.pdf'));
      invalidFile.writeAsStringSync('not an archive');
      mockFilePicker.pickedPath = invalidFile.path;

      await tester.pumpWidget(buildTestWidget(
        child: const ProjectManagementView(),
      ));
      await tester.pumpAndSettle();

      // Tap import button
      await tester.tap(find.byTooltip('从外部导入'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirmation dialog should NOT appear
      expect(find.text('确认项目名称'), findsNothing);

      // Error toast should appear
      expect(find.text('不支持的文件格式，仅支持压缩包格式 (.zip, .tar.gz, .tar.xz, .tar 等)'), findsOneWidget);

      // Wait for toast to dismiss
      await tester.pump(const Duration(seconds: 3));

      // Verify no project created
      final projects = await projectService.listProjects();
      expect(projects, isEmpty);
    });
  });
}
