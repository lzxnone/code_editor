import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/models/notice_item.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/services/background_task/background_task.dart';
import 'package:code_editor/services/background_task/background_task_scheduler.dart';
import 'package:code_editor/services/background_task/generic_background_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundTaskScheduler Tests', () {
    late NoticeCenter noticeCenter;
    late BackgroundTaskScheduler scheduler;

    setUp(() {
      noticeCenter = NoticeCenter();
      scheduler = BackgroundTaskScheduler.instance;
      scheduler.attachNoticeCenter(noticeCenter);
    });

    test('packageManager scope tasks are executed sequentially without race conditions', () async {
      final executionOrder = <String>[];
      final activePackageManagerTasks = <String>[];
      var maxConcurrentPackageManager = 0;

      Future<bool> runTask(String id, Duration duration) async {
        activePackageManagerTasks.add(id);
        if (activePackageManagerTasks.length > maxConcurrentPackageManager) {
          maxConcurrentPackageManager = activePackageManagerTasks.length;
        }
        await Future.delayed(duration);
        executionOrder.add(id);
        activePackageManagerTasks.remove(id);
        return true;
      }

      final task1 = GenericBackgroundTask<bool>(
        id: 'pkg1',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        runner: (_) => runTask('pkg1', const Duration(milliseconds: 50)),
      );

      final task2 = GenericBackgroundTask<bool>(
        id: 'pkg2',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        runner: (_) => runTask('pkg2', const Duration(milliseconds: 20)),
      );

      final future1 = scheduler.submit(task1);
      final future2 = scheduler.submit(task2);

      await Future.wait([future1, future2]);

      expect(maxConcurrentPackageManager, 1);
      expect(executionOrder, ['pkg1', 'pkg2']);
    });

    test('Higher priority task jumps queue ahead of lower priority queued tasks', () async {
      final executionOrder = <String>[];

      // 先占住 packageManager 锁
      final blocker = GenericBackgroundTask<bool>(
        id: 'blocker',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        runner: (_) async {
          await Future.delayed(const Duration(milliseconds: 60));
          executionOrder.add('blocker');
          return true;
        },
      );

      final lowPriority = GenericBackgroundTask<bool>(
        id: 'low',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        runner: (_) async {
          executionOrder.add('low');
          return true;
        },
      );

      final highPriority = GenericBackgroundTask<bool>(
        id: 'high',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.userInitiated,
        runner: (_) async {
          executionOrder.add('high');
          return true;
        },
      );

      final fBlocker = scheduler.submit(blocker);
      // 两个在 blocker 执行期间进入排队
      final fLow = scheduler.submit(lowPriority);
      final fHigh = scheduler.submit(highPriority);

      await Future.wait([fBlocker, fLow, fHigh]);

      expect(executionOrder, ['blocker', 'high', 'low']);
    });

    test('Task cancellation removes queued task and notifies NoticeCenter', () async {
      // blocker
      final blocker = GenericBackgroundTask<bool>(
        id: 'blocker2',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        runner: (_) => Future.delayed(const Duration(milliseconds: 50), () => true),
      );

      final target = GenericBackgroundTask<bool>(
        id: 'to_cancel',
        scope: TaskExecutionScope.packageManager,
        priority: TaskPriority.projectLifecycle,
        showNotice: true,
        noticeTextBuilder: (state, {detail, error}) => const ComponentInstallPhaseText(
          componentName: 'test',
          isQueued: true,
        ),
        runner: (_) async => true,
      );

      final fBlocker = scheduler.submit(blocker);
      final fTarget = scheduler.submit(target);

      expect(noticeCenter.visible.any((e) => e.id == 'to_cancel'), isTrue);

      scheduler.cancel('to_cancel');

      expect(fTarget, throwsA(isA<CancellationException>()));
      // dismiss 后卡片被标记为 removing（等待 UI 播放退场动画）
      expect(noticeCenter.removingIds.contains('to_cancel'), isTrue);
      noticeCenter.finalizeDismiss('to_cancel');
      expect(noticeCenter.visible.any((e) => e.id == 'to_cancel'), isFalse);

      await fBlocker;
    });
  });
}
