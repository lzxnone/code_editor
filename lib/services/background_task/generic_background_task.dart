import '../../models/notice_item.dart';
import 'background_task.dart';

/// 包装一个函数执行体到后台调度系统（如探测中的依赖自动安装等）
class GenericBackgroundTask<T> extends BackgroundTask<T> {
  @override
  final String id;
  @override
  final TaskExecutionScope scope;
  @override
  final TaskPriority priority;
  @override
  final bool showNotice;

  final Future<T> Function(TaskExecutionContext context) runner;
  final NoticeText? Function(BackgroundTaskState state, {String? detail, String? error})? noticeTextBuilder;

  GenericBackgroundTask({
    required this.id,
    required this.scope,
    this.priority = TaskPriority.projectLifecycle,
    this.showNotice = false,
    required this.runner,
    this.noticeTextBuilder,
  });

  @override
  NoticeText? createNoticeText(BackgroundTaskState state, {String? detail, String? error}) {
    return noticeTextBuilder?.call(state, detail: detail, error: error);
  }

  @override
  Future<T> execute(TaskExecutionContext context) {
    return runner(context);
  }
}
