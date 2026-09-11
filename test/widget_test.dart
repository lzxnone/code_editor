import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:code_editor/main.dart';

void main() {
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
}




