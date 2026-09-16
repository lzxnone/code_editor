import 'run_task.dart';

/// 内置任务类型（完全可枚举）：UI 按"类型 → 具体任务"分组呈现。
///
/// 顺序即 UI 展示顺序；[user] 永远在最后。
/// 每个探测模块对应一个类型，模块探测出的任务只写入自己类型那一格。
enum RunTaskType {
  gradle,
  cmake,
  cargo,
  npm,
  make,
  dart,

  /// 未映射到内置类型模块的探测任务（例如运行时注册的自定义模块）
  other,
  singleFile,
  user;

  /// 该类型对应的模块 id（非模块类型返回 null）
  String? get moduleId => switch (this) {
        RunTaskType.gradle => 'gradle',
        RunTaskType.cmake => 'cmake',
        RunTaskType.cargo => 'cargo',
        RunTaskType.npm => 'npm',
        RunTaskType.make => 'make',
        RunTaskType.dart => 'dart',
        RunTaskType.other => null,
        RunTaskType.singleFile => null,
        RunTaskType.user => null,
      };

  /// 是否为"可执行真实自省/可重新同步"的模块类型
  bool get isModuleType => moduleId != null;

  /// 类型展示名（模块类型为专有名词，不做本地化；用户任务/单文件走 l10n）
  static const Map<String, RunTaskType> _byModuleId = {
    'gradle': RunTaskType.gradle,
    'cmake': RunTaskType.cmake,
    'cargo': RunTaskType.cargo,
    'npm': RunTaskType.npm,
    'make': RunTaskType.make,
    'dart': RunTaskType.dart,
  };

  /// 模块 id -> 类型
  static RunTaskType? fromModuleId(String? moduleId) {
    if (moduleId == null || moduleId.isEmpty) return null;
    return _byModuleId[moduleId];
  }

  /// 单条任务归属的类型
  static RunTaskType ofTask(RunTask task) {
    if (task.source == TaskSource.custom) return RunTaskType.user;
    final byModule = fromModuleId(task.moduleId);
    if (byModule != null) return byModule;
    if (task.group == 'single_file') return RunTaskType.singleFile;
    // 有模块归属但未映射到内置类型（自定义模块）-> other；其它无模块任务才算用户可见兜底
    if (task.moduleId != null && task.moduleId!.isNotEmpty) return RunTaskType.other;
    return RunTaskType.user;
  }
}
