import '../l10n/app_localizations.dart';
import '../models/notice_item.dart';

/// 通知的展示文案：标题 + 可选副标题。
/// 所有文字都来自 l10n，模型层只提供结构化 key 与参数。
class NoticeDisplay {
  final String title;
  final String? subtitle;

  const NoticeDisplay({required this.title, this.subtitle});
}

/// 把结构化 [NoticeText] 解析为本地化文案
NoticeDisplay resolveNoticeDisplay(AppLocalizations l10n, NoticeText text) {
  switch (text) {
    case ModulePhaseText():
      final title = switch (text.phase) {
        ProbeNoticePhase.queued => l10n.probePhaseQueued(text.moduleDisplayName),
        ProbeNoticePhase.checkingDependency =>
          l10n.probePhaseCheckingDependency(text.moduleDisplayName),
        ProbeNoticePhase.installingDependency =>
          l10n.probePhaseInstallingDependency(text.moduleDisplayName),
        ProbeNoticePhase.detecting => l10n.probeBannerDetecting(text.moduleDisplayName),
        ProbeNoticePhase.finalizing => l10n.probeBannerFinalizing,
      };
      return NoticeDisplay(title: title, subtitle: text.detail);
    case ModuleDoneText():
      return NoticeDisplay(
        title: l10n.probeDoneWithCount(text.moduleDisplayName, text.taskCount),
      );
    case ProbeBudgetExceededText():
      return NoticeDisplay(
        title: l10n.probeBudgetExceededTitle,
        subtitle: l10n.probeBudgetExceededMessage(text.completed, text.total),
      );
    case ModuleFailureText():
      final subtitle = switch (text.failure) {
        NoticeFailure.toolchainMissing =>
          l10n.probeFailureToolchainMissing(text.detail ?? ''),
        NoticeFailure.dependencyInstallFailed =>
          l10n.probeFailureDependencyInstallFailed(text.detail ?? ''),
        NoticeFailure.executionFailed =>
          l10n.probeFailureExecutionFailed(text.detail ?? ''),
        NoticeFailure.unparsable => l10n.probeFailureUnparsable,
        NoticeFailure.timeout => l10n.probeFailureTimeout,
      };
      return NoticeDisplay(
        title: l10n.probeFailedTitle(text.moduleDisplayName),
        subtitle: subtitle,
      );
    case ComponentInstallPhaseText():
      final title = text.isQueued
          ? l10n.componentQueued(text.componentName)
          : (text.isUninstall
              ? l10n.uninstallingComponent(text.componentName)
              : l10n.installingComponent(text.componentName));
      return NoticeDisplay(title: title, subtitle: text.detail);
    case ComponentInstallDoneText():
      final title = text.isUninstall
          ? l10n.uninstallComponentSuccess(text.componentName)
          : l10n.installComponentSuccess(text.componentName);
      return NoticeDisplay(title: title);
    case ComponentInstallFailureText():
      final title = text.isUninstall
          ? l10n.uninstallComponentFailed(text.error ?? '')
          : l10n.installComponentFailed(text.error ?? '');
      return NoticeDisplay(title: title, subtitle: text.error);
  }
}
