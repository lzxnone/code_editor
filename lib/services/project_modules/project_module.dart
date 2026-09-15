import 'dart:io';
import '../../models/run_task.dart';
import '../distro_manager.dart';
import '../run_task_storage_service.dart';

/// 传递给各项目探测模块的上下文环境
class ProjectModuleContext {
  /// 工程根目录
  final Directory projectDir;

  /// 当前在编辑器中激活的文件路径（宿主绝对路径，可能为 null）
  final String? currentFilePath;

  /// 容器系统名称（默认为 'ubuntu' 或当前激活的容器）
  final String systemName;

  /// 任务持久化存储服务
  final RunTaskStorageService storageService;

  /// 容器管理器
  final DistroManager distroManager;

  const ProjectModuleContext({
    required this.projectDir,
    this.currentFilePath,
    this.systemName = 'ubuntu',
    required this.storageService,
    required this.distroManager,
  });

  /// 在容器后台静默执行命令并捕获输出
  Future<ProcessResult?> runHeadless(
    String command, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    return distroManager.runHeadlessCommand(
      systemName: systemName,
      workspacePath: projectDir.path,
      command: command,
      timeout: timeout,
    );
  }
}

/// 项目探测模块接口（对标 VS Code TaskProvider）
abstract class ProjectModule {
  /// 模块唯一标识（如 'gradle', 'cmake', 'cargo', 'npm' 等）
  String get id;

  /// 模块友好展示名称
  String get displayName;

  /// 该项目特有的特征标记文件（命中其中任意一个才激活本探测器）
  List<String> get triggerFiles;

  /// 快速判断当前工程是否匹配本模块（毫秒级，只检测文件存在与否，不进行深层解析）
  bool shouldActivate(Directory projectDir);

  /// 探测项目任务（支持优先读取本地缓存；当 forceRefresh=true 时强制发起真实探测）
  Future<List<RunTask>> detect(ProjectModuleContext context, {bool forceRefresh = false});
}
