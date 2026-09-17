import 'package:flutter/foundation.dart';

/// 通知条目类型（决定默认配色与图标）
enum NoticeKind {
  /// 进行中（带进度圈）
  progress,

  /// 已完成
  success,

  /// 失败（默认保留到手动关闭）
  failure,

  /// 纯信息
  info,
}

/// 探测阶段（对应 l10n 文案 key）
///
/// 队列线性执行：每个模块依次经历
/// [queued] 排队 → [checkingDependency] 依赖检测 → [installingDependency] 自动补全
/// → [detecting] 执行探测 → [finalizing] 结果整理。
enum ProbeNoticePhase { queued, checkingDependency, installingDependency, detecting, finalizing }

/// 探测失败分类（对应 l10n 文案 key）
enum NoticeFailure {
  toolchainMissing,
  dependencyInstallFailed,
  executionFailed,
  unparsable,
  timeout,
}

/// 结构化通知文案：**模型层不含任何用户可见字符串**，
/// 实际文字由 UI 层 `resolveNoticeDisplay()` 通过 l10n 解析（禁止硬编码）。
sealed class NoticeText {
  const NoticeText();
}

/// 模块探测阶段文案：排队 / 依赖检测 / 自动补全 / 执行探测 / 整理
class ModulePhaseText extends NoticeText {
  /// 模块展示名（如 'Gradle'，来自 ProjectModule.displayName，不是文案）
  final String moduleDisplayName;
  final ProbeNoticePhase phase;

  /// 可选技术细节（例如安装过程中的最后一行输出），展示为副标题
  final String? detail;

  const ModulePhaseText({
    required this.moduleDisplayName,
    required this.phase,
    this.detail,
  });
}

/// 模块探测完成（带发现的任务数）
class ModuleDoneText extends NoticeText {
  final String moduleDisplayName;
  final int taskCount;

  const ModuleDoneText(this.moduleDisplayName, {this.taskCount = 0});
}

/// 整轮探测因超出时间预算而中止（已完成 [completed]/[total] 个模块）
class ProbeBudgetExceededText extends NoticeText {
  final int completed;
  final int total;

  const ProbeBudgetExceededText({required this.completed, required this.total});
}

/// 模块探测失败（带失败分类与可选技术细节，如缺失的工具名 / stderr 末尾）
class ModuleFailureText extends NoticeText {
  final String moduleDisplayName;
  final NoticeFailure failure;
  final String? detail;

  const ModuleFailureText({
    required this.moduleDisplayName,
    required this.failure,
    this.detail,
  });
}

/// 后台组件安装/卸载阶段通知（支持排队、执行中）
class ComponentInstallPhaseText extends NoticeText {
  final String componentName;
  final bool isUninstall;
  final bool isQueued;
  final String? detail;

  const ComponentInstallPhaseText({
    required this.componentName,
    this.isUninstall = false,
    this.isQueued = false,
    this.detail,
  });
}

/// 后台组件安装/卸载成功通知
class ComponentInstallDoneText extends NoticeText {
  final String componentName;
  final bool isUninstall;

  const ComponentInstallDoneText({
    required this.componentName,
    this.isUninstall = false,
  });
}

/// 后台组件安装/卸载失败通知
class ComponentInstallFailureText extends NoticeText {
  final String componentName;
  final bool isUninstall;
  final String? error;

  const ComponentInstallFailureText({
    required this.componentName,
    this.isUninstall = false,
    this.error,
  });
}

/// 一条通知（业务无关：任务探测、以后的下载/编译进度都可复用）
@immutable
class NoticeItem {
  /// 稳定标识（如 'probe:gradle'），用于插入/移除动画定位与就地更新
  final String id;

  final NoticeKind kind;
  final NoticeText text;

  /// 0..1 进度；null 表示不定进度
  final double? progress;

  /// 完成后是否必须由用户手动关闭（失败场景用）
  final bool sticky;

  /// 完成后延时自动关闭（成功场景用）
  final Duration? autoCloseAfter;

  /// 用户点击 × 时的附加动作（例如"正在探测"的通知被关闭 => 取消探测）
  final VoidCallback? onUserDismiss;

  /// 关闭前是否需要二次确认（破坏性操作，例如取消正在进行的探测）
  final bool confirmBeforeDismiss;

  const NoticeItem({
    required this.id,
    required this.kind,
    required this.text,
    this.progress,
    this.sticky = false,
    this.autoCloseAfter,
    this.onUserDismiss,
    this.confirmBeforeDismiss = false,
  });

  NoticeItem copyWith({
    NoticeKind? kind,
    NoticeText? text,
    double? progress,
    bool? sticky,
    Duration? autoCloseAfter,
    bool? confirmBeforeDismiss,
    bool clearProgress = false,
    bool clearAutoClose = false,
  }) {
    return NoticeItem(
      id: id,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      progress: clearProgress ? null : (progress ?? this.progress),
      sticky: sticky ?? this.sticky,
      autoCloseAfter:
          clearAutoClose ? null : (autoCloseAfter ?? this.autoCloseAfter),
      onUserDismiss: onUserDismiss,
      confirmBeforeDismiss: confirmBeforeDismiss ?? this.confirmBeforeDismiss,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoticeItem &&
      other.id == id &&
      other.kind == kind &&
      other.text == text &&
      other.progress == progress &&
      other.sticky == sticky &&
      other.autoCloseAfter == autoCloseAfter;

  @override
  int get hashCode =>
      Object.hash(id, kind, text, progress, sticky, autoCloseAfter);
}
