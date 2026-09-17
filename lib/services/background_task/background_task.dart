import '../../models/notice_item.dart';
import '../distro_manager.dart';

/// 任务执行范围（互斥域）
enum TaskExecutionScope {
  /// 包管理器域：严格单线程串行（Ubuntu 下 apt-get / dpkg 独占锁保护）
  packageManager,

  /// 独占域：暂停所有其它任务，独自运行
  exclusive,

  /// 共享只读域：允许与其他非 exclusive 任务并发运行（如无副作用的检查、扫描）
  shared,
}

/// 任务优先级（值越大越靠前出队）
enum TaskPriority implements Comparable<TaskPriority> {
  /// 用户主动触发（如用户点击安装/卸载组件）：最高优先
  userInitiated(100),

  /// 项目生命周期触发（如打开工程后的模块依赖探测）：标准优先级
  projectLifecycle(50),

  /// 静默预热/后台空闲：低优先级
  backgroundIdle(10);

  final int value;
  const TaskPriority(this.value);

  @override
  int compareTo(TaskPriority other) => other.value.compareTo(value);
}

/// 任务执行状态
enum BackgroundTaskState {
  queued,
  running,
  completed,
  failed,
  cancelled,
}

/// 任务执行上下文
class TaskExecutionContext {
  /// 用于中断底层进程的取消令牌
  final HeadlessCancelToken cancelToken;

  /// 实时输出行/副标题更新
  final void Function(String line) updateDetail;

  /// 进度百分比更新（0.0 ~ 1.0）
  final void Function(double? progress) updateProgress;

  const TaskExecutionContext({
    required this.cancelToken,
    required this.updateDetail,
    required this.updateProgress,
  });

  bool get isCancelled => cancelToken.isCancelled;
}

/// 全局后台任务抽象接口
abstract class BackgroundTask<T> {
  /// 全局唯一任务 ID（同时作为右上角通知 NoticeItem 的 id）
  String get id;

  /// 互斥作用域
  TaskExecutionScope get scope;

  /// 优先级
  TaskPriority get priority => TaskPriority.projectLifecycle;

  /// 是否在 NoticeCenter 中展示右上角悬浮通知
  bool get showNotice => true;

  /// 根据状态生成对应的结构化通知文案（无硬编码）
  NoticeText? createNoticeText(BackgroundTaskState state, {String? detail, String? error});

  /// 核心执行体
  Future<T> execute(TaskExecutionContext context);

  /// 取消回调
  void onCancelled() {}

  /// 失败回调
  void onFailure(Object error, StackTrace stackTrace) {}

  /// 成功回调
  void onSuccess(T result) {}
}
