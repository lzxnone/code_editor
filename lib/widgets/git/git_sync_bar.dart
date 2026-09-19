import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/git_error_mapper.dart';
import '../../views/git_account_management_view.dart';
import 'git_conflict_panel.dart';
import 'git_remote_management_sheet.dart';

/// Git 云端同步工具条
///
/// 承载 Fetch / Pull / Push / 发布分支 四个动作，并内联展示：
/// - 进行中的操作进度、已用时间与取消按钮
/// - 结构化错误提示与「一键修复」（先拉取再推送 / 放弃变基 / 去修账号）
/// - 可折叠的原始输出，便于排查
///
/// 计数（领先/落后）完全来自 `GitProvider.tracking`，即 ahead/behind 是
/// 决定按钮文案的唯一信号，避免出现与真实状态不一致的按钮。
class GitSyncBar extends StatefulWidget {
  const GitSyncBar({super.key});

  @override
  State<GitSyncBar> createState() => _GitSyncBarState();
}

class _GitSyncBarState extends State<GitSyncBar> {
  /// 云端操作开始时间，用于展示"已用时间"
  DateTime? _startedAt;

  /// 每秒刷新一次已用时间；仅在操作进行中存在
  Timer? _elapsedTicker;

  bool _showRawLog = false;

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool busy) {
    if (busy && _elapsedTicker == null) {
      _startedAt = DateTime.now();
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!busy && _elapsedTicker != null) {
      _elapsedTicker!.cancel();
      _elapsedTicker = null;
      _startedAt = null;
    }
  }

  /// 操作已进行的时长文案（大仓库长时间无百分比时，用户靠它判断是否卡死）
  String? _elapsedText(AppLocalizations l10n) {
    final started = _startedAt;
    if (started == null) return null;
    final elapsed = DateTime.now().difference(started);
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return l10n.gitElapsed(
      l10n.gitElapsedMinutesSeconds(elapsed.inMinutes, seconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final gitProvider = context.watch<GitProvider>();

    // 无仓库或 Git 未安装时不展示同步能力
    if (!gitProvider.hasProject ||
        !gitProvider.gitInstalled ||
        gitProvider.currentRepo == null) {
      return const SizedBox.shrink();
    }

    _syncTicker(gitProvider.isRemoteBusy);

    // 尚未配置任何远程仓库：给出引导而不是一排点了必然失败的按钮
    if (!gitProvider.hasRemote &&
        !(gitProvider.tracking?.hasUpstream ?? false)) {
      return _buildNoRemoteGuide(context, theme, l10n, gitProvider);
    }

    final pushTarget = gitProvider.pushTarget;
    final pushName = pushTarget.remote?.name ?? '';
    final upstreamName = gitProvider.tracking?.remoteName;
    final differs =
        pushName.isNotEmpty && upstreamName != null && pushName != upstreamName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 与上方「分支」行完全一致的结构：左侧占满的选择条 + 右侧 32×32 图标按钮。
        // 这样三行（分支 / 远程 / 进度）视觉对齐，宽度也天然不会溢出。
        Row(
          children: [
            Expanded(
              child: _buildRemoteSelectorBar(
                context,
                theme,
                l10n,
                gitProvider,
                differsFromUpstream: differs,
              ),
            ),
            const SizedBox(width: 6),
            _buildSyncButton(context, theme, l10n, gitProvider),
          ],
        ),
        // 冲突横幅放在远程行**下方**：它是一段需要处理的状态说明，
        // 放在远程行之上会把「分支 → 远程」这两行的对应关系打断。
        if (gitProvider.hasPendingOperation) ...[
          const SizedBox(height: 6),
          _buildConflictBanner(context, theme, l10n, gitProvider),
        ],
        // 推送目标与上游不一致时的提示：单独占一行。
        // 绝不能塞进上面的选择条 —— 那是第三个抢宽度的元素，会把远程名挤到溢出。
        if (differs) ...[
          const SizedBox(height: 4),
          _buildPushTargetNotice(
            theme,
            l10n,
            // differs 为真已保证 upstreamName 非空
            upstreamName: upstreamName,
            pushName: pushName,
          ),
        ],
        if (gitProvider.remoteProgress != null || gitProvider.isRemoteBusy) ...[
          const SizedBox(height: 6),
          _buildProgressRow(context, theme, l10n, gitProvider),
        ],
        if (gitProvider.lastRemoteError != null) ...[
          const SizedBox(height: 6),
          _buildErrorPanel(context, theme, l10n, gitProvider),
        ],
      ],
    );
  }

  /// fork 场景提示：拉取与推送指向不同远程，必须让用户看清
  ///
  /// 注意 l10n 的签名是 `(upstream, push)`，两个都是 String，
  /// 传反了编译器不会报错但文案会与事实相反 —— 已由测试锁住。
  Widget _buildPushTargetNotice(
    ThemeData theme,
    AppLocalizations l10n, {
    required String upstreamName,
    required String pushName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 13,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              l10n.gitPushTargetDiffersNotice(upstreamName, pushName),
              style: TextStyle(
                fontSize: 10.5,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 冲突横幅：把用户直接引到冲突解决面板
  ///
  /// 冲突时 push/pull 都无法推进，所以它必须排在远程行之前，
  /// 而不是和错误面板一起挤在下面。
  Widget _buildConflictBanner(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final colorScheme = theme.colorScheme;
    final remaining = provider.conflictState.conflictCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('git_conflict_banner'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => GitConflictPanel.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.merge_type, size: 15, color: colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  remaining > 0
                      ? l10n.gitConflictRemaining(remaining)
                      : l10n.gitConflictAllResolved,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 远程仓库选择条（样式与「分支」条保持一致，点击切换推送目标）
  Widget _buildRemoteSelectorBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider, {
    required bool differsFromUpstream,
  }) {
    final pushName = provider.pushTarget.remote?.name ?? '';
    final canPick = provider.remotes.length > 1;
    final busy = provider.isRemoteBusy;

    final reason = _pushReason(l10n, provider.pushTarget.source);
    final tooltip = differsFromUpstream
        ? '${l10n.gitPushTargetTooltip(pushName, reason)}\n${l10n.gitPushTargetDiffers}'
        : l10n.gitPushTargetTooltip(pushName, reason);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('git_remote_selector_bar'),
        borderRadius: BorderRadius.circular(6),
        onTap: (!canPick || busy)
            ? null
            : () => _showPushTargetPicker(context, l10n, provider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              // 与上游不一致时（fork：拉 upstream、推 origin）用强调边框提示
              color: differsFromUpstream
                  ? theme.colorScheme.tertiary.withValues(alpha: 0.7)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 14,
                  color: differsFromUpstream
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pushName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: differsFromUpstream
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurface,
                      fontFamily: 'JetBrains Mono',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canPick)
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 云同步按钮：与「分支」行右侧的更多按钮同尺寸、同形状，纯图标不带文字
  Widget _buildSyncButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final colorScheme = theme.colorScheme;
    final busy = provider.isRemoteBusy;
    final ahead = provider.aheadCount;
    final behind = provider.behindCount;
    final needsPublish = provider.needsPublishBranch;

    // 图标反映"当前该做什么"；计数交给菜单与下行进度，按钮本身保持纯图标
    final IconData icon;
    if (busy) {
      icon = Icons.sync;
    } else if (behind > 0) {
      icon = Icons.arrow_downward_rounded;
    } else if (ahead > 0) {
      icon = Icons.arrow_upward_rounded;
    } else {
      icon = Icons.cloud_outlined;
    }

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<_SyncAction>(
        key: const ValueKey('git_sync_cloud_button'),
        icon: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: colorScheme.primary,
                ),
              )
            : Icon(
                icon,
                size: 18,
                color: (behind > 0 || ahead > 0)
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
        tooltip: l10n.gitSyncCloudTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        enabled: !busy,
        onSelected: (action) {
          switch (action) {
            case _SyncAction.fetch:
              _runFetch(context, l10n, provider);
              break;
            case _SyncAction.pull:
              _runPull(context, l10n, provider);
              break;
            case _SyncAction.push:
              _runPush(context, l10n, provider);
              break;
            case _SyncAction.publish:
              _runPush(context, l10n, provider, setUpstream: true);
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _SyncAction.fetch,
            child: _buildMenuItem(
              icon: Icons.cloud_download_outlined,
              label: l10n.gitFetch,
              trailing: null,
            ),
          ),
          PopupMenuItem(
            value: _SyncAction.pull,
            child: _buildMenuItem(
              icon: Icons.arrow_downward_rounded,
              label: l10n.gitPull,
              trailing: behind > 0 ? '$behind' : null,
            ),
          ),
          if (needsPublish)
            PopupMenuItem(
              value: _SyncAction.publish,
              child: _buildMenuItem(
                icon: Icons.cloud_upload_outlined,
                label: l10n.gitPublishBranch,
                trailing: null,
              ),
            )
          else
            PopupMenuItem(
              value: _SyncAction.push,
              child: _buildMenuItem(
                icon: Icons.arrow_upward_rounded,
                label: l10n.gitPush,
                trailing: ahead > 0 ? '$ahead' : null,
              ),
            ),
        ],
      ),
    );
  }

  /// 云按钮菜单项：图标 + 文案 + 可选计数
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // ---------------------------- 无远程仓库引导 ----------------------------

  /// 未配置远程仓库时的引导视图
  ///
  /// 此时前进/后退按钮都没有意义（既无上游也无地址），因此整条同步条
  /// 退化为一个明确的「添加远程仓库」入口，避免用户点了才发现失败。
  Widget _buildNoRemoteGuide(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.gitNoRemoteConfigured,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            key: const ValueKey('git_sync_add_remote_guide_button'),
            onPressed: provider.isRemoteBusy
                ? null
                : () => GitRemoteManagementSheet.show(context),
            icon: const Icon(Icons.add, size: 14),
            label: Text(
              l10n.gitAddRemote,
              style: const TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------- 推送目标徽标 ----------------------------
  // ---------------------------- 进度与取消 ----------------------------

  Widget _buildProgressRow(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final progress = provider.remoteProgress;
    final elapsed = _elapsedText(l10n);

    // 大仓库长时间只输出无百分比的阶段（如 Enumerating objects）时，
    // 已用时间能让用户判断是在正常传输还是已经卡死。
    final String primaryText;
    if (progress != null && progress.raw.isNotEmpty) {
      primaryText = '${_phaseLabel(l10n, progress.phase)} · ${progress.raw}';
    } else if (provider.isRemoteBusy) {
      primaryText = l10n.gitRemoteOperationRunning;
    } else {
      primaryText = _phaseLabel(l10n, null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                elapsed == null ? primaryText : '$primaryText · $elapsed',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // 取消按钮：长耗时推送不必干等
            TextButton(
              key: const ValueKey('git_sync_cancel_button'),
              onPressed: provider.isRemoteBusy
                  ? () => provider.cancelRemoteOperation()
                  : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.gitCancelOperation,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            // 无百分比时为不确定态：git 的进度行并非每行都带百分比
            value: progress?.percent != null
                ? progress!.percent! / 100.0
                : null,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  String _phaseLabel(AppLocalizations l10n, String? phase) {
    return switch (phase) {
      'fetch' => l10n.gitFetch,
      'pull' => l10n.gitPull,
      'push' => l10n.gitPush,
      'auth' => l10n.gitCheckConnection,
      'remote' => l10n.gitRemoteManagement,
      _ => l10n.gitSync,
    };
  }

  /// 推送目标的解析原因文案（解释"为什么推到这个远程"）
  String _pushReason(AppLocalizations l10n, GitRemoteSource source) {
    return switch (source) {
      GitRemoteSource.pushRemote => l10n.gitPushReasonPushRemote,
      GitRemoteSource.pushDefault => l10n.gitPushReasonPushDefault,
      GitRemoteSource.upstream => l10n.gitPushReasonUpstream,
      GitRemoteSource.branchRemote => l10n.gitPushReasonBranchRemote,
      GitRemoteSource.fallback => l10n.gitPushReasonFallback,
      GitRemoteSource.manualOverride => l10n.gitPushReasonOverridden,
      GitRemoteSource.none => l10n.gitPushReasonFallback,
    };
  }

  /// 点击远程徽标切换推送目标（多远程时的显式选择）
  Future<void> _showPushTargetPicker(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final current = provider.pushTarget.remote?.name;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.gitTogglePushTarget,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final r in provider.remotes)
                ListTile(
                  key: ValueKey('git_push_target_${r.name}'),
                  dense: true,
                  leading: Icon(
                    r.name == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: r.name == current ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  // 地址与角色分两行：拼在一行会让 URL 把「上游（拉取）」
                  // 挤到完全看不见，而角色恰恰是 fork 场景下最关键的判断依据。
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.fetchUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (r.name == provider.tracking?.remoteName) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.gitRemoteRoleUpstream,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(r.name),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null || !context.mounted) return;
    provider.setPushTargetOverride(selected);
    DialogUtils.showToast(
      context,
      l10n.gitPushTargetChanged(selected),
      type: ToastType.info,
    );
  }

  // ---------------------------- 错误面板与一键修复 ----------------------------

  Widget _buildErrorPanel(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final error = provider.lastRemoteError!;
    final colorScheme = theme.colorScheme;
    final detail = error.rawDetail;
    final fixAction = error.fixAction;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 15, color: colorScheme.error),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  // 错误说明按类型取词，保持与项目其余部分一致的中英双语
                  error.kind.message(l10n),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _showRawLog = false);
                  provider.clearRemoteError();
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colorScheme.onErrorContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            error.kind.suggestion(l10n),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
            ),
          ),
          // 兜底场景保留 git 的原始错误行（英文原文，不做翻译，便于精确检索）
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'JetBrains Mono',
                color: colorScheme.onErrorContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 原始输出折叠入口：出错时完整输出是排查的第一手材料
              if (provider.remoteLog.isNotEmpty)
                InkWell(
                  key: const ValueKey('git_error_toggle_raw_log'),
                  onTap: () => setState(() => _showRawLog = !_showRawLog),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showRawLog ? Icons.expand_less : Icons.expand_more,
                        size: 14,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _showRawLog
                            ? l10n.gitHideOperationLog
                            : l10n.gitViewOperationLog,
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              // 不同错误给不同出口
              if (fixAction == GitErrorFixAction.pullThenPush)
                _FixAction(
                  key: const ValueKey('git_error_fix_pull_then_push'),
                  label: l10n.gitPullThenPush,
                  icon: Icons.sync,
                  onPressed: () => _runPullThenPush(context, l10n, provider),
                ),
              if (fixAction == GitErrorFixAction.fetchAndRetry)
                _FixAction(
                  key: const ValueKey('git_error_fix_fetch_retry'),
                  label: l10n.gitFetch,
                  icon: Icons.refresh,
                  onPressed: () => _runFetch(context, l10n, provider),
                ),
              if (fixAction == GitErrorFixAction.abortRebase)
                _FixAction(
                  key: const ValueKey('git_error_fix_abort_rebase'),
                  label: l10n.gitConflictAbort,
                  icon: Icons.undo,
                  onPressed: () => _runAbortRebase(context, l10n, provider),
                ),
              if (fixAction == GitErrorFixAction.openAccountManagement)
                _FixAction(
                  key: const ValueKey('git_error_fix_accounts'),
                  label: l10n.gitAccountManagement,
                  icon: Icons.manage_accounts_outlined,
                  onPressed: () => _openAccountManagement(context),
                ),
            ],
          ),
          if (_showRawLog && provider.remoteLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  provider.remoteLog,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------- 动作实现 ----------------------------

  Future<void> _runFetch(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final res = await provider.fetchRemote();
    if (!context.mounted) return;
    if (res.cancelled) {
      DialogUtils.showToast(
        context,
        l10n.gitRemoteOperationCancelled,
        type: ToastType.info,
      );
      return;
    }
    if (res.success) {
      DialogUtils.showToast(
        context,
        l10n.gitFetchSuccess,
        type: ToastType.success,
      );
    }
    // 失败时不在 toast 里重复错误：错误面板已给出结构化说明与修复入口
  }

  /// 拉取：有未提交改动时先让用户决定（提交 / 贮藏 / 取消），绝不静默 stash
  Future<void> _runPull(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    if (provider.totalChangedCount > 0) {
      final choice = await _showUncommittedChangesDialog(context, l10n);
      if (choice == null || choice == _PullWithChanges.cancel) return;
      if (choice == _PullWithChanges.commitFirst) return;

      final res = await provider.stashAndPull();
      if (!context.mounted) return;
      if (res.success) {
        DialogUtils.showToast(
          context,
          l10n.gitStashAndPullSuccess,
          type: ToastType.success,
        );
      }
      return;
    }

    final res = await provider.pull();
    if (!context.mounted) return;
    if (res.cancelled) {
      DialogUtils.showToast(
        context,
        l10n.gitRemoteOperationCancelled,
        type: ToastType.info,
      );
      return;
    }
    if (res.success) {
      // `Already up to date.` 是正常结果，不该报错也不该渲染成"有更新"
      final upToDate = res.stdout.toLowerCase().contains('up to date');
      DialogUtils.showToast(
        context,
        upToDate ? l10n.gitPullAlreadyUpToDate : l10n.gitPullSuccess,
        type: upToDate ? ToastType.info : ToastType.success,
      );
    }
  }

  Future<void> _runPush(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider, {
    bool setUpstream = false,
  }) async {
    final res = await provider.push(setUpstream: setUpstream);
    if (!context.mounted) return;
    if (res.cancelled) {
      DialogUtils.showToast(
        context,
        l10n.gitRemoteOperationCancelled,
        type: ToastType.info,
      );
      return;
    }
    if (res.success) {
      final upToDate =
          res.stdout.toLowerCase().contains('up-to-date') ||
          res.stderr.toLowerCase().contains('up-to-date');
      DialogUtils.showToast(
        context,
        upToDate ? l10n.gitPushUpToDate : l10n.gitPushSuccess,
        type: upToDate ? ToastType.info : ToastType.success,
      );
    }
  }

  Future<void> _runPullThenPush(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final res = await provider.pullThenPush();
    if (!context.mounted) return;
    if (res.success) {
      DialogUtils.showToast(
        context,
        l10n.gitPushSuccess,
        type: ToastType.success,
      );
    }
  }

  Future<void> _runAbortRebase(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.gitConflictAbort,
      message: l10n.gitConflictAbortConfirm,
      confirmText: l10n.gitConflictAbort,
    );
    if (!confirmed || !context.mounted) return;

    final res = await provider.abortRebase();
    if (!context.mounted) return;
    if (res.success) {
      DialogUtils.showToast(
        context,
        l10n.gitRemoteOperationCancelled,
        type: ToastType.info,
      );
    } else {
      DialogUtils.showToast(context, res.stderr, type: ToastType.error);
    }
  }

  void _openAccountManagement(BuildContext context) {
    // 账号管理页面已存在于设置中，这里通过既有入口跳转
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AccountManagementLauncher()),
    );
  }

  /// 未提交改动时的三选一（提交 / 贮藏并拉取 / 取消）
  Future<_PullWithChanges?> _showUncommittedChangesDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<_PullWithChanges>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.tertiary,
          ),
          title: Text(l10n.gitUncommittedChangesTitle),
          content: Text(l10n.gitUncommittedChangesDesc),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PullWithChanges.cancel),
              child: Text(l10n.gitUncommittedCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PullWithChanges.commitFirst),
              child: Text(l10n.gitUncommittedCommitFirst),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PullWithChanges.stashAndPull),
              child: Text(l10n.gitUncommittedStashAndPull),
            ),
          ],
        );
      },
    );
  }
}

/// 未提交改动时用户的选择
enum _PullWithChanges { stashAndPull, commitFirst, cancel }

/// 云按钮菜单中的动作类型
///
/// 用枚举而不是字符串：PopupMenuButton 的 value 若拼写错误会静默失效，
/// 枚举可以让编译器兜住。
enum _SyncAction { fetch, pull, push, publish }

/// 错误面板内的修复动作按钮
class _FixAction extends StatelessWidget {
  const _FixAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: theme.colorScheme.onErrorContainer,
        side: BorderSide(
          color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
    );
  }
}

/// 账号管理跳转：复用设置页已有的 GitAccountManagementView
class _AccountManagementLauncher extends StatelessWidget {
  const _AccountManagementLauncher();

  @override
  Widget build(BuildContext context) {
    return const GitAccountManagementView();
  }
}
