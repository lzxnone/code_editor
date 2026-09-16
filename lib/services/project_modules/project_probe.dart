import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/notice_item.dart';
import '../../models/run_task.dart';
import '../distro_manager.dart';
import '../toolchain_service.dart';

/// 探测阶段（队列线性执行：入队 → 依赖检测 → 自动补全 → 执行探测 → 整理）
enum ProbePhase { queued, checkingDependency, installingDependency, probing, finalizing }

/// 一次探测涉及的模块引用（供 UI 建通知条目）
@immutable
class ProbeModuleRef {
  final String id;
  final String displayName;

  const ProbeModuleRef(this.id, this.displayName);

  @override
  bool operator ==(Object other) =>
      other is ProbeModuleRef && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

/// 探测进度快照（队列线性执行：当前模块 + 队列全貌）
@immutable
class ProbeProgress {
  final ProbePhase phase;

  /// 本轮队列中的全部模块（含已完成/排队中）
  final List<ProbeModuleRef> queue;

  /// 当前正在执行三动作的模块
  final ProbeModuleRef? current;

  const ProbeProgress({
    required this.phase,
    required this.queue,
    this.current,
  });
}

/// 模块探测结果状态
enum ModuleProbeStatus {
  /// 成功（可能 0 个任务，但探测本身成功）
  ok,

  /// 探测失败（工具链缺失 / 依赖安装失败 / 执行失败 / 输出不可解析 / 超时）
  failed,

  /// 被用户取消
  cancelled,

  /// 因整轮探测超出时间预算而被跳过（尚未开始执行）
  skippedByBudget,
}

/// 单个模块的探测结果（结构化，失败必须显式携带原因）
@immutable
class ModuleProbeResult {
  final String moduleId;
  final ModuleProbeStatus status;
  final List<RunTask> tasks;

  /// 失败分类（用于 l10n 文案），status != failed 时为 null
  final NoticeFailure? failure;

  /// 失败细节：缺失的工具名、stderr 末尾等（技术信息，允许原样展示）
  final String? failureDetail;

  const ModuleProbeResult._({
    required this.moduleId,
    required this.status,
    this.tasks = const <RunTask>[],
    this.failure,
    this.failureDetail,
  });

  const ModuleProbeResult.ok(String moduleId, List<RunTask> tasks)
      : this._(moduleId: moduleId, status: ModuleProbeStatus.ok, tasks: tasks);

  const ModuleProbeResult.failed(
    String moduleId, {
    required NoticeFailure failure,
    String? detail,
  }) : this._(
          moduleId: moduleId,
          status: ModuleProbeStatus.failed,
          failure: failure,
          failureDetail: detail,
        );

  const ModuleProbeResult.cancelled(String moduleId)
      : this._(moduleId: moduleId, status: ModuleProbeStatus.cancelled);

  const ModuleProbeResult.skippedByBudget(String moduleId)
      : this._(moduleId: moduleId, status: ModuleProbeStatus.skippedByBudget);
}

/// 探测请求
@immutable
class ProjectProbeRequest {
  final Directory projectDir;
  final String? currentFilePath;

  /// 当前真实选中的容器系统名（必需）
  final String systemName;

  /// 仅探测指定模块（用于"重新同步真实任务"）
  final String? onlyModuleId;

  const ProjectProbeRequest({
    required this.projectDir,
    required this.systemName,
    this.currentFilePath,
    this.onlyModuleId,
  });
}

/// 探测报告：聚合所有模块结果 + 最终任务列表
@immutable
class ProjectProbeReport {
  final String systemName;
  final List<RunTask> detectedTasks;
  final Map<String, ModuleProbeResult> moduleResults;
  final DateTime finishedAt;

  /// 本轮队列涉及的模块总数（用于"已完成 X/Y 个模块"文案）
  final int totalModules;

  /// 是否因超出时间预算而中止
  final bool abortedByBudget;

  const ProjectProbeReport({
    required this.systemName,
    required this.detectedTasks,
    required this.moduleResults,
    required this.finishedAt,
    this.totalModules = 0,
    this.abortedByBudget = false,
  });

  static ProjectProbeReport empty(String systemName) => ProjectProbeReport(
        systemName: systemName,
        detectedTasks: const <RunTask>[],
        moduleResults: const <String, ModuleProbeResult>{},
        finishedAt: DateTime.now(),
      );

  /// 真正跑完（成功或失败）的模块数，不含被跳过/被取消的
  int get completedModules => moduleResults.values
      .where((r) => r.status == ModuleProbeStatus.ok || r.status == ModuleProbeStatus.failed)
      .length;

  bool get hasFailure =>
      moduleResults.values.any((r) => r.status == ModuleProbeStatus.failed);
}

/// 一次探测会话：承载进度、取消、缓存读写与容器执行能力。
///
/// 依赖能力（供模块的"依赖检测 / 自动补全"两个动作使用）：
/// * [isToolchainInstalled]：优先在宿主 rootfs 内快速判定，必要时回落到容器 `command -v`；
/// * [installToolchains]：按发行版家族复用 [ToolchainService] 的安装命令，
///   带长超时、可取消、逐行回传输出（供弹窗显示安装进度）。
class ProjectProbe {
  /// 整轮探测的默认时间预算：超过后不再出队新模块（剩余模块标记为"预算跳过"）
  static const Duration defaultBudget = Duration(minutes: 15);

  final ProjectProbeRequest request;
  final DistroManager distroManager;

  /// 本轮探测的时间预算
  final Duration budget;

  /// 取消令牌（取消后容器内的子进程会被立即杀掉）
  final HeadlessCancelToken cancelToken;

  /// 进度（null 表示已结束）
  final ValueNotifier<ProbeProgress?> progress;

  /// 安装过程最后一行输出（供弹窗副标题显示安装进度）
  final ValueNotifier<String?> installLine;

  bool _disposed = false;
  DateTime? _deadline;

  ProjectProbe({
    required this.request,
    required this.distroManager,
    this.budget = defaultBudget,
    HeadlessCancelToken? cancelToken,
    ValueNotifier<ProbeProgress?>? progress,
    ValueNotifier<String?>? installLine,
  })  : cancelToken = cancelToken ?? HeadlessCancelToken(),
        progress = progress ?? ValueNotifier<ProbeProgress?>(null),
        installLine = installLine ?? ValueNotifier<String?>(null);

  Directory get projectDir => request.projectDir;
  String? get currentFilePath => request.currentFilePath;
  String get systemName => request.systemName;
  String? get onlyModuleId => request.onlyModuleId;
  bool get isCancelled => cancelToken.isCancelled;
  bool get isDisposed => _disposed;

  /// 开始计时（由总调度在真正开跑时调用，排队/等待用户的时间不计入预算）
  void startBudget([Duration? override]) {
    _deadline = DateTime.now().add(override ?? budget);
  }

  /// 已耗时（未开始计时返回 Duration.zero）
  Duration get elapsed {
    final deadline = _deadline;
    if (deadline == null) return Duration.zero;
    final remaining = deadline.difference(DateTime.now());
    final used = budget - remaining;
    return used.isNegative ? Duration.zero : used;
  }

  /// 是否已超出时间预算
  bool get isBudgetExceeded {
    final deadline = _deadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  void cancel() => cancelToken.cancel();

  /// 在容器内静默执行命令（带取消支持 + 可选逐行输出）
  Future<ProcessResult?> runHeadless(
    String command, {
    Duration timeout = const Duration(seconds: 90),
    void Function(String chunk)? onStdout,
  }) {
    return distroManager.runHeadlessCommand(
      systemName: systemName,
      workspacePath: projectDir.path,
      command: command,
      timeout: timeout,
      cancelToken: cancelToken,
      onStdout: onStdout,
    );
  }

  /// 容器内是否存在指定二进制（无法确认且未被取消时返回 true，避免受限/单测环境误报缺失）
  Future<bool> hasCommand(String binary) async {
    if (isCancelled) return false;
    final result = await runHeadless(
      'command -v $binary >/dev/null 2>&1 && echo CE_OK',
      timeout: const Duration(seconds: 20),
    );
    if (isCancelled) return false;
    if (result == null) return true;
    return result.exitCode == 0 && result.stdout.toString().contains('CE_OK');
  }

  /// 依赖是否已安装（优先宿主侧 rootfs 快速判定，失败再回落容器检查）
  Future<bool> isToolchainInstalled(ToolchainRequirement requirement) async {
    if (isCancelled) return false;
    try {
      final rootDir = await distroManager.getSystemRootDir(systemName);
      if (rootDir.existsSync()) {
        return ToolchainService.isToolInstalledInRootfs(rootDir, requirement.checkBinary);
      }
    } catch (_) {
      // 宿主信息不可用 -> 回落容器内检查
    }
    return hasCommand(requirement.checkBinary);
  }

  /// 自动补全依赖：按发行版家族合成安装命令并在容器内执行
  ///
  /// 队列是线性执行的，因此同一时刻只会有一次安装，天然不会与其它模块争抢包管理器锁。
  /// 同一批缺失依赖合并成一条脚本执行（只取一次包管理器锁、只 update 一次）。
  Future<bool> installToolchains(List<String> toolchainKeys) async {
    if (isCancelled || _disposed || toolchainKeys.isEmpty) return false;

    final DistroFamily family;
    try {
      family = await distroManager.detectDistroFamily(systemName);
    } catch (_) {
      return false;
    }
    if (family == DistroFamily.unknown) return false;

    final commands = <String>[];
    for (final key in toolchainKeys) {
      final requirement = ToolchainService.supportedTools[key];
      final command = requirement?.getInstallCommand(family);
      if (command != null && command.trim().isNotEmpty) {
        commands.add(command);
      }
    }
    if (commands.isEmpty) return false;

    final script = commands.join(' && ');
    final result = await runHeadless(
      script,
      timeout: const Duration(minutes: 10),
      onStdout: (chunk) {
        final line = chunk.trim();
        if (line.isNotEmpty) setInstallLine(line);
      },
    );
    return result != null && result.exitCode == 0;
  }

  /// 更新安装进度行（带释放保护，避免取消/释放后写入已 dispose 的 notifier）
  void setInstallLine(String? line) {
    if (_disposed) return;
    installLine.value = line;
  }

  void reportProgress(ProbeProgress value) {
    if (isCancelled || _disposed) return;
    progress.value = value;
  }

  /// 释放（幂等：取消与正常结束路径都可能调用）
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    progress.dispose();
    installLine.dispose();
  }
}
