import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/widgets/notice_host.dart';
import 'package:code_editor/widgets/probe_cancel_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Stack(children: [Positioned.fill(child: child)])),
      );

  NoticeItem progressNotice({bool confirm = true, VoidCallback? onDismiss}) => NoticeItem(
        id: 'probe:gradle',
        kind: NoticeKind.progress,
        text: const ModulePhaseText(
          moduleDisplayName: 'Gradle',
          phase: ProbeNoticePhase.detecting,
        ),
        onUserDismiss: onDismiss,
        confirmBeforeDismiss: confirm,
      );

  Future<void> settle(WidgetTester tester) async {
    // 进行中的通知含无限进度圈，不能用 pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('取消探测的二次确认', () {
    testWidgets('确认弹窗文案与按钮来自 l10n（取消 => 探测继续）', (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(wrap(Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async => results.add(await confirmCancelProbe(context)),
            child: const Text('cancel'),
          ),
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(find.text('取消本次探测？'), findsOneWidget);
      expect(find.textContaining('未完成的模块将被跳过'), findsOneWidget);

      await tester.tap(find.text('继续探测'));
      await tester.pumpAndSettle();
      expect(results, [false], reason: '"继续探测" => 不取消');
    });

    testWidgets('点"取消探测" => 确认取消', (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(wrap(Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async => results.add(await confirmCancelProbe(context)),
            child: const Text('cancel'),
          ),
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消探测'));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('NoticeHost：confirmBeforeDismiss 为 false 时直接关闭（不弹确认）', (tester) async {
      final center = NoticeCenter();
      var dismissedByUser = false;
      await tester.pumpWidget(wrap(NoticeHost(
        center: center,
        confirmDismissBuilder: confirmCancelProbe,
      )));
      await tester.pumpAndSettle();

      center.push(progressNotice(confirm: false, onDismiss: () => dismissedByUser = true));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('取消本次探测？'), findsNothing);
      expect(dismissedByUser, isTrue);
      expect(center.visible, isEmpty);
    });

    testWidgets('NoticeHost：在确认弹窗里选"继续探测" => 卡片保留、附加动作不执行', (tester) async {
      final center = NoticeCenter();
      var dismissedByUser = false;
      await tester.pumpWidget(wrap(NoticeHost(
        center: center,
        confirmDismissBuilder: confirmCancelProbe,
      )));
      await tester.pumpAndSettle();

      center.push(progressNotice(onDismiss: () => dismissedByUser = true));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.text('取消本次探测？'), findsOneWidget);

      await tester.tap(find.text('继续探测'));
      await settle(tester);

      expect(dismissedByUser, isFalse, reason: '放弃取消 => 不得执行"取消探测"动作');
      expect(center.visible, hasLength(1), reason: '卡片必须保留');
    });

    testWidgets('NoticeHost：确认"取消探测" => 执行附加动作并移除卡片', (tester) async {
      final center = NoticeCenter();
      var dismissedByUser = false;
      await tester.pumpWidget(wrap(NoticeHost(
        center: center,
        confirmDismissBuilder: confirmCancelProbe,
      )));
      await tester.pumpAndSettle();

      center.push(progressNotice(onDismiss: () => dismissedByUser = true));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      await tester.tap(find.text('取消探测'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(dismissedByUser, isTrue);
      expect(center.visible, isEmpty);
    });
  });
}
