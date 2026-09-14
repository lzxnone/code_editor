import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/run_task.dart';
import 'run_task_detail_view.dart';

/// 运行任务列表配置 View（支持拖动排序、单项与多选删除确认、自动静默保存至 JSON）
class RunTaskEditView extends StatefulWidget {
  final List<RunTask> tasks;
  final ValueChanged<List<RunTask>> onSave;

  const RunTaskEditView({
    super.key,
    required this.tasks,
    required this.onSave,
  });

  static Future<void> navigate({
    required BuildContext context,
    required List<RunTask> currentTasks,
    required ValueChanged<List<RunTask>> onSave,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => RunTaskEditView(
          tasks: currentTasks,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<RunTaskEditView> createState() => _RunTaskEditViewState();
}

class _RunTaskEditViewState extends State<RunTaskEditView> {
  late List<RunTask> _taskList;
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _taskList = List.from(widget.tasks);
  }

  /// 任何变动立即写回（直接写回 JSON，无需点击额外保存按钮）
  void _persistChanges() {
    widget.onSave(List.unmodifiable(_taskList));
  }

  void _openCreateView() {
    RunTaskDetailView.navigate(
      context: context,
      onSave: (newTask) {
        setState(() {
          _taskList.add(newTask);
        });
        _persistChanges();
      },
    );
  }

  void _openEditView(RunTask task) {
    RunTaskDetailView.navigate(
      context: context,
      initialTask: task,
      onSave: (updatedTask) {
        final index = _taskList.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          setState(() {
            _taskList[index] = updatedTask;
          });
          _persistChanges();
        }
      },
    );
  }

  /// 单项删除确认弹窗
  Future<void> _confirmDeleteSingle(RunTask task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteTaskConfirmMessage(task.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _taskList.removeWhere((t) => t.id == task.id);
        _selectedTaskIds.remove(task.id);
      });
      _persistChanges();
    }
  }

  /// 多选批量删除确认弹窗
  Future<void> _confirmDeleteBatch() async {
    if (_selectedTaskIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteSelectedTasksConfirmMessage(_selectedTaskIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _taskList.removeWhere((t) => _selectedTaskIds.contains(t.id));
        _selectedTaskIds.clear();
        _isSelectionMode = false;
      });
      _persistChanges();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTaskIds.contains(id)) {
        _selectedTaskIds.remove(id);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? l10n.selectedCount(_selectedTaskIds.length)
            : l10n.runTasksConfig),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedTaskIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: l10n.deleteSelected,
              onPressed: _confirmDeleteBatch,
            )
          else if (_taskList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: l10n.selectTasksToDelete,
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _taskList.isEmpty ? _buildEmptyView(theme, l10n) : _buildReorderableList(theme, l10n),
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton(
              onPressed: _openCreateView,
              tooltip: l10n.addTask,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyView(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.playlist_remove, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l10n.noCustomTasksInProject,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.createNow),
            onPressed: _openCreateView,
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(ThemeData theme, AppLocalizations l10n) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _taskList.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final task = _taskList.removeAt(oldIndex);
          _taskList.insert(newIndex, task);
        });
        _persistChanges();
      },
      itemBuilder: (ctx, index) {
        final task = _taskList[index];
        final isSelected = _selectedTaskIds.contains(task.id);

        return Card(
          key: ValueKey(task.id),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 0,
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(task.id),
                  )
                : const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.terminal, size: 18),
                  ),
            // 只显示：名称 + 用途（描述）
            title: Text(
              task.getLocalizedName(l10n),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: task.getLocalizedDescription(l10n).trim().isNotEmpty
                ? Text(
                    task.getLocalizedDescription(l10n).trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: l10n.editTask,
                    onPressed: () => _openEditView(task),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                    tooltip: l10n.delete,
                    onPressed: () => _confirmDeleteSingle(task),
                  ),
                  // 最右侧拖动把手，支持长按/拖动排序
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(
                        Icons.drag_handle,
                        color: theme.colorScheme.outline,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(task.id);
              } else {
                _openEditView(task);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedTaskIds.add(task.id);
                });
              }
            },
          ),
        );
      },
    );
  }
}
