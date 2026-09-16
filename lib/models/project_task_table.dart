import 'run_task.dart';
import 'run_task_type.dart';

/// 当前工程的系统任务内存表：**类型 → 任务数组**（哈希表）。
///
/// * 进入项目时逐类型加载；
/// * 某个模块探测完成，就只写入自己类型那一格（[replaceType]）；
/// * UI 按类型逐段渲染（[nonEmptyTypes] 给出非空类型，顺序即枚举顺序）。
class ProjectTaskTable {
  final Map<RunTaskType, List<RunTask>> _byType = {
    for (final type in RunTaskType.values) type: <RunTask>[],
  };

  List<RunTask> tasksOf(RunTaskType type) => List.unmodifiable(_byType[type] ?? const []);

  /// 非空类型（按枚举顺序，即 UI 展示顺序）
  List<RunTaskType> get nonEmptyTypes =>
      [for (final type in RunTaskType.values) if ((_byType[type] ?? const []).isNotEmpty) type];

  bool get isEmpty => _byType.values.every((tasks) => tasks.isEmpty);

  int get totalCount => _byType.values.fold(0, (sum, tasks) => sum + tasks.length);

  /// 模块探测完成 -> 覆盖写入自己类型那一格
  void replaceType(RunTaskType type, List<RunTask> tasks) {
    _byType[type] = List<RunTask>.from(tasks);
  }

  /// 用户自定义任务写入 user 类型
  void setUserTasks(List<RunTask> tasks) => replaceType(RunTaskType.user, tasks);

  void clear() {
    for (final type in RunTaskType.values) {
      _byType[type] = <RunTask>[];
    }
  }

  /// 按类型顺序展开的全部任务（用户任务在最后）
  List<RunTask> get allOrdered => [
        for (final type in RunTaskType.values) ...?_byType[type],
      ];

  /// 全部探测任务（不含用户自定义任务）
  List<RunTask> get detectedTasks => [
        for (final type in RunTaskType.values)
          if (type != RunTaskType.user) ...?_byType[type],
      ];
}
