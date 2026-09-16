import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project_task_table.dart';
import '../models/run_task.dart';
import '../models/run_task_type.dart';
import '../providers/run_provider.dart';

/// 运行任务选择弹窗（带顶部搜索栏、区分系统探测与自定义任务、支持模块深度重新同步、点击直接调度执行）
class RunTasksDialog extends StatefulWidget {
  final List<RunTask> customTasks;
  final List<RunTask> detectedTasks;
  final String? lastRunTaskId;
  final ValueChanged<RunTask> onTaskSelected;
  final VoidCallback onEditCustomTasks;
  final void Function(String moduleId)? onSyncModule;
  final bool Function(String moduleId)? isSyncingModule;

  const RunTasksDialog({
    super.key,
    required this.customTasks,
    required this.detectedTasks,
    this.lastRunTaskId,
    required this.onTaskSelected,
    required this.onEditCustomTasks,
    this.onSyncModule,
    this.isSyncingModule,
  });

  static Future<void> show({
    required BuildContext context,
    required List<RunTask> customTasks,
    required List<RunTask> detectedTasks,
    String? lastRunTaskId,
    required ValueChanged<RunTask> onTaskSelected,
    required VoidCallback onEditCustomTasks,
    void Function(String moduleId)? onSyncModule,
    bool Function(String moduleId)? isSyncingModule,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => RunTasksDialog(
        customTasks: customTasks,
        detectedTasks: detectedTasks,
        lastRunTaskId: lastRunTaskId,
        onTaskSelected: onTaskSelected,
        onEditCustomTasks: onEditCustomTasks,
        onSyncModule: onSyncModule,
        isSyncingModule: isSyncingModule,
      ),
    );
  }

  @override
  State<RunTasksDialog> createState() => _RunTasksDialogState();
}

class _RunTasksDialogState extends State<RunTasksDialog> {
  /// 内存中持久化各类型任务段的折叠状态（生命周期内常驻，不写磁盘）
  static final Set<RunTaskType> _collapsedTypes = <RunTaskType>{};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isCollapsed(RunTaskType type) {
    if (_searchQuery.isNotEmpty) return false;
    return _collapsedTypes.contains(type);
  }

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
    final group = task.group ?? '';
    return name.toLowerCase().contains(_searchQuery) ||
        task.command.toLowerCase().contains(_searchQuery) ||
        desc.toLowerCase().contains(_searchQuery) ||
        group.toLowerCase().contains(_searchQuery) ||
        (task.description?.toLowerCase().contains(_searchQuery) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 优先响应父级 Provider 数据变化，保证静默后台自省完成后对话框无感自动刷新
    RunProvider? runProvider;
    try {
      runProvider = Provider.of<RunProvider>(context);
    } catch (_) {}

    final effectiveLastRunTaskId = runProvider?.lastRunTaskId ?? widget.lastRunTaskId;

    // 类型 → 任务数组：优先取 Provider 的当前工程内存表；
    // 无 Provider（独立使用弹窗/单测）时按同构结构由入参临时组装。
    final ProjectTaskTable table;
    if (runProvider != null) {
      table = runProvider.taskTable;
    } else {
      table = ProjectTaskTable()..setUserTasks(widget.customTasks);
      for (final task in widget.detectedTasks) {
        final type = RunTaskType.ofTask(task);
        table.replaceType(type, [...table.tasksOf(type), task]);
      }
    }

    // 按类型过滤（搜索命中），保留非空类型的顺序
    final sections = <({RunTaskType type, List<RunTask> tasks})>[];
    for (final type in RunTaskType.values) {
      final tasks = table.tasksOf(type).where((t) => _matchesQuery(t, l10n)).toList();
      if (tasks.isNotEmpty) sections.add((type: type, tasks: tasks));
    }
    final hasAny = sections.isNotEmpty;

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
                          // 任务类型 → 具体任务：每个类型为独立折叠 Tile（折叠状态内存常驻）
                          for (final section in sections) ...[
                            _buildSectionHeader(
                              context,
                              section.type,
                              _typeLabel(l10n, section.type, runProvider),
                              _typeIcon(section.type),
                              section.tasks.length,
                              _isCollapsed(section.type),
                              () {
                                setState(() {
                                  if (_collapsedTypes.contains(section.type)) {
                                    _collapsedTypes.remove(section.type);
                                  } else {
                                    _collapsedTypes.add(section.type);
                                  }
                                });
                              },
                            ),
                            if (!_isCollapsed(section.type)) ...[
                              ...section.tasks.map(
                                (task) => _buildTaskItem(context, task, l10n, effectiveLastRunTaskId),
                              ),
                            ],
                            const SizedBox(height: 6),
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

  /// 任务类型展示名：模块类型用专有名词（取自模块 displayName），单文件/用户任务走 l10n
  String _typeLabel(AppLocalizations l10n, RunTaskType type, RunProvider? runProvider) {
    final moduleId = type.moduleId;
    if (moduleId == null) {
      return switch (type) {
        RunTaskType.singleFile => l10n.taskTypeSingleFile,
        RunTaskType.user => l10n.userCustomTasks,
        RunTaskType.other => l10n.taskTypeOther,
        _ => type.name,
      };
    }
    return runProvider?.moduleDisplayName(moduleId) ?? _moduleLabel(type);
  }

  /// 模块类型专有名词（Gradle / CMake / …）
  String _moduleLabel(RunTaskType type) {
    final moduleId = type.moduleId;
    if (moduleId == null) return type.name;
    return moduleId[0].toUpperCase() + moduleId.substring(1);
  }

  IconData _typeIcon(RunTaskType type) {
    return switch (type) {
      RunTaskType.user => Icons.person_outline,
      RunTaskType.singleFile => Icons.description_outlined,
      RunTaskType.other => Icons.category_outlined,
      _ => Icons.radar_outlined,
    };
  }

  Widget _buildSectionHeader(
    BuildContext context,
    RunTaskType type,
    String title,
    IconData icon,
    int count,
    bool isCollapsed,
    VoidCallback onToggle,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, RunTask task, AppLocalizations l10n, String? lastRunTaskId) {
    final theme = Theme.of(context);
    final isLastRun = lastRunTaskId != null && lastRunTaskId == task.id;

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.getLocalizedName(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isLastRun ? Colors.green.shade700 : null,
                ),
              ),
            ),
            if (task.group != null && task.group!.isNotEmpty && task.group != 'single_file')
              Container(
                margin: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(maxWidth: 130),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.group!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSecondaryContainer,
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
          radius: 15,
          backgroundColor: isLastRun
              ? Colors.green.withValues(alpha: 0.25)
              : theme.colorScheme.primaryContainer,
          foregroundColor: isLastRun ? Colors.green : theme.colorScheme.onPrimaryContainer,
          child: const Icon(Icons.play_arrow, size: 18),
        ),
        onTap: () {
          Navigator.of(context).pop();
          widget.onTaskSelected(task);
        },
      ),
    );
  }
}
