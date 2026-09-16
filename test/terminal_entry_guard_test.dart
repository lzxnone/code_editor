import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/widgets/terminal_entry_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 挂一个按钮调用守卫，把返回值记录下来（无需真正进入终端 view）
  Future<void> pumpGuard(WidgetTester tester, List<bool> results) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  results.add(await confirmEnterTerminalWhileProbing(context));
                },
                child: const Text('terminal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('进入终端前的探测占用确认', () {
    testWidgets('文案与按钮来自 l10n，取消 => 不进入终端', (tester) async {
      final results = <bool>[];
      await pumpGuard(tester, results);

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      expect(find.text('任务探测进行中'), findsOneWidget);
      expect(find.textContaining('是否仍要进入终端？'), findsOneWidget);
      expect(find.text('继续进入终端'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(results, [false], reason: '取消必须返回 false（不进入终端）');
    });

    testWidgets('继续进入终端 => 返回 true', (tester) async {
      final results = <bool>[];
      await pumpGuard(tester, results);

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续进入终端'));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('点弹窗外部关闭 => 按取消处理（保守不进入）', (tester) async {
      final results = <bool>[];
      await pumpGuard(tester, results);

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      // 点击对话框外的遮罩区域
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });
  });
}
