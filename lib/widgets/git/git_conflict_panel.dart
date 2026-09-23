import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../providers/tab_provider.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/git_error_mapper.dart';
import '../../views/main_view.dart';
import 'git_conflict_resolve_page.dart';

/// 冲突解决面板（底部弹出）
///
/// 设计要点：
/// 1. 解决冲突的本质就是「改文件 + `git add`」，因此打开文件一律**强制从磁盘
///    重载**（Git 在冲突时直接改写了工作区文件并写入标记）。
/// 2. `--ours/--theirs` 在 rebase 下含义与直觉相反，因此按钮文案按**实际操作
///    类型**翻译，绝不写「我的 / 对方的」。
/// 3. 「继续」在仍有未解决文件时禁用，避免 git 立刻再次停下造成误解。
class GitConflictPanel extends StatelessWidget {
  const GitConflictPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GitConflictPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<GitProvider>();
    final state = provider.conflictState;

    if (!state.isPending) {
      // 面板打开期间操作已完成（例如用户点了继续）→ 自动关闭
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final baselineLabel = _baselineLabel(provider, l10n);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.merge_type,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.gitConflictTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _operationLabel(l10n, state.operation),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 状态条：未解决 / 可继续
            _buildStatusBar(theme, l10n, provider),

            // 「提交为空」提示：明确告诉用户可以跳过，而不是让用户猜
            if (provider.conflictNotice == 'emptyCommit') ...[
              const SizedBox(height: 6),
              _buildEmptyCommitHint(theme, l10n, provider),
            ],

            const SizedBox(height: 8),
            if (state.files.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.files.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) => _ConflictFileTile(
                    file: state.files[index],
                    baselineLabel: baselineLabel,
                  ),
                ),
              ),

            const SizedBox(height: 10),
            _buildActions(context, theme, l10n, provider),
          ],
        ),
      ),
    );
  }

  /// 基线侧的名称 —— 用实际来源代替「我的/对方的」，避免 rebase 下误导
  String _baselineLabel(GitProvider provider, AppLocalizations l10n) {
    final upstream = provider.tracking?.upstream;
    if (upstream != null && upstream.isNotEmpty) return upstream;
    return l10n.gitConflictTakeBaselineGeneric;
  }

  String _operationLabel(AppLocalizations l10n, GitPendingOperation op) {
    return switch (op) {
      GitPendingOperation.rebase => l10n.gitConflictRebaseInProgress,
      GitPendingOperation.merge => l10n.gitConflictMergeInProgress,
      GitPendingOperation.cherryPick => l10n.gitConflictCherryPickInProgress,
      GitPendingOperation.revert => l10n.gitConflictRevertInProgress,
      GitPendingOperation.none => '',
    };
  }

  Widget _buildStatusBar(
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final remaining = provider.conflictState.conflictCount;
    final done = remaining == 0;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: done
                ? colorScheme.onPrimaryContainer
                : colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              done
                  ? l10n.gitConflictAllResolved
                  : l10n.gitConflictRemaining(remaining),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCommitHint(
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.gitConflictEmptyCommitNotice,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          InkWell(
            onTap: provider.clearConflictNotice,
            child: Icon(
              Icons.close,
              size: 14,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider provider,
  ) {
    final state = provider.conflictState;
    final canContinue = state.canContinue;

    return Row(
      children: [
        // 放弃：始终可用
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('git_conflict_abort_button'),
            onPressed: () => _abort(context, l10n, provider),
            icon: const Icon(Icons.undo, size: 15),
            label: Text(
              l10n.gitConflictAbort,
              style: const TextStyle(fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // 跳过：仅 rebase / cherry-pick / revert 有意义
        if (state.operation != GitPendingOperation.merge)
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('git_conflict_skip_button'),
              onPressed: () => _skip(context, l10n, provider),
              icon: const Icon(Icons.skip_next, size: 15),
              label: Text(
                l10n.gitConflictSkip,
                style: const TextStyle(fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        const SizedBox(width: 6),
        // 继续：仍有未解决文件时禁用
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('git_conflict_continue_button'),
            onPressed: canContinue ? () => _continue(context, l10n, provider) : null,
            icon: const Icon(Icons.play_arrow, size: 15),
            label: Text(
              l10n.gitConflictContinue,
              style: const TextStyle(fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _continue(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final res = await provider.continueOperation();
    if (!context.mounted) return;
    if (res.success) {
      DialogUtils.showToast(context, l10n.gitConflictContinueSuccess, type: ToastType.success);
    } else if (provider.conflictNotice != 'emptyCommit') {
      // 失败原因优先用结构化错误；无结构化错误时退回原文
      final err = provider.lastRemoteError;
      DialogUtils.showToast(
        context,
        err != null ? err.kind.message(l10n) : res.stderr,
        type: ToastType.error,
      );
    }
  }

  Future<void> _skip(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final res = await provider.skipOperation();
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success ? l10n.gitConflictSkipSuccess : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _abort(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.gitConflictAbort,
      message: l10n.gitConflictAbortConfirm,
      confirmText: l10n.gitConflictAbort,
      icon: Icons.undo,
    );
    if (!confirmed || !context.mounted) return;

    final res = await provider.abortOperation();
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success ? l10n.gitConflictAbortSuccess : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }
}

/// 单个冲突文件条目
class _ConflictFileTile extends StatelessWidget {
  const _ConflictFileTile({required this.file, required this.baselineLabel});

  final GitConflictedFile file;
  final String baselineLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<GitProvider>();
    final colorScheme = theme.colorScheme;

    return ListTile(
      key: ValueKey('git_conflict_file_${file.relativePath}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        file.isBinary ? Icons.data_object : Icons.description_outlined,
        size: 18,
        color: colorScheme.error,
      ),
      title: Text(
        file.relativePath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontFamily: 'JetBrains Mono'),
      ),
      subtitle: Text(
        _typeLabel(l10n, file.type),
        style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<String>(
        key: ValueKey('git_conflict_actions_${file.relativePath}'),
        tooltip: l10n.gitConflictTitle,
        onSelected: (action) => _handle(context, l10n, provider, action),
        itemBuilder: (_) => [
          if (file.canEditManually) ...[
            PopupMenuItem(
              value: 'resolve',
              child: _menuRow(
                Icons.merge_type,
                l10n.gitConflictResolveTitle,
              ),
            ),
            PopupMenuItem(
              value: 'open',
              child: _menuRow(Icons.open_in_new_rounded, l10n.gitConflictOpenFile),
            ),
          ],
          PopupMenuItem(
            value: 'ours',
            child: _menuRow(
              Icons.arrow_downward_rounded,
              l10n.gitConflictTakeBaseline(baselineLabel),
            ),
          ),
          PopupMenuItem(
            value: 'theirs',
            child: _menuRow(
              Icons.arrow_upward_rounded,
              l10n.gitConflictTakeIncoming,
            ),
          ),
          if (file.canEditManually)
            PopupMenuItem(
              value: 'recreate',
              child: _menuRow(Icons.refresh, l10n.gitConflictRecreate),
            ),
          PopupMenuItem(
            value: 'resolved',
            child: _menuRow(Icons.check, l10n.gitConflictContinue),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: _menuRow(Icons.delete_outline, l10n.gitConflictRemoveFile),
          ),
        ],
      ),
      // 点击文件条目直接进入三方解决页（这是主要路径）
      onTap: file.canEditManually
          ? () => _openResolvePage(context, provider)
          : null,
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _typeLabel(AppLocalizations l10n, GitConflictType type) {
    return switch (type) {
      GitConflictType.bothModified => l10n.gitConflictTypeBothModified,
      GitConflictType.bothAdded => l10n.gitConflictTypeBothAdded,
      GitConflictType.deletedByUs => l10n.gitConflictTypeDeletedByUs,
      GitConflictType.deletedByThem => l10n.gitConflictTypeDeletedByThem,
      GitConflictType.addedByUs => l10n.gitConflictTypeAddedByUs,
      GitConflictType.addedByThem => l10n.gitConflictTypeAddedByThem,
      GitConflictType.bothDeleted => l10n.gitConflictTypeBothDeleted,
      GitConflictType.unknown => l10n.gitConflictTypeUnknown,
    };
  }

  Future<void> _handle(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    String action,
  ) async {
    switch (action) {
      case 'resolve':
        await _openResolvePage(context, provider);
        break;
      case 'open':
        await _openInEditor(context, provider);
        break;
      case 'ours':
        await _takeSide(context, l10n, provider, useOurs: true);
        break;
      case 'theirs':
        await _takeSide(context, l10n, provider, useOurs: false);
        break;
      case 'recreate':
        final res = await provider.recreateConflictMarkers(file);
        if (!context.mounted) return;
        DialogUtils.showToast(
          context,
          res.success ? l10n.gitConflictRecreateDone : res.stderr,
          type: res.success ? ToastType.success : ToastType.error,
        );
        break;
      case 'resolved':
        final res = await provider.markConflictResolved(file);
        if (!context.mounted) return;
        DialogUtils.showToast(
          context,
          res.success
              ? l10n.gitConflictResolved(file.relativePath)
              : res.stderr,
          type: res.success ? ToastType.success : ToastType.error,
        );
        break;
      case 'remove':
        final confirmed = await DialogUtils.showDestructiveConfirmDialog(
          context,
          title: l10n.gitConflictRemoveFile,
          message: file.relativePath,
          icon: Icons.delete_outline,
        );
        if (!confirmed || !context.mounted) return;
        await provider.removeConflictedFile(file);
        break;
    }
  }

  /// 打开三方冲突解决页（逐块选择，由程序替换而非人工删标记）
  Future<void> _openResolvePage(BuildContext context, GitProvider provider) async {
    await provider.refreshConflictState();
    if (!context.mounted) return;

    await Navigator.of(context).push(
      GitConflictResolvePage.route(file: file, gitProvider: provider),
    );
    // 返回后刷新：用户可能已在解决页里标记完成
    await provider.refreshConflictState();
  }

  /// 在编辑器中打开冲突文件
  ///
  /// **必须先强制从磁盘重载**：Git 冲突时直接改写了工作区文件并写入标记，
  /// 而 openFile 对已打开的 tab 不会重载，用户会看到没有标记的旧内容。
  Future<void> _openInEditor(BuildContext context, GitProvider provider) async {
    final tabProvider = context.read<TabProvider>();
    await provider.refreshConflictState();
    await tabProvider.reloadTabFromDisk(file.absolutePath);
    await tabProvider.openFile(file.absolutePath);
    if (!context.mounted) return;

    // 先收起 bottom sheet 冲突面板，再关闭侧边栏抽屉，直达主代码编辑区
    Navigator.of(context).pop();
    MainView.closeDrawerIfOpen();
  }

  Future<void> _takeSide(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider, {
    required bool useOurs,
  }) async {
    final res = await provider.takeConflictSide(file, useOurs: useOurs);
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success ? l10n.gitConflictResolved(file.relativePath) : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }
}
