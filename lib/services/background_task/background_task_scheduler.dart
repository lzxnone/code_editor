import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/notice_item.dart';
import '../../providers/notice_center.dart';
import '../distro_manager.dart';
import 'background_task.dart';

/// 待执行任务包装条目
class _QueuedTaskEntry<T> {
  final BackgroundTask<T> task;
  final Completer<T> completer;
  final HeadlessCancelToken cancelToken;

  _QueuedTaskEntry({
    required this.task,
    required this.completer,
    required this.cancelToken,
  });
}

/// 统一后台任务调度中心
///
/// 核心职责：
/// 1. 任务排队与优先级排序；
/// 2. [TaskExecutionScope] 资源互斥域管控（针对 Ubuntu 单底座 apt/dpkg 独占锁，严格串行 packageManager 域）；
/// 3. 与 [NoticeCenter] 双向联动（反映入队、执行中、成功淡出、失败驻留，UI 取消联动底层进程中断）；
/// 4. 任务取消与失败时的环境自愈保护。
class BackgroundTaskScheduler {
  BackgroundTaskScheduler._();
  static final BackgroundTaskScheduler instance = BackgroundTaskScheduler._();

  NoticeCenter? _noticeCenter;

  /// 待执行任务队列
  final List<_QueuedTaskEntry> _queue = [];

  /// 正在运行的任务集合
  final Map<String, _QueuedTaskEntry> _runningTasks = {};

  /// 绑定全局通知中心
  void attachNoticeCenter(NoticeCenter noticeCenter) {
    _noticeCenter = noticeCenter;
  }

  /// 提交一个后台任务
  Future<T> submit<T>(BackgroundTask<T> task) {
    final completer = Completer<T>();
    final cancelToken = HeadlessCancelToken();

    final entry = _QueuedTaskEntry<T>(
      task: task,
      completer: completer,
      cancelToken: cancelToken,
    );

    // 插入并按优先级降序排序（优先级高在先）
    _queue.add(entry);
    _queue.sort((a, b) => a.task.priority.compareTo(b.task.priority));

    // 通知中心同步：若任务配置了通知，则先发入队卡片
    if (task.showNotice && _noticeCenter != null) {
      final text = task.createNoticeText(BackgroundTaskState.queued);
      if (text != null) {
        _noticeCenter!.push(
          NoticeItem(
            id: task.id,
            kind: NoticeKind.progress,
            text: text,
            onUserDismiss: () => cancel(task.id),
          ),
        );
      }
    }

    _scheduleNext();
    return completer.future;
  }

  /// 取消指定 ID 的任务（若在队列中则移除，若在运行中则触发 cancelToken）
  void cancel(String taskId) {
    // 1. 检查队列中尚未启动的任务
    final qIndex = _queue.indexWhere((e) => e.task.id == taskId);
    if (qIndex != -1) {
      final entry = _queue.removeAt(qIndex);
      entry.cancelToken.cancel();
      try {
        entry.task.onCancelled();
      } catch (e) {
        debugPrint('[BackgroundTaskScheduler] onCancelled 异常: ');
      }
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(
          const CancellationException('Task cancelled before start'),
        );
      }
      _noticeCenter?.dismiss(taskId);
      return;
    }

    // 2. 检查正在运行的任务
    final running = _runningTasks[taskId];
    if (running != null) {
      running.cancelToken.cancel();
      try {
        running.task.onCancelled();
      } catch (e) {
        debugPrint('[BackgroundTaskScheduler] onCancelled 异常: ');
      }
      // 不直接 dismiss，等待执行体退出抛出/退出时自然结算
    }
  }

  /// 是否有任务正在占用 packageManager 锁
  bool get isPackageManagerBusy {
    return _runningTasks.values
        .any((e) => e.task.scope == TaskExecutionScope.packageManager);
  }

  /// 是否有独占任务正在运行
  bool get isExclusiveBusy {
    return _runningTasks.values
        .any((e) => e.task.scope == TaskExecutionScope.exclusive);
  }

  /// 正在运行的任务总数
  int get runningCount => _runningTasks.length;

  /// 等待队列中的任务总数
  int get queuedCount => _queue.length;

  /// 核心调度分配逻辑
  void _scheduleNext() {
    if (_queue.isEmpty) return;

    // 若当前有 exclusive 任务正在运行，阻塞一切新任务
    if (isExclusiveBusy) return;

    for (int i = 0; i < _queue.length; i++) {
      final candidate = _queue[i];
      final scope = candidate.task.scope;

      if (scope == TaskExecutionScope.exclusive) {
        // 独占任务必须等待当前所有运行中的任务全部结束才能起跑
        if (_runningTasks.isEmpty) {
          _queue.removeAt(i);
          _executeTask(candidate);
        }
        return;
      } else if (scope == TaskExecutionScope.packageManager) {
        // 包管理器任务要求单线排他
        if (!isPackageManagerBusy) {
          _queue.removeAt(i);
          _executeTask(candidate);
          // 继续检查后续队列中是否有可以并发执行的 shared 任务
          _scheduleNext();
          return;
        }
      } else if (scope == TaskExecutionScope.shared) {
        // 共享任务可以并发运行（受最大并发限制，如 4）
        if (_runningTasks.length < 4) {
          _queue.removeAt(i);
          _executeTask(candidate);
          _scheduleNext();
          return;
        }
      }
    }
  }

  Future<void> _executeTask(_QueuedTaskEntry entry) async {
    final task = entry.task;
    _runningTasks[task.id] = entry;

    // 更新为运行中通知
    if (task.showNotice && _noticeCenter != null) {
      final text = task.createNoticeText(BackgroundTaskState.running);
      if (text != null) {
        _noticeCenter!.update(
          task.id,
          kind: NoticeKind.progress,
          text: text,
        );
      }
    }

    final context = TaskExecutionContext(
      cancelToken: entry.cancelToken,
      updateDetail: (detail) {
        if (!entry.cancelToken.isCancelled && task.showNotice && _noticeCenter != null) {
          final text = task.createNoticeText(BackgroundTaskState.running, detail: detail);
          if (text != null) {
            _noticeCenter!.update(task.id, text: text);
          }
        }
      },
      updateProgress: (progress) {
        if (!entry.cancelToken.isCancelled && task.showNotice && _noticeCenter != null) {
          _noticeCenter!.update(task.id, progress: progress);
        }
      },
    );

    try {
      final result = await task.execute(context);
      _runningTasks.remove(task.id);

      if (entry.cancelToken.isCancelled) {
        try {
          task.onCancelled();
        } catch (e) {
          debugPrint('[BackgroundTaskScheduler] onCancelled 异常: ');
        }
        _noticeCenter?.dismiss(task.id);
        if (!entry.completer.isCompleted) {
          entry.completer.completeError(
            const CancellationException('Task was cancelled during execution'),
          );
        }
      } else {
        try {
          task.onSuccess(result);
        } catch (e) {
          debugPrint('[BackgroundTaskScheduler] onSuccess 异常: ');
        }

        if (task.showNotice && _noticeCenter != null) {
          final doneText = task.createNoticeText(BackgroundTaskState.completed);
          if (doneText != null) {
            _noticeCenter!.complete(
              task.id,
              kind: NoticeKind.success,
              text: doneText,
              autoCloseAfter: const Duration(seconds: 3),
            );
          } else {
            _noticeCenter!.dismiss(task.id);
          }
        }

        if (!entry.completer.isCompleted) {
          entry.completer.complete(result);
        }
      }
    } catch (e, stack) {
      _runningTasks.remove(task.id);

      if (entry.cancelToken.isCancelled) {
        try {
          task.onCancelled();
        } catch (err) {
          debugPrint('[BackgroundTaskScheduler] onCancelled 异常: ');
        }
        _noticeCenter?.dismiss(task.id);
        if (!entry.completer.isCompleted) {
          entry.completer.completeError(
            const CancellationException('Task was cancelled'),
          );
        }
      } else {
        try {
          task.onFailure(e, stack);
        } catch (err) {
          debugPrint('[BackgroundTaskScheduler] onFailure 异常: ');
        }

        if (task.showNotice && _noticeCenter != null) {
          final failText = task.createNoticeText(
            BackgroundTaskState.failed,
            error: e.toString(),
          );
          if (failText != null) {
            _noticeCenter!.complete(
              task.id,
              kind: NoticeKind.failure,
              text: failText,
              sticky: true,
            );
          } else {
            _noticeCenter!.dismiss(task.id);
          }
        }

        if (!entry.completer.isCompleted) {
          entry.completer.completeError(e, stack);
        }
      }
    } finally {
      // 触发后续调度
      _scheduleNext();
    }
  }
}

/// 取消异常定义
class CancellationException implements Exception {
  final String message;
  const CancellationException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancellationException: ';
}
