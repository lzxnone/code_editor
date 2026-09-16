import 'dart:io';
import 'dart:typed_data';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMultiFilePicker extends FilePicker {
  List<PlatformFile>? pickedFiles;

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
    if (pickedFiles == null) return null;
    return FilePickerResult(pickedFiles!);
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
  late Directory testProjectDir;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;
  late RunProvider runProvider;
  late MockMultiFilePicker mockFilePicker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('drawer_import_test_');
    testProjectDir = Directory(p.join(tempBaseDir.path, 'my_project'))..createSync();

    InternalProjectService.instance.customProjectsDir =
        Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    runProvider = RunProvider();

    mockFilePicker = MockMultiFilePicker();
    FilePicker.platform = mockFilePicker;

    // Switch to active project
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

  Widget buildTestWidget({
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
        home: const Scaffold(
          drawer: CodeEditorDrawer(),
          body: Center(child: Text('Editor Body')),
        ),
      ),
    );
  }

  testWidgets('Import button is present to the right of new file and new folder buttons with correct tooltip', (tester) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('zh')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify buttons in the subtitle row
    expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
    expect(find.byTooltip('从外部导入'), findsOneWidget);

    // Verify ordering: note_add_outlined < create_new_folder_outlined < file_upload_outlined
    final noteAddOffset = tester.getTopLeft(find.byIcon(Icons.note_add_outlined));
    final folderOffset = tester.getTopLeft(find.byIcon(Icons.create_new_folder_outlined));
    final importOffset = tester.getTopLeft(find.byIcon(Icons.file_upload_outlined));

    expect(noteAddOffset.dx, lessThan(folderOffset.dx));
    expect(folderOffset.dx, lessThan(importOffset.dx));
  });

  testWidgets('Import button shows English tooltip when locale is en', (tester) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Import from External'), findsOneWidget);
  });

  testWidgets('Tapping import button imports multiple external files into project root', (tester) async {
    final file1 = File(p.join(tempBaseDir.path, 'source1.txt'))..writeAsStringSync('hello world');
    final file2 = File(p.join(tempBaseDir.path, 'source2.dart'))..writeAsStringSync('void main() {}');

    mockFilePicker.pickedFiles = [
      PlatformFile(name: 'source1.txt', size: 11, path: file1.path),
      PlatformFile(name: 'source2.dart', size: 16, path: file2.path),
    ];

    await tester.pumpWidget(buildTestWidget(locale: const Locale('zh')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final imported1 = File(p.join(testProjectDir.path, 'source1.txt'));
    final imported2 = File(p.join(testProjectDir.path, 'source2.dart'));

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      for (var i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (imported1.existsSync() && imported2.existsSync()) break;
      }
    });
    await tester.pumpAndSettle();

    // Verify files were copied into testProjectDir
    expect(imported1.existsSync(), isTrue);
    expect(imported1.readAsStringSync(), equals('hello world'));

    expect(imported2.existsSync(), isTrue);
    expect(imported2.readAsStringSync(), equals('void main() {}'));

    // Verify success toast
    expect(find.text('成功导入 2 个文件'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Importing file with duplicate name automatically generates unique filename', (tester) async {
    // Existing file in root
    File(p.join(testProjectDir.path, 'duplicate.txt')).writeAsStringSync('existing original');

    // External file to import
    final extFile = File(p.join(tempBaseDir.path, 'duplicate.txt'))..writeAsStringSync('imported copy');

    mockFilePicker.pickedFiles = [
      PlatformFile(name: 'duplicate.txt', size: 13, path: extFile.path),
    ];

    await tester.pumpWidget(buildTestWidget(locale: const Locale('zh')));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final uniqueFile = File(p.join(testProjectDir.path, 'duplicate(1).txt'));

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      for (var i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (uniqueFile.existsSync()) break;
      }
    });
    await tester.pumpAndSettle();

    // Original file remains unchanged
    expect(File(p.join(testProjectDir.path, 'duplicate.txt')).readAsStringSync(), equals('existing original'));

    // New unique file is created
    expect(uniqueFile.existsSync(), isTrue);
    expect(uniqueFile.readAsStringSync(), equals('imported copy'));

    // Wait for toast to dismiss
    await tester.pump(const Duration(seconds: 3));
  });

  test('ProjectProvider.importFiles supports bytes fallback when path is null', () async {
    final bytes = Uint8List.fromList([65, 66, 67]);
    final file = PlatformFile(
      name: 'bytes_file.txt',
      size: 3,
      bytes: bytes,
    );

    final count = await projectProvider.importFiles(testProjectDir.path, [file]);
    expect(count, equals(1));

    final imported = File(p.join(testProjectDir.path, 'bytes_file.txt'));
    expect(imported.existsSync(), isTrue);
    expect(imported.readAsStringSync(), equals('ABC'));
  });
}
