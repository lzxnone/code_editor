import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DialogUtils Tests', () {
    testWidgets('shows toast on overlay without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    DialogUtils.showToast(context, 'Test Toast');
                    DialogUtils.showSuccessToast(context, 'Success Toast');
                    DialogUtils.showErrorToast(context, 'Error Toast');
                    DialogUtils.showWarningToast(context, 'Warning Toast');
                    DialogUtils.showInfoToast(context, 'Info Toast');
                  },
                  child: const Text('Trigger Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Toast'));
      await tester.pump();

      expect(find.text('Test Toast'), findsOneWidget);
      expect(find.text('Success Toast'), findsOneWidget);
      expect(find.text('Error Toast'), findsOneWidget);
      expect(find.text('Warning Toast'), findsOneWidget);
      expect(find.text('Info Toast'), findsOneWidget);

      // 等待 toast 定时器执行完毕并移除
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows info dialog and closes on button click', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    DialogUtils.showInfoDialog(
                      context,
                      title: '信息提示',
                      message: '这是信息内容',
                    );
                  },
                  child: const Text('Open Info Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Info Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('信息提示'), findsOneWidget);
      expect(find.text('这是信息内容'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.text('信息提示'), findsNothing);
    });

    testWidgets('shows warning dialog and error dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    DialogUtils.showWarningDialog(
                      context,
                      title: '警告提示',
                      message: '这是警告内容',
                    );
                  },
                  child: const Text('Open Warning Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Warning Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('警告提示'), findsOneWidget);
      expect(find.text('这是警告内容'), findsOneWidget);
      expect(find.text('知道了'), findsOneWidget);

      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      expect(find.text('警告提示'), findsNothing);
    });

    testWidgets('shows normal confirm dialog returning true on confirm and false on cancel',
        (WidgetTester tester) async {
      bool? confirmResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        confirmResult = await DialogUtils.showConfirmDialog(
                          context,
                          title: '普通确认',
                          message: '确认要执行此操作吗？',
                        );
                      },
                      child: const Text('Open Confirm'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // 1. 测试点击取消
      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('普通确认'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(confirmResult, false);

      // 2. 测试点击确定
      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(confirmResult, true);
    });

    testWidgets('shows destructive confirm dialog with error styling and delete action',
        (WidgetTester tester) async {
      bool? confirmResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    confirmResult = await DialogUtils.showDestructiveConfirmDialog(
                      context,
                      title: '确认删除',
                      message: '删除后无法恢复！',
                      confirmText: '永久删除',
                    );
                  },
                  child: const Text('Open Delete Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Delete Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除'), findsOneWidget);
      expect(find.text('永久删除'), findsOneWidget);

      await tester.tap(find.text('永久删除'));
      await tester.pumpAndSettle();

      expect(confirmResult, true);
    });

    testWidgets('shows input dialog with validation and returns value',
        (WidgetTester tester) async {
      String? enteredValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    enteredValue = await DialogUtils.showInputDialog(
                      context,
                      title: '新建文件',
                      hintText: '请输入文件名',
                      initialValue: 'init.dart',
                    );
                  },
                  child: const Text('Open Input Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Input Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('新建文件'), findsOneWidget);
      expect(find.text('init.dart'), findsOneWidget);

      // 1. 输入非法字符并校验
      await tester.enterText(find.byType(TextFormField), 'bad/name');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.text('名称不能包含非法字符 (\\/:*?"<>|)'), findsOneWidget);

      // 2. 输入合法字符并确定
      await tester.enterText(find.byType(TextFormField), 'good_name.dart');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(enteredValue, 'good_name.dart');
    });

    testWidgets('shows save prompt dialog and handles save, discard, cancel',
        (WidgetTester tester) async {
      SavePromptResult? promptResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    promptResult = await DialogUtils.showSavePromptDialog(
                      context,
                      fileName: 'main.dart',
                    );
                  },
                  child: const Text('Open Save Prompt'),
                );
              },
            ),
          ),
        ),
      );

      // 1. Test Cancel
      await tester.tap(find.text('Open Save Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('保存更改'), findsOneWidget);
      expect(find.text('文件 "main.dart" 已被修改，是否保存更改？'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('不保存'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(promptResult, equals(SavePromptResult.cancel));

      // 2. Test Discard
      await tester.tap(find.text('Open Save Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不保存'));
      await tester.pumpAndSettle();
      expect(promptResult, equals(SavePromptResult.discard));

      // 3. Test Save
      await tester.tap(find.text('Open Save Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(promptResult, equals(SavePromptResult.save));
    });
  });
}
