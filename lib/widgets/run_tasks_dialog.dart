import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/run_task.dart';

/// 运行任务选择弹窗（带顶部搜索栏、区分系统探测与自定义任务，点击直接调度执行）
class RunTasksDialog extends StatefulWidget {
  final List<RunTask> customTasks;
  final List<RunTask> detectedTasks;
  final String? lastRunTaskId;
  final ValueChanged<RunTask> onTaskSelected;
  final VoidCallback onEditCustomTasks;

  const RunTasksDialog({
    super.key,
    required this.customTasks,
    required this.detectedTasks,
    this.lastRunTaskId,
    required this.onTaskSelected,
    required this.onEditCustomTasks,
  });

  static Future<void> show({
    required BuildContext context,
    required List<RunTask> customTasks,
    required List<RunTask> detectedTasks,
    String? lastRunTaskId,
    required ValueChanged<RunTask> onTaskSelected,
    required VoidCallback onEditCustomTasks,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => RunTasksDialog(
        customTasks: customTasks,
        detectedTasks: detectedTasks,
        lastRunTaskId: lastRunTaskId,
        onTaskSelected: onTaskSelected,
        onEditCustomTasks: onEditCustomTasks,
      ),
    );
  }

  @override
  State<RunTasksDialog> createState() => _RunTasksDialogState();
}

class _RunTasksDialogState extends State<RunTasksDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(RunTask task, AppLocalizations l10n) {
    if (_searchQuery.isEmpty) return true;
    final name = task.getLocalizedName(l10n);
    final desc = task.getLocalizedDescription(l10n);
    return name.toLowerCase().contains(_searchQuery) ||
        task.command.toLowerCase().contains(_searchQuery) ||
        desc.toLowerCase().contains(_searchQuery) ||
        (task.description?.toLowerCase().contains(_searchQuery) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final filteredCustom = widget.customTasks.where((t) => _matchesQuery(t, l10n)).toList();
    final filteredDetected = widget.detectedTasks.where((t) => _matchesQuery(t, l10n)).toList();
    final hasAny = filteredCustom.isNotEmpty || filteredDetected.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏：简洁标题 + 编辑按钮 + 关闭 X
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.runTasks,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_outlined),
                    tooltip: l10n.editCustomTasksTooltip,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onEditCustomTasks();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 搜索输入框
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchTasksHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // 任务展示列表
              Expanded(
                child: !hasAny
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? l10n.noTasksAvailable : l10n.noMatchingTasks,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView(
                        children: [
                          if (filteredDetected.isNotEmpty) ...[
                            _buildSectionHeader(context, l10n.systemDetectedTasks, Icons.radar_outlined),
                            ...filteredDetected.map((task) => _buildTaskItem(context, task, l10n)),
                            const SizedBox(height: 8),
                          ],
                          if (filteredCustom.isNotEmpty) ...[
                            _buildSectionHeader(context, l10n.userCustomTasks, Icons.person_outline),
                            ...filteredCustom.map((task) => _buildTaskItem(context, task, l10n)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, RunTask task, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isLastRun = widget.lastRunTaskId != null && widget.lastRunTaskId == task.id;

    final cardColor = isLastRun
        ? Colors.green.withValues(alpha: 0.15)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final borderColor = isLastRun
        ? Colors.green.withValues(alpha: 0.8)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    final localizedDesc = task.getLocalizedDescription(l10n).trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: isLastRun ? 1.5 : 1.0),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.getLocalizedName(l10n),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isLastRun ? Colors.green.shade700 : null,
                ),
              ),
            ),
            if (isLastRun)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.history,
                  size: 14,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
        subtitle: localizedDesc.isNotEmpty
            ? Text(
                localizedDesc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: CircleAvatar(
          radius: 16,
          backgroundColor: isLastRun
              ? Colors.green.withValues(alpha: 0.25)
              : theme.colorScheme.primaryContainer,
          foregroundColor: isLastRun ? Colors.green : theme.colorScheme.onPrimaryContainer,
          child: const Icon(Icons.play_arrow, size: 20),
        ),
        onTap: () {
          Navigator.of(context).pop();
          widget.onTaskSelected(task);
        },
      ),
    );
  }
}
