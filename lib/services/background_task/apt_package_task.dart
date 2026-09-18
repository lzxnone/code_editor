import '../../models/distro_manifest.dart';
import '../../models/notice_item.dart';
import '../distro_manager.dart';
import '../internal_engine_service.dart';
import '../toolchain_service.dart';
import 'background_task.dart';

/// Ubuntu APT 软件包安装与卸载任务
///
/// 运行在 [TaskExecutionScope.packageManager] 互斥域内，
/// 保证同一时刻全局只有一个 apt-get/dpkg 命令执行，杜绝锁冲突。
class AptPackageTask extends BackgroundTask<bool> {
  final String packageName;
  final String componentDisplayName;
  final bool isUninstall;
  @override
  final TaskPriority priority;

  AptPackageTask({
    required this.packageName,
    required this.componentDisplayName,
    this.isUninstall = false,
    this.priority = TaskPriority.userInitiated,
  });

  @override
  String get id => 'pkg:${isUninstall ? 'remove' : 'install'}:$packageName';

  @override
  TaskExecutionScope get scope => TaskExecutionScope.packageManager;

  @override
  NoticeText? createNoticeText(
    BackgroundTaskState state, {
    String? detail,
    String? error,
  }) {
    switch (state) {
      case BackgroundTaskState.queued:
        return ComponentInstallPhaseText(
          componentName: componentDisplayName,
          isUninstall: isUninstall,
          isQueued: true,
        );
      case BackgroundTaskState.running:
        return ComponentInstallPhaseText(
          componentName: componentDisplayName,
          isUninstall: isUninstall,
          isQueued: false,
          detail: detail,
        );
      case BackgroundTaskState.completed:
        return ComponentInstallDoneText(
          componentName: componentDisplayName,
          isUninstall: isUninstall,
        );
      case BackgroundTaskState.failed:
        return ComponentInstallFailureText(
          componentName: componentDisplayName,
          isUninstall: isUninstall,
          error: error,
        );
      case BackgroundTaskState.cancelled:
        return null;
    }
  }

  @override
  Future<bool> execute(TaskExecutionContext context) async {
    final engine = InternalEngineService.instance;
    if (!await engine.isEngineInstalled() || packageName.trim().isEmpty) {
      return false;
    }

    final rootfs = await engine.getRootfsDir();

    final cmd = isUninstall
        ? '${ToolchainService.dpkgAutoHealPrefix} '
            'apt-get remove --purge -y ${packageName.trim()} && '
            'apt-get autoremove -y'
        : '${ToolchainService.dpkgAutoHealPrefix} '
            'apt-get update && '
            'apt-get install -y --no-install-recommends ${packageName.trim()}';

    final res = await DistroManager().runHeadlessCommand(
      systemName: DistroRepository.defaultSystemName,
      customRootDir: rootfs,
      command: cmd,
      timeout: isUninstall ? const Duration(minutes: 5) : const Duration(minutes: 10),
      cancelToken: context.cancelToken,
      onStdout: (chunk) {
        final line = chunk.trim();
        if (line.isNotEmpty) {
          context.updateDetail(line);
        }
      },
    );

    if (context.isCancelled) {
      // 被取消后，进行一次后台锁自愈
      _healDpkgLock(rootfs);
      return false;
    }

    final success = res != null && res.exitCode == 0;
    if (!success) {
      throw Exception(
        'apt process exited with code ${res?.exitCode ?? -1}: ${res?.stderr}',
      );
    }
    return true;
  }

  void _healDpkgLock(dynamic rootfs) {
    DistroManager().runHeadlessCommand(
      systemName: DistroRepository.defaultSystemName,
      customRootDir: rootfs,
      command: 'dpkg --configure -a 2>/dev/null || true',
      timeout: const Duration(seconds: 30),
    );
  }
}
