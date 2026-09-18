import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../providers/tab_provider.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/file_icon_utils.dart';
import 'git_diff_page.dart';
import 'git_graph_painter.dart';

/// Git 版本控制侧边栏面板组件
class GitPanelWidget extends StatefulWidget {
  const GitPanelWidget({super.key});

  @override
  State<GitPanelWidget> createState() => _GitPanelWidgetState();
}

class _GitPanelWidgetState extends State<GitPanelWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commitMsgController = TextEditingController();
  final GlobalKey _branchBarKey = GlobalKey();
  bool _stagedExpanded = true;
  bool _unstagedExpanded = true;
  bool _graphExpanded = true;
  bool _showTagsInSelector = false;
  GitProvider? _gitProvider;

  @override
  void initState() {
    super.initState();
    final gitProvider = context.read<GitProvider>();
    _gitProvider = gitProvider;
    _stagedExpanded = gitProvider.stagedExpanded;
    _unstagedExpanded = gitProvider.unstagedExpanded;
    _graphExpanded = gitProvider.graphExpanded;
    _showTagsInSelector = gitProvider.showTagsInSelector;
    _commitMsgController.text = gitProvider.commitMessage;

    _commitMsgController.addListener(_onCommitMsgChanged);
    _scrollController.addListener(_onScrollChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients && gitProvider.scrollOffset > 0) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final target = gitProvider.scrollOffset.clamp(0.0, maxScroll);
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gitProvider = context.read<GitProvider>();
  }

  void _onCommitMsgChanged() {
    _gitProvider?.setCommitMessage(_commitMsgController.text);
  }

  void _onScrollChanged() {
    if (_scrollController.hasClients) {
      _gitProvider?.setScrollOffset(_scrollController.offset);
    }
  }

  @override
  void dispose() {
    _commitMsgController.removeListener(_onCommitMsgChanged);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _commitMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final gitProvider = context.watch<GitProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作栏
        _buildHeader(context, theme, l10n, gitProvider),

        // 主体内容区
        Expanded(
          child: _buildBody(context, theme, l10n, gitProvider),
        ),
      ],
    );
  }

  /// 顶部标题与操作栏
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    final repos = gitProvider.repositories;
    final currentRepo = gitProvider.currentRepo;
    final branch = gitProvider.currentBranch;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 第一行：标题、多仓库切换、刷新、更多操作
              Row(
                children: [
                  // 标题
                  Text(
                    l10n.drawerTabGit,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 多仓库切换下拉菜单（若发现多个仓库）
                  if (repos.length > 1) ...[
                    PopupMenuButton<String>(
                      tooltip: l10n.gitSwitchRepo,
                      initialValue: gitProvider.currentRepoPath,
                      onSelected: (path) => gitProvider.switchRepository(path),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.source_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                currentRepo?.name ?? l10n.gitRepository,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (ctx) {
                        return repos.map((r) {
                          final isSelected = r.rootPath == gitProvider.currentRepoPath;
                          return PopupMenuItem<String>(
                            value: r.rootPath,
                            child: Row(
                              children: [
                                Icon(
                                  r.isRoot ? Icons.folder_special_outlined : Icons.folder_outlined,
                                  size: 16,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        r.name,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (r.currentBranch != null)
                                        Text(
                                          r.currentBranch!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                    const SizedBox(width: 6),
                  ],

                  const Spacer(),

                  // 刷新按钮
                  if (gitProvider.hasProject && gitProvider.gitInstalled)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: l10n.gitRefresh,
                      visualDensity: VisualDensity.compact,
                      onPressed: gitProvider.isLoading ? null : () => gitProvider.refresh(),
                    ),

                  // 更多操作 (撤销上次提交、Stash 贮藏等)
                  if (gitProvider.hasProject && gitProvider.gitInstalled && gitProvider.hasRepository)
                    _buildMoreActionsMenu(context, theme, l10n, gitProvider),
                ],
              ),

              // 第二行：当前分支/标签栏与行更多操作按钮
              if (currentRepo != null && branch != null && branch.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildBranchSelectorBar(context, theme, l10n, gitProvider, branch),
                    ),
                    const SizedBox(width: 6),
                    _buildBranchRowMoreButton(context, theme, l10n, gitProvider, branch),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 独立分支/标签切换条组件（Title 下方独占一行，点击展开下拉分支/标签菜单）
  Widget _buildBranchSelectorBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
    String currentBranch,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _branchBarKey,
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showBranchOrTagSelectorMenu(context, theme, l10n, gitProvider, currentBranch),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                gitProvider.isCurrentRefTag ? Icons.local_offer_outlined : Icons.call_split_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentBranch,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'JetBrains Mono',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (gitProvider.stashCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'stash: ${gitProvider.stashCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开分支或标签选择下拉菜单（包含顶部单选按钮与列表）
  Future<void> _showBranchOrTagSelectorMenu(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
    String currentBranch,
  ) async {
    final renderBox = _branchBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissBranchMenu',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogCtx, anim1, anim2) {
        return _BranchOrTagSelectorMenuDialog(
          offset: offset,
          size: size,
          theme: theme,
          l10n: l10n,
          gitProvider: gitProvider,
          currentBranch: currentBranch,
          initialShowTags: _showTagsInSelector,
          onModeChanged: (isTag) {
            _showTagsInSelector = isTag;
            gitProvider.setShowTagsInSelector(isTag);
          },
          onSwitchBranch: (b) async {
            final res = await gitProvider.switchBranch(b);
            if (context.mounted) {
              if (res.success) {
                DialogUtils.showToast(context, l10n.gitSwitchBranchSuccess(b), type: ToastType.success);
              } else if (res.stderr.isNotEmpty) {
                DialogUtils.showToast(context, res.stderr, type: ToastType.error);
              }
            }
          },
          onSwitchTag: (t) async {
            final res = await gitProvider.switchTag(t);
            if (context.mounted) {
              if (res.success) {
                DialogUtils.showToast(context, l10n.gitSwitchTagSuccess(t), type: ToastType.success);
              } else if (res.stderr.isNotEmpty) {
                DialogUtils.showToast(context, res.stderr, type: ToastType.error);
              }
            }
          },
        );
      },
    );
  }

  /// 行分支/标签更多按钮（动态展示分支操作或标签操作，去除背景与边框）
  Widget _buildBranchRowMoreButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
    String currentBranch,
  ) {
    final colorScheme = theme.colorScheme;
    final isTag = gitProvider.isCurrentRefTag;
    final canDeleteBranch = gitProvider.branches.where((b) => b != currentBranch).isNotEmpty;
    final canDeleteTag = gitProvider.tags.isNotEmpty;

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        key: const ValueKey('branch_row_more_button'),
        icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
        tooltip: isTag ? l10n.gitTags : l10n.gitBranches,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (action) {
          switch (action) {
            case 'create_branch':
              _showCreateBranchDialog(context, l10n, gitProvider);
              break;
            case 'delete_branch':
              _showDeleteBranchDialog(context, l10n, gitProvider, currentBranch);
              break;
            case 'create_tag':
              _showCreateTagDialog(context, l10n, gitProvider);
              break;
            case 'delete_tag':
              _showDeleteTagDialog(context, l10n, gitProvider);
              break;
          }
        },
        itemBuilder: (ctx) {
          final branchItems = [
            PopupMenuItem(
              value: 'create_branch',
              child: Row(
                children: [
                  Icon(Icons.call_split_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.gitCreateBranch, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete_branch',
              enabled: canDeleteBranch,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(l10n.gitDeleteBranch, style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
                ],
              ),
            ),
          ];

          final tagItems = [
            PopupMenuItem(
              value: 'create_tag',
              child: Row(
                children: [
                  Icon(Icons.local_offer_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.gitCreateTag, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete_tag',
              enabled: canDeleteTag,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(l10n.gitDeleteTag, style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
                ],
              ),
            ),
          ];

          if (isTag) {
            return [
              ...tagItems,
              const PopupMenuDivider(),
              ...branchItems,
            ];
          } else {
            return [
              ...branchItems,
              const PopupMenuDivider(),
              ...tagItems,
            ];
          }
        },
      ),
    );
  }

  /// 顶部更多操作菜单（撤销上次提交、Stash 等）
  Widget _buildMoreActionsMenu(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: l10n.gitMoreActions,
      padding: EdgeInsets.zero,
      onSelected: (action) async {
        switch (action) {
          case 'undo_commit':
            _handleUndoLastCommit(context, l10n, gitProvider);
            break;
          case 'stash':
            _handleStash(context, l10n, gitProvider);
            break;
          case 'stash_pop':
            _handleStashPop(context, l10n, gitProvider);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'undo_commit',
          enabled: gitProvider.commits.isNotEmpty,
          child: Row(
            children: [
              const Icon(Icons.undo, size: 16),
              const SizedBox(width: 8),
              Text(l10n.gitUndoLastCommit, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'stash',
          enabled: gitProvider.changedFiles.isNotEmpty,
          child: Row(
            children: [
              const Icon(Icons.archive_outlined, size: 16),
              const SizedBox(width: 8),
              Text(l10n.gitStashChanges, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'stash_pop',
          enabled: gitProvider.stashCount > 0,
          child: Row(
            children: [
              const Icon(Icons.unarchive_outlined, size: 16),
              const SizedBox(width: 8),
              Text(
                '${l10n.gitStashPop}${gitProvider.stashCount > 0 ? ' (${gitProvider.stashCount})' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 创建新分支对话框
  Future<void> _showCreateBranchDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.gitCreateBranch),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.gitBranchNameHint,
            isDense: true,
          ),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(dialogCtx).pop(trimmed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogCtx).pop(trimmed);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      final res = await gitProvider.createBranch(name);
      if (context.mounted) {
        if (res.success) {
          DialogUtils.showToast(
            context,
            l10n.gitCreateBranchSuccess(name),
            type: ToastType.success,
          );
        } else if (res.stderr.isNotEmpty) {
          DialogUtils.showToast(context, res.stderr, type: ToastType.error);
        }
      }
    }
  }

  /// 删除分支对话框
  Future<void> _showDeleteBranchDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
    String currentBranch,
  ) async {
    final deletableBranches = gitProvider.branches.where((b) => b != currentBranch).toList();
    if (deletableBranches.isEmpty) {
      DialogUtils.showToast(context, l10n.gitCannotDeleteCurrentBranch, type: ToastType.warning);
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _ItemSelectionDialog(
        title: l10n.gitSelectBranchToDelete,
        searchHint: l10n.gitSearchBranches,
        emptyText: l10n.gitNoBranches,
        itemIcon: Icons.call_split_rounded,
        items: deletableBranches,
        cancelText: l10n.cancel,
      ),
    );

    if (selected != null && context.mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.gitDeleteBranch),
          content: Text(l10n.gitDeleteBranchConfirm(selected)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.gitDeleteBranch),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        final res = await gitProvider.deleteBranch(selected);
        if (context.mounted) {
          if (res.success) {
            DialogUtils.showToast(context, l10n.gitDeleteBranchSuccess(selected), type: ToastType.success);
          } else if (res.stderr.isNotEmpty) {
            DialogUtils.showToast(context, res.stderr, type: ToastType.error);
          }
        }
      }
    }
  }

  /// 创建新标签对话框
  Future<void> _showCreateTagDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.gitCreateTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.gitTagNameHint,
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              decoration: InputDecoration(
                hintText: l10n.gitTagMessageHint,
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.of(dialogCtx).pop(true);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final tagName = nameCtrl.text.trim();
      final msg = msgCtrl.text.trim();
      final res = await gitProvider.createTag(tagName, message: msg.isNotEmpty ? msg : null);
      if (context.mounted) {
        if (res.success) {
          DialogUtils.showToast(context, l10n.gitCreateTagSuccess(tagName), type: ToastType.success);
        } else if (res.stderr.isNotEmpty) {
          DialogUtils.showToast(context, res.stderr, type: ToastType.error);
        }
      }
    }
  }

  /// 删除标签对话框
  Future<void> _showDeleteTagDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    if (gitProvider.tags.isEmpty) {
      DialogUtils.showToast(context, l10n.gitNoTags, type: ToastType.warning);
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _ItemSelectionDialog(
        title: l10n.gitSelectTagToDelete,
        searchHint: l10n.gitSearchTags,
        emptyText: l10n.gitNoTags,
        itemIcon: Icons.local_offer_outlined,
        items: gitProvider.tags,
        cancelText: l10n.cancel,
      ),
    );

    if (selected != null && context.mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.gitDeleteTag),
          content: Text(l10n.gitDeleteTagConfirm(selected)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.gitDeleteTag),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        final res = await gitProvider.deleteTag(selected);
        if (context.mounted) {
          if (res.success) {
            DialogUtils.showToast(context, l10n.gitDeleteTagSuccess(selected), type: ToastType.success);
          } else if (res.stderr.isNotEmpty) {
            DialogUtils.showToast(context, res.stderr, type: ToastType.error);
          }
        }
      }
    }
  }

  /// 处理撤销上一次提交
  Future<void> _handleUndoLastCommit(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.gitUndoLastCommit),
        content: Text(l10n.gitUndoLastCommitConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final res = await gitProvider.undoLastCommit();
      if (context.mounted) {
        if (res.success) {
          DialogUtils.showToast(
            context,
            l10n.gitUndoLastCommitSuccess,
            type: ToastType.success,
          );
        } else if (res.stderr.isNotEmpty) {
          DialogUtils.showToast(context, res.stderr, type: ToastType.error);
        }
      }
    }
  }

  /// 处理暂存工作区修改 (Stash)
  Future<void> _handleStash(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final res = await gitProvider.stash();
    if (context.mounted) {
      if (res.success) {
        DialogUtils.showToast(
          context,
          l10n.gitStashChangesSuccess,
          type: ToastType.success,
        );
      } else if (res.stderr.isNotEmpty) {
        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
      }
    }
  }

  /// 处理恢复最近暂存 (Stash Pop)
  Future<void> _handleStashPop(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    if (gitProvider.stashCount == 0) {
      DialogUtils.showToast(context, l10n.gitNoStashFound, type: ToastType.info);
      return;
    }
    final res = await gitProvider.stashPop();
    if (context.mounted) {
      if (res.success) {
        DialogUtils.showToast(
          context,
          l10n.gitStashPopSuccess,
          type: ToastType.success,
        );
      } else if (res.stderr.isNotEmpty) {
        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
      }
    }
  }

  /// 面板主体内容路由调度
  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    // 1. 未打开工程目录
    if (!gitProvider.hasProject) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.folder_open_rounded,
        title: l10n.noOpenDirectory,
        subtitle: null,
      );
    }

    // 2. 宿主/容器未安装 Git 命令行工具
    if (!gitProvider.gitInstalled) {
      return _buildGitNotInstalledView(context, theme, l10n, gitProvider);
    }

    // 3. 正在加载中且尚未加载出任何仓库
    if (gitProvider.isLoading && !gitProvider.hasRepository) {
      return const Center(child: CircularProgressIndicator());
    }

    // 4. 当前工程未初始化 Git 仓库
    if (!gitProvider.hasRepository) {
      return _buildUninitializedRepoView(context, theme, l10n, gitProvider);
    }

    // 5. 已检测到 Git 仓库，展示变更与状态列表
    return _buildRepoChangesView(context, theme, l10n, gitProvider);
  }

  /// Git 未安装时的引导与同步安装视图
  Widget _buildGitNotInstalledView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    return LayoutBuilder(
      builder: (layoutCtx, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // 图标（温和友好的源码分支图标，避免警示性红黄色）
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.alt_route_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 标题：温和提示需要安装 Git
                    Text(
                      l10n.gitNeedInstall,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // 页面下方明显的【安装 Git】按钮
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          l10n.gitInstallAction,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _handleInstallGit(this.context, l10n, gitProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 点击安装 Git 按钮，弹出同步阻塞 Dialog 并执行安装
  Future<void> _handleInstallGit(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    // 弹出同步阻塞 Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            content: Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.gitInstallingProgress,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 执行后台安装
    final result = await gitProvider.installGit();

    // 关闭同步阻塞 Dialog
    if (navigator.mounted) {
      navigator.pop();
    }

    if (mounted) {
      if (result.success) {
        DialogUtils.showToast(
          this.context,
          l10n.gitInstallSuccess,
          type: ToastType.success,
        );
      } else {
        DialogUtils.showToast(
          this.context,
          l10n.gitInstallFailed(result.stderr),
          type: ToastType.error,
        );
      }
    }
  }

  /// 未初始化 Git 仓库视图
  Widget _buildUninitializedRepoView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // 图标
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.merge_type_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 标题
                    Text(
                      l10n.gitNoRepoFound,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // 说明
                    Text(
                      l10n.gitNoRepoDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // 页面下方明显的【初始化 Git 仓库】按钮
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(
                          l10n.gitInitRepo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _handleInitRepository(this.context, l10n, gitProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 点击初始化按钮，弹出同步阻塞 Dialog 并执行 git init
  Future<void> _handleInitRepository(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    // 弹出同步阻塞 Dialog（不可随意点击空白区域退出）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            content: Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.gitInitializing,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 执行后台初始化
    final result = await gitProvider.initRepository();

    // 关闭同步阻塞 Dialog
    if (navigator.mounted) {
      navigator.pop();
    }

    if (mounted) {
      if (result.success) {
        DialogUtils.showToast(
          this.context,
          l10n.gitInitSuccess,
          type: ToastType.success,
        );
      } else {
        DialogUtils.showToast(
          this.context,
          l10n.gitInitFailed(result.stderr),
          type: ToastType.error,
        );
      }
    }
  }

  /// 已初始化仓库的变更列表视图
  Widget _buildRepoChangesView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    final colorScheme = theme.colorScheme;
    final staged = gitProvider.stagedFiles;
    final unstaged = gitProvider.unstagedFiles;
    final tabProvider = context.read<TabProvider?>();

    return Column(
      children: [
        // 顶部提交信息输入区与提交按钮
        _buildCommitBox(context, theme, l10n, gitProvider),
        const Divider(height: 1, thickness: 0.8),

        // 虚拟化列表区 (暂存更改 + 更改 + 图表，真正按需渲染视口内元素，防卡顿)
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              // 1. 暂存区变更 (Staged Changes)
              if (staged.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    theme: theme,
                    title: l10n.gitStagedChanges,
                    count: staged.length,
                    isExpanded: _stagedExpanded,
                    onToggle: () {
                      setState(() {
                        _stagedExpanded = !_stagedExpanded;
                        gitProvider.setStagedExpanded(_stagedExpanded);
                      });
                    },
                    actions: [
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        splashRadius: 12,
                        icon: Icon(Icons.remove, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                        tooltip: l10n.gitUnstageAll,
                        onPressed: () async {
                          final res = await gitProvider.unstageAll();
                          if (mounted && !res.success && res.stderr.isNotEmpty) {
                            DialogUtils.showToast(this.context, res.stderr, type: ToastType.error);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (_stagedExpanded)
                  SliverList.builder(
                    itemCount: staged.length,
                    itemBuilder: (ctx, index) => _buildFileItem(
                      context,
                      theme,
                      l10n,
                      staged[index],
                      tabProvider,
                      gitProvider,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
              ],

              // 2. 工作区变更 (Unstaged Changes)
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  theme: theme,
                  title: l10n.gitChanges,
                  count: unstaged.length,
                  isExpanded: _unstagedExpanded,
                  onToggle: () {
                    setState(() {
                      _unstagedExpanded = !_unstagedExpanded;
                      gitProvider.setUnstagedExpanded(_unstagedExpanded);
                    });
                  },
                  actions: [
                    if (unstaged.isNotEmpty) ...[
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        splashRadius: 12,
                        icon: Icon(Icons.undo_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                        tooltip: l10n.gitDiscardAll,
                        onPressed: () => _handleDiscardAllUnstaged(context, l10n, gitProvider),
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        splashRadius: 12,
                        icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                        tooltip: l10n.gitStageAll,
                        onPressed: () async {
                          final res = await gitProvider.stageAll();
                          if (mounted && !res.success && res.stderr.isNotEmpty) {
                            DialogUtils.showToast(this.context, res.stderr, type: ToastType.error);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (_unstagedExpanded) ...[
                if (unstaged.isEmpty && staged.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 6, 16, 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.gitNoChanges,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: unstaged.length,
                    itemBuilder: (ctx, index) => _buildFileItem(
                      context,
                      theme,
                      l10n,
                      unstaged[index],
                      tabProvider,
                      gitProvider,
                    ),
                  ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // 3. 提交历史图表 (Graph)
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  theme: theme,
                  title: l10n.gitGraphTitle,
                  count: gitProvider.totalCommitsCount > 0
                      ? gitProvider.totalCommitsCount
                      : gitProvider.commits.length,
                  isExpanded: _graphExpanded,
                  onToggle: () {
                    setState(() {
                      _graphExpanded = !_graphExpanded;
                      gitProvider.setGraphExpanded(_graphExpanded);
                    });
                  },
                  actions: [
                    // 全部展开按钮
                    IconButton(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      iconSize: 15,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      splashRadius: 12,
                      icon: Icon(
                        Icons.unfold_more_rounded,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      tooltip: l10n.gitExpandAll,
                      onPressed: () async {
                        if (!_graphExpanded) {
                          setState(() {
                            _graphExpanded = true;
                            gitProvider.setGraphExpanded(true);
                          });
                        }
                        await gitProvider.loadAllCommits();
                      },
                    ),
                    // 刷新按钮
                    IconButton(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      iconSize: 15,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      splashRadius: 12,
                      icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                      tooltip: l10n.gitRefresh,
                      onPressed: () => gitProvider.refresh(),
                    ),
                  ],
                ),
              ),
              if (_graphExpanded) ...[
                if (gitProvider.commits.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildNoCommitsItem(theme, l10n),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: gitProvider.commits.length,
                    itemBuilder: (ctx, index) => _buildCommitItem(
                      context,
                      theme,
                      l10n,
                      gitProvider.commits[index],
                      index == 0,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCommitsFooter(context, theme, l10n, gitProvider),
                  ),
                ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ],
    );
  }

  /// 图表底部懒加载与分页统计栏（对标搜索结果懒加载设计）
  Widget _buildCommitsFooter(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    if (gitProvider.commits.isEmpty) return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;
    final loaded = gitProvider.commits.length;
    final total = gitProvider.totalCommitsCount > 0 ? gitProvider.totalCommitsCount : loaded;
    final hasMore = gitProvider.hasMoreCommits;
    final remaining = (total - loaded).clamp(0, total);

    if (gitProvider.isLoadingMoreCommits) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.gitLoadingMoreCommits,
              style: TextStyle(
                fontSize: 11.5,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (hasMore) {
      final nextCount = math.min(50, remaining);
      return InkWell(
        onTap: () => gitProvider.loadMoreCommits(count: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.expand_more, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.gitLoadMoreCommits(nextCount),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l10n.gitLoadedCommitsCount(loaded, total),
                style: TextStyle(
                  fontSize: 10.5,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 已全部加载完毕提示
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 13,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 5),
          Text(
            l10n.gitAllCommitsLoaded(loaded),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  /// 提交控制台（输入框与提交按钮）
  Widget _buildCommitBox(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) {
    final colorScheme = theme.colorScheme;
    final hasChanges = gitProvider.totalChangedCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _commitMsgController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: l10n.gitCommitMessageHint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
              ),
            ),
            onSubmitted: (_) => _handleCommit(context, l10n, gitProvider),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(
              l10n.gitCommit,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: (!hasChanges || gitProvider.isLoading)
                ? null
                : () => _handleCommit(context, l10n, gitProvider),
          ),
        ],
      ),
    );
  }

  /// 处理 Commit 提交
  Future<void> _handleCommit(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final msg = _commitMsgController.text.trim();
    if (msg.isEmpty) {
      DialogUtils.showToast(context, l10n.gitNoCommitMessage, type: ToastType.warning);
      return;
    }

    // 如果暂存区为空但工作区有改动，提示是否全部暂存并直接提交
    if (gitProvider.stagedFiles.isEmpty && gitProvider.unstagedFiles.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.gitCommit),
          content: Text(l10n.gitNoStagedChangesToCommit),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.gitStageAllAndCommit),
            ),
          ],
        ),
      );

      if (confirm != true || !context.mounted) return;

      final stageRes = await gitProvider.stageAll();
      if (!stageRes.success) {
        if (context.mounted) {
          DialogUtils.showToast(context, stageRes.stderr, type: ToastType.error);
        }
        return;
      }
    }

    final res = await gitProvider.commit(msg);
    if (!context.mounted) return;

    if (res.success) {
      _commitMsgController.clear();
      gitProvider.setCommitMessage('');
      DialogUtils.showToast(context, l10n.gitCommitSuccess, type: ToastType.success);
    } else {
      DialogUtils.showToast(
        context,
        l10n.gitCommitFailed(res.stderr.isNotEmpty ? res.stderr : res.stdout),
        type: ToastType.error,
      );
    }
  }

  /// 处理放弃单个文件的更改 (Discard Changes)
  Future<void> _handleDiscardFile(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
    GitFileStatus file,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.gitDiscardConfirm),
        content: Text(l10n.gitDiscardConfirmDesc(file.fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.gitDiscardChange),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final res = await gitProvider.discardFile(file);
      if (context.mounted && !res.success && res.stderr.isNotEmpty) {
        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
      }
    }
  }

  /// 处理放弃所有未暂存更改
  Future<void> _handleDiscardAllUnstaged(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider gitProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.gitDiscardAllChangesTitle),
        content: Text(l10n.gitDiscardAllChangesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.gitDiscardAll),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final res = await gitProvider.discardAllUnstaged();
      if (context.mounted && !res.success && res.stderr.isNotEmpty) {
        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
      }
    }
  }



  /// 变更分组标头（支持折叠/展开、数量胶囊及右侧操作按钮列表）
  Widget _buildSectionHeader({
    required ThemeData theme,
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
    List<Widget> actions = const [],
  }) {
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          children: [
            // 折叠指示箭头
            Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),

            // 分组标题
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),

            const Spacer(),

            // 操作按钮列表 (紧凑排布)
            for (final action in actions) ...[
              action,
              const SizedBox(width: 2),
            ],

            const SizedBox(width: 2),

            // 变更数量胶囊徽标
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 暂无提交条目
  Widget _buildNoCommitsItem(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      child: Text(
        l10n.gitNoCommits,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// 单个提交历史项（VS Code 风格线性图表与提交元信息）
  Widget _buildCommitItem(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitCommit commit,
    bool isFirst,
  ) {
    final colorScheme = theme.colorScheme;
    final maxLane = [commit.lane, ...commit.activeLanes, ...commit.outgoingLanes]
        .fold<int>(0, (m, l) => l > m ? l : m);
    final graphWidth = (maxLane + 1) * 14.0 + 16.0;

    return InkWell(
      onTap: () => _showCommitDetails(context, theme, l10n, commit),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.only(right: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 线性拓扑图形 (动态撑满行高从 y=0 到 y=height，上下行无缝连接 0 间隙，RepaintBoundary 绘制隔离)
              RepaintBoundary(
                child: SizedBox(
                  width: graphWidth,
                  child: CustomPaint(
                    painter: GitGraphPainter(
                      commit: commit,
                      isFirstCommit: isFirst,
                      colorScheme: colorScheme,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 提交内容与元信息 (垂直边距移入内部，不影响外层拓扑连线的顶天立地)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ref 引用胶囊标签 (多标签采用 Wrap 自动折行，杜绝横向溢出)
                      if (commit.refs.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (final ref in commit.refs)
                              _buildRefBadge(context, theme, ref),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],

                      // 提交信息 (充分利用整行宽度，最多两行并省略溢出)
                      Text(
                        commit.subject,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 2),

                      // 短哈希 • 作者 • 相对时间
                      Row(
                        children: [
                          Text(
                            commit.shortHash,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ' • ${commit.authorName} • ${commit.relativeDate}',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Git Ref 引用徽标（分支、HEAD、Tag 标签）
  Widget _buildRefBadge(BuildContext context, ThemeData theme, String ref) {
    final colorScheme = theme.colorScheme;
    final isTag = ref.contains('tag:');
    final isHead = ref.startsWith('HEAD');
    final label = ref.replaceFirst('HEAD -> ', '').replaceFirst('tag: ', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isHead
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isHead
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTag
                ? Icons.label_outline_rounded
                : (isHead ? Icons.navigation_rounded : Icons.fork_right_rounded),
            size: 11,
            color: isHead ? colorScheme.primary : colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isHead ? colorScheme.primary : colorScheme.onSecondaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出提交详情面板
  void _showCommitDetails(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitCommit commit,
  ) {
    final colorScheme = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部滑动指示条
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 标题
                Row(
                  children: [
                    Icon(Icons.commit_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.gitCommitDetails,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 提交描述
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    commit.subject,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),

                // 提交完整哈希
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.gitCommitHash,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            commit.hash,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: l10n.gitCopyHash,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: commit.hash));
                        Navigator.of(ctx).pop();
                        DialogUtils.showToast(context, l10n.gitHashCopied, type: ToastType.info);
                      },
                    ),
                  ],
                ),
                const Divider(height: 16, thickness: 0.6),

                // 作者（独占一行，长邮箱完整展示）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gitCommitAuthor,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      commit.authorEmail.isNotEmpty
                          ? '${commit.authorName} <${commit.authorEmail}>'
                          : commit.authorName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 16, thickness: 0.6),

                // 提交日期（单独开一行）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gitCommitDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      commit.relativeDate,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),

                if (commit.parentHashes.isNotEmpty) ...[
                  const Divider(height: 16, thickness: 0.6),
                  Text(
                    l10n.gitCommitParent,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: commit.parentHashes.map((p) {
                      final shortP = p.length > 7 ? p.substring(0, 7) : p;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shortP,
                          style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: colorScheme.primary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 单个文件变更条目
  Widget _buildFileItem(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitFileStatus file,
    TabProvider? tabProvider,
    GitProvider gitProvider,
  ) {
    final (badgeText, badgeColor) = _getStatusBadge(file.statusType);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GitDiffPage(
              file: file,
              gitProvider: gitProvider,
            ),
          ),
        );
      },
      onLongPress: () => _showFileContextMenu(context, theme, l10n, file, tabProvider, gitProvider),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26.0, 3.0, 10.0, 3.0),
        child: Row(
          children: [
            // 文件类型图标
            Icon(
              FileIconUtils.getIcon(name: file.fileName, isDirectory: false),
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),

            const SizedBox(width: 8),

            // 文件名与所在路径 (垂直排布：文件名在上，所在相对路径在下方)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.fileName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (file.directoryPath.isNotEmpty)
                    Text(
                      file.directoryPath,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // 单文件暂存 (+) 或取消暂存 (-) 按钮（紧凑化）
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              iconSize: 15,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              splashRadius: 12,
              icon: Icon(
                file.isStaged ? Icons.remove : Icons.add,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              tooltip: file.isStaged ? l10n.gitUnstageChange : l10n.gitStageChange,
              onPressed: () async {
                if (file.isStaged) {
                  final res = await gitProvider.unstageFile(file.relativePath);
                  if (context.mounted && !res.success && res.stderr.isNotEmpty) {
                    DialogUtils.showToast(context, res.stderr, type: ToastType.error);
                  }
                } else {
                  final res = await gitProvider.stageFile(file.relativePath);
                  if (context.mounted && !res.success && res.stderr.isNotEmpty) {
                    DialogUtils.showToast(context, res.stderr, type: ToastType.error);
                  }
                }
              },
            ),

            const SizedBox(width: 4),

            // Git 状态标徽 (M, U, A, D, R, !)
            Container(
              constraints: const BoxConstraints(minWidth: 16),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文件项长按上下文菜单 (包含暂存/取消暂存、放弃更改、添加到 .gitignore、打开文件等)
  void _showFileContextMenu(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GitFileStatus file,
    TabProvider? tabProvider,
    GitProvider gitProvider,
  ) {
    final isUntracked = file.statusType == GitFileStatusType.untracked;
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部拖动条
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 文件头部信息
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        FileIconUtils.getIcon(name: file.fileName, isDirectory: false),
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (file.directoryPath.isNotEmpty)
                              Text(
                                file.directoryPath,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 16),

                // 查看差异 (Diff View)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.difference_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  title: Text(l10n.gitDiff),
                  onTap: () {
                    Navigator.of(bottomSheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GitDiffPage(
                          file: file,
                          gitProvider: gitProvider,
                        ),
                      ),
                    );
                  },
                ),

                // 暂存 / 取消暂存
                ListTile(
                  dense: true,
                  leading: Icon(
                    file.isStaged ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  title: Text(file.isStaged ? l10n.gitUnstageChange : l10n.gitStageChange),
                  onTap: () async {
                    Navigator.of(bottomSheetCtx).pop();
                    if (file.isStaged) {
                      final res = await gitProvider.unstageFile(file.relativePath);
                      if (context.mounted && !res.success && res.stderr.isNotEmpty) {
                        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
                      }
                    } else {
                      final res = await gitProvider.stageFile(file.relativePath);
                      if (context.mounted && !res.success && res.stderr.isNotEmpty) {
                        DialogUtils.showToast(context, res.stderr, type: ToastType.error);
                      }
                    }
                  },
                ),

                // 放弃更改 (撤销更改)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.undo_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    l10n.gitDiscardChange,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetCtx).pop();
                    _handleDiscardFile(context, l10n, gitProvider, file);
                  },
                ),

                // 未跟踪文件可添加到 .gitignore
                if (!file.isStaged && isUntracked)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.visibility_off_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(l10n.gitAddToGitignore),
                    onTap: () async {
                      Navigator.of(bottomSheetCtx).pop();
                      final ok = await gitProvider.addToGitignore(file.relativePath);
                      if (context.mounted && ok) {
                        DialogUtils.showToast(context, l10n.gitAddedToGitignore, type: ToastType.success);
                      }
                    },
                  ),

                // 打开文件
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.gitOpenFile),
                  onTap: () async {
                    Navigator.of(bottomSheetCtx).pop();
                    if (tabProvider != null) {
                      await tabProvider.openFile(file.path);
                    }
                    if (context.mounted) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 获取状态徽标文案与颜色
  (String, Color) _getStatusBadge(GitFileStatusType type) {
    switch (type) {
      case GitFileStatusType.modified:
        return ('M', Colors.orange);
      case GitFileStatusType.untracked:
        return ('U', Colors.green);
      case GitFileStatusType.added:
        return ('A', Colors.green);
      case GitFileStatusType.deleted:
        return ('D', Colors.red);
      case GitFileStatusType.renamed:
        return ('R', Colors.blue);
      case GitFileStatusType.unmerged:
        return ('!', Colors.purple);
      default:
        return ('?', Colors.grey);
    }
  }

  /// 通用空状态布局
  Widget _buildEmptyState({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 独立分支与标签下拉浮层（支持按需虚拟化加载与搜索过滤）
class _BranchOrTagSelectorMenuDialog extends StatefulWidget {
  final Offset offset;
  final Size size;
  final ThemeData theme;
  final AppLocalizations l10n;
  final GitProvider gitProvider;
  final String currentBranch;
  final bool initialShowTags;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onSwitchBranch;
  final ValueChanged<String> onSwitchTag;

  const _BranchOrTagSelectorMenuDialog({
    required this.offset,
    required this.size,
    required this.theme,
    required this.l10n,
    required this.gitProvider,
    required this.currentBranch,
    required this.initialShowTags,
    required this.onModeChanged,
    required this.onSwitchBranch,
    required this.onSwitchTag,
  });

  @override
  State<_BranchOrTagSelectorMenuDialog> createState() => _BranchOrTagSelectorMenuDialogState();
}

class _BranchOrTagSelectorMenuDialogState extends State<_BranchOrTagSelectorMenuDialog> {
  late bool _showTags;
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _showTags = widget.initialShowTags;
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;
    final branches = widget.gitProvider.branches.isNotEmpty
        ? widget.gitProvider.branches
        : [widget.currentBranch];
    final tags = widget.gitProvider.tags;

    final query = _searchQuery.trim().toLowerCase();
    final filteredBranches = query.isEmpty
        ? branches
        : branches.where((b) => b.toLowerCase().contains(query)).toList();
    final filteredTags = query.isEmpty
        ? tags
        : tags.where((t) => t.toLowerCase().contains(query)).toList();

    return Stack(
      children: [
        Positioned(
          left: widget.offset.dx,
          top: widget.offset.dy + widget.size.height + 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: widget.size.width.clamp(200.0, 280.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 顶部单选按钮（分支 vs 标签）
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      child: RadioGroup<bool>(
                        groupValue: _showTags,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _showTags = v;
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                            widget.onModeChanged(v);
                          }
                        },
                        child: Row(
                          children: [
                            // 分支单选
                            Expanded(
                              child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  _showTags = false;
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                });
                                widget.onModeChanged(false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Radio<bool>(
                                      value: false,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                      widget.l10n.gitBranches,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !_showTags ? FontWeight.bold : FontWeight.normal,
                                        color: !_showTags ? colorScheme.primary : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 标签单选
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  _showTags = true;
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                });
                                widget.onModeChanged(true);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Radio<bool>(
                                      value: true,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                      widget.l10n.gitTags,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _showTags ? FontWeight.bold : FontWeight.normal,
                                        color: _showTags ? colorScheme.primary : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                    // 搜索过滤框（分支与标签均提供即时搜索过滤）
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            hintText: _showTags ? widget.l10n.gitSearchTags : widget.l10n.gitSearchBranches,
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            prefixIcon: Icon(Icons.search, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),

                    const Divider(height: 1, thickness: 0.8),

                    // 下方列表（按需虚拟化构建）
                    _showTags
                        ? _buildTagList(context, colorScheme, filteredTags)
                        : _buildBranchList(context, colorScheme, filteredBranches),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchList(BuildContext dialogCtx, ColorScheme colorScheme, List<String> branches) {
    if (branches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Text(
            widget.l10n.gitNoBranches,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    const double itemHeight = 36.0;
    final double listHeight = (branches.length * itemHeight).clamp(36.0, 240.0);

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        itemExtent: itemHeight,
        itemCount: branches.length,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemBuilder: (ctx, index) {
          final b = branches[index];
          final isCurrent = b == widget.currentBranch;
          return InkWell(
            onTap: () {
              Navigator.of(dialogCtx).pop();
              if (!isCurrent) {
                widget.onSwitchBranch(b);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.call_split_rounded,
                    size: 15,
                    color: isCurrent ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check, size: 16, color: colorScheme.primary),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagList(BuildContext dialogCtx, ColorScheme colorScheme, List<String> tags) {
    if (tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Center(
          child: Text(
            widget.l10n.gitNoTags,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    const double itemHeight = 36.0;
    final double listHeight = (tags.length * itemHeight).clamp(36.0, 240.0);

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        itemExtent: itemHeight,
        itemCount: tags.length,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemBuilder: (ctx, index) {
          final t = tags[index];
          final isCurrent = widget.currentBranch == t || widget.currentBranch.contains(t);
          return InkWell(
            onTap: () {
              Navigator.of(dialogCtx).pop();
              widget.onSwitchTag(t);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 15,
                    color: isCurrent ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check, size: 16, color: colorScheme.primary),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 支持即时搜索过滤与虚拟化滚动的单项选择弹窗（用于删除分支/标签选择）
class _ItemSelectionDialog extends StatefulWidget {
  final String title;
  final String searchHint;
  final String emptyText;
  final IconData itemIcon;
  final List<String> items;
  final String cancelText;

  const _ItemSelectionDialog({
    required this.title,
    required this.searchHint,
    required this.emptyText,
    required this.itemIcon,
    required this.items,
    required this.cancelText,
  });

  @override
  State<_ItemSelectionDialog> createState() => _ItemSelectionDialogState();
}

class _ItemSelectionDialogState extends State<_ItemSelectionDialog> {
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.items
        : widget.items.where((i) => i.toLowerCase().contains(query)).toList();

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = (screenHeight - viewInsets.bottom - 240.0).clamp(60.0, 320.0);

    const double itemHeight = 40.0;
    final double listHeight = (filtered.length * itemHeight).clamp(40.0, availableHeight);

    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 搜索输入框
            SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(Icons.search, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.8),
            // 虚拟化列表
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    widget.emptyText,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    itemExtent: itemHeight,
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => Navigator.of(context).pop(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Icon(widget.itemIcon, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}
