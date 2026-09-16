import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/widgets/notice_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHost(NoticeCenter center, {Locale locale = const Locale('zh')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: Stack(
            children: [
              Positioned.fill(child: NoticeHost(center: center)),
            ],
          ),
        ),
      ),
    );
  }

  /// 推进动画：注意"进行中"通知里的 CircularProgressIndicator 是无限动画，
  /// 因此这里必须用显式 pump(duration)，不能用 pumpAndSettle。
  Future<void> advance(WidgetTester tester, [int ms = 400]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
  }

  NoticeItem phaseNotice(
    String id, {
    String module = 'Gradle',
    ProbeNoticePhase phase = ProbeNoticePhase.detecting,
  }) =>
      NoticeItem(
        id: id,
        kind: NoticeKind.progress,
        text: ModulePhaseText(moduleDisplayName: module, phase: phase),
      );

  group('NoticeHost 通知堆叠宿主', () {
    testWidgets('空队列时不渲染任何内容', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gradle'), findsNothing);
    });

    testWidgets('可同时插入多条通知，文案来自 l10n（中文）', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle', module: 'Gradle'));
      center.push(phaseNotice('probe:npm', module: 'NPM'));
      await advance(tester);

      expect(find.text('正在探测 Gradle 任务…'), findsOneWidget);
      expect(find.text('正在探测 NPM 任务…'), findsOneWidget);
    });

    testWidgets('英文环境下同一模型渲染为英文文案（零硬编码）', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center, locale: const Locale('en')));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle', module: 'Gradle'));
      await advance(tester);
      expect(find.text('Detecting Gradle tasks…'), findsOneWidget);
      expect(find.text('正在探测 Gradle 任务…'), findsNothing);
    });

    testWidgets('插入动画：可见透明度在动画中途介于 0~1', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle'));
      await tester.pump(); // 动画起点
      await tester.pump(const Duration(milliseconds: 90)); // 动画中途

      final midwayOpacity = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((w) => w.opacity.value)
          .toList();
      expect(midwayOpacity.any((v) => v > 0 && v < 1), isTrue,
          reason: '插入过程中应能观测到透明度介于 0~1 的中间态');

      await tester.pump(const Duration(milliseconds: 400));
      final settledOpacity = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((w) => w.opacity.value)
          .toList();
      expect(settledOpacity.every((v) => v == 1.0), isTrue);
    });

    testWidgets('点击关闭按钮：退场动画后条目消失', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle'));
      await advance(tester);
      expect(find.text('正在探测 Gradle 任务…'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60)); // 退场动画中
      expect(center.removingIds, contains('probe:gradle'));

      await tester.pump(const Duration(milliseconds: 400)); // 退场动画结束
      expect(find.text('正在探测 Gradle 任务…'), findsNothing);
      expect(center.visible, isEmpty);
    });

    testWidgets('超过可视上限的通知进入队列，关闭一条后自动补位弹出', (tester) async {
      final center = NoticeCenter(visibleLimit: 2);
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle', module: 'Gradle'));
      center.push(phaseNotice('probe:npm', module: 'NPM'));
      center.push(phaseNotice('probe:make', module: 'Makefile'));
      await advance(tester);

      expect(find.text('正在探测 Makefile 任务…'), findsNothing);
      expect(find.text('还有 1 项进行中'), findsOneWidget);

      // 关闭一条 -> 队列首条自动弹出
      center.dismiss('probe:npm');
      await advance(tester, 600);
      expect(find.text('正在探测 Makefile 任务…'), findsOneWidget);
      expect(find.text('还有 1 项进行中'), findsNothing);
    });

    testWidgets('失败通知显示模块标题 + 结构化原因（toolchainMissing）', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(NoticeItem(
        id: 'probe:gradle',
        kind: NoticeKind.failure,
        text: const ModuleFailureText(
          moduleDisplayName: 'Gradle',
          failure: NoticeFailure.toolchainMissing,
          detail: 'gradle',
        ),
        sticky: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Gradle 任务探测失败'), findsOneWidget);
      expect(find.text('当前系统内未找到 gradle，请先在系统管理中安装'), findsOneWidget);
    });

    testWidgets('完成通知自动关闭后完全消失', (tester) async {
      final center = NoticeCenter();
      await tester.pumpWidget(buildHost(center));
      await tester.pumpAndSettle();

      center.push(phaseNotice('probe:gradle'));
      await advance(tester);

      // 成功 -> 转为"已完成"静态卡片，并在 autoCloseAfter 后自动关闭
      center.complete(
        'probe:gradle',
        kind: NoticeKind.success,
        text: const ModuleDoneText('Gradle', taskCount: 3),
        autoCloseAfter: const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gradle 探测完成 · 发现 3 个任务'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Gradle 探测完成 · 发现 3 个任务'), findsNothing);
      expect(center.visible, isEmpty);
    });
  });
}
