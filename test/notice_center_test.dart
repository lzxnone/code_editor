import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/providers/notice_center.dart';

void main() {
  NoticeItem progress(String id, {String module = 'Gradle'}) => NoticeItem(
        id: id,
        kind: NoticeKind.progress,
        text: ModulePhaseText(moduleDisplayName: module, phase: ProbeNoticePhase.detecting),
      );

  group('NoticeCenter 通知队列', () {
    test('可视槽位未满时直接展示，超限后进入队列', () {
      final center = NoticeCenter(visibleLimit: 2);
      center.push(progress('probe:gradle'));
      center.push(progress('probe:npm'));
      expect(center.visible.map((e) => e.id).toList(), ['probe:npm', 'probe:gradle']);
      expect(center.queued, isEmpty);

      center.push(progress('probe:make'));
      expect(center.visible, hasLength(2));
      expect(center.queued.map((e) => e.id).toList(), ['probe:make']);
    });

    test('关闭一条后，队列首条自动补位（弹窗关闭自动弹出）', () {
      final center = NoticeCenter(visibleLimit: 1);
      center.push(progress('probe:gradle'));
      center.push(progress('probe:npm'));

      // 先进入"正在移除"（UI 播退场动画），真正移除前队列不补位
      center.dismiss('probe:gradle');
      expect(center.removingIds, contains('probe:gradle'));
      expect(center.visible, hasLength(1));
      expect(center.queued, hasLength(1));

      // 动画结束回调 -> 移除 + 补位
      center.finalizeDismiss('probe:gradle');
      expect(center.visible.map((e) => e.id).toList(), ['probe:npm']);
      expect(center.queued, isEmpty);
      expect(center.removingIds, isEmpty);
    });

    test('队列中的条目被关闭时直接移除并立即补位', () {
      final center = NoticeCenter(visibleLimit: 1);
      center.push(progress('probe:gradle'));
      center.push(progress('probe:npm'));
      center.dismiss('probe:npm');
      expect(center.queued, isEmpty);
      expect(center.visible.map((e) => e.id).toList(), ['probe:gradle']);
    });

    test('update 就地更新文案但不改变位置', () {
      final center = NoticeCenter(visibleLimit: 3);
      center.push(progress('probe:gradle'));
      center.push(progress('probe:npm'));
      center.update(
        'probe:gradle',
        text: const ModulePhaseText(
          moduleDisplayName: 'Gradle',
          phase: ProbeNoticePhase.checkingDependency,
        ),
      );
      expect(center.visible.map((e) => e.id).toList(), ['probe:npm', 'probe:gradle']);
      final gradle = center.visible.last;
      expect((gradle.text as ModulePhaseText).phase, ProbeNoticePhase.checkingDependency);
    });

    testWidgets('complete 带 autoCloseAfter 时延时自动关闭；sticky 则保留', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final center = NoticeCenter(visibleLimit: 3);
      center.push(progress('probe:gradle'));
      center.push(progress('probe:npm'));

      // 成功：1 秒后自动进入移除流程
      center.complete('probe:gradle', kind: NoticeKind.success, autoCloseAfter: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 900));
      expect(center.removingIds, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(center.removingIds, contains('probe:gradle'));

      // 失败：sticky 不自动关闭
      center.complete(
        'probe:npm',
        kind: NoticeKind.failure,
        text: const ModuleFailureText(
          moduleDisplayName: 'NPM',
          failure: NoticeFailure.toolchainMissing,
          detail: 'npm',
        ),
        sticky: true,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(center.removingIds, isNot(contains('probe:npm')));
      expect(center.visible.map((e) => e.id), contains('probe:npm'));
    });

    testWidgets('dismissAll 清空可见与队列，并取消所有自动关闭定时器', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final center = NoticeCenter(visibleLimit: 1);
      center.push(progress('probe:gradle'));
      center.complete('probe:gradle', kind: NoticeKind.success, autoCloseAfter: const Duration(seconds: 5));
      center.push(progress('probe:npm'));
      center.dismissAll();
      expect(center.isEmpty, isTrue);
      // 定时器已取消：不会在之后触发任何状态变化
      await tester.pump(const Duration(seconds: 10));
      expect(center.isEmpty, isTrue);
    });
  });
}
