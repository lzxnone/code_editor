import '../models/run_task.dart';
import 'project_task_dispatcher.dart';

/// 负责根据工程文件和当前打开的文件，在内存中动态推导可用的运行任务
/// （现已接入模块化 ProjectTaskDispatcher 总调度器，保持向后 100% 兼容）
class ProjectTaskDetector {
  /// 核心探测入口
  /// [projectRoot]: 工程根目录（宿主绝对路径）
  /// [currentFilePath]: 当前编辑器激活打开的文件（宿主绝对路径，可能为 null）
  static Future<List<RunTask>> detect({
    required String projectRoot,
    String? currentFilePath,
  }) {
    return ProjectTaskDispatcher.instance.detect(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
    );
  }
}
