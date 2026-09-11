import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/project_history_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class ProjectHistoryWidget extends StatefulWidget {
  final ValueChanged<ProjectHistory>? onSelectHistory;

  const ProjectHistoryWidget({
    super.key,
    this.onSelectHistory,
  });

  /// 打开历史弹窗（不关闭后方的 Drawer）
  static Future<void> show(
    BuildContext context, {
    ValueChanged<ProjectHistory>? onSelectHistory,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return ProjectHistoryWidget(
          onSelectHistory: onSelectHistory,
        );
      },
    );
  }

  @override
  State<ProjectHistoryWidget> createState() =>
      _ProjectHistoryWidgetState();
}

class _ProjectHistoryWidgetState
    extends State<ProjectHistoryWidget> {
  List<ProjectHistory> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await ProjectHistoryService.instance.getFullHistory();
    if (mounted) {
      setState(() {
        _historyList = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteHistory(ProjectHistory item) async {
    final root = item.rootPath;
    if (root == null || root.isEmpty) return;

    // 1. 判断是否是当前正在打开的项目
    ProjectProvider? projectProvider;
    TabProvider? tabProvider;
    try {
      projectProvider = context.read<ProjectProvider>();
      tabProvider = context.read<TabProvider>();
    } catch (_) {}

    final currentRoot = projectProvider?.rootPath;
    final isCurrentProject = currentRoot != null && p.equals(p.normalize(currentRoot), p.normalize(root));

    // 2. 如果删除的是当前项目，先进行保存确认检查
    if (isCurrentProject && tabProvider != null) {
      final canProceed = await tabProvider.checkUnsavedChanges(context);
      if (!canProceed || !mounted) {
        // 用户取消或未通过保存流程，中止后续操作
        return;
      }
    }

    // 3. 弹出是否移除历史记录确认弹窗
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.deleteHistoryTitle,
      message: l10n.deleteHistoryMessage,
      confirmText: l10n.remove,
    );

    // 4. 只有两者均为 true（保存检查通过 且 确认移除历史记录），才真正去关闭当前项目并删除历史
    if (confirmed && mounted) {
      if (isCurrentProject && projectProvider != null) {
        await projectProvider.closeProject();
        if (!mounted) return;
      }

      await ProjectHistoryService.instance.removeHistory(root);
      await _loadHistory();
      if (mounted) {
        DialogUtils.showSuccessToast(context, l10n.historyRemoved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Title 区域：加粗、与 AppBar 相同背景颜色、右上角 X 关闭
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.projectHistory,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                    ),
                    tooltip: l10n.close,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. 列表区域
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _historyList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              l10n.noHistory,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: _historyList.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final item = _historyList[index];
                            final lastFile = item.lastOpenedFilePath;
                            final fileName = (lastFile != null &&
                                    lastFile.trim().isNotEmpty)
                                ? p.basename(lastFile)
                                : l10n.noOpenFile;
                            final rootDir = item.rootPath ?? l10n.unknownDirectory;

                            return InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelectHistory?.call(item);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    // 左边：历史图标
                                    Icon(
                                      Icons.history,
                                      size: 24,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),

                                    // 中间：撑开，占据最大空间，两行字
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 上面：大的上一次打开的文件名称
                                          Text(
                                            fileName,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          // 下面：一行小字表示根目录
                                          Text(
                                            rootDir,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 右边：删除历史记录的图标，点击后删除
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: theme.colorScheme.error,
                                      ),
                                      tooltip: l10n.deleteThisHistory,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteHistory(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}