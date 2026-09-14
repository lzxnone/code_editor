import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/run_task.dart';
import '../utils/dialog_utils.dart';

/// 运行任务单项创建/编辑 View（独立页面，点击返回键返回任务配置界面）
class RunTaskDetailView extends StatefulWidget {
  final RunTask? initialTask;
  final ValueChanged<RunTask> onSave;

  const RunTaskDetailView({
    super.key,
    this.initialTask,
    required this.onSave,
  });

  static Future<void> navigate({
    required BuildContext context,
    RunTask? initialTask,
    required ValueChanged<RunTask> onSave,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => RunTaskDetailView(
          initialTask: initialTask,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<RunTaskDetailView> createState() => _RunTaskDetailViewState();
}

class _RunTaskDetailViewState extends State<RunTaskDetailView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _commandController;
  late TextEditingController _descController;
  bool _clearBeforeRun = false;

  late String _initialName;
  late String _initialCommand;
  late String _initialDesc;
  late bool _initialClearBeforeRun;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _initialName = task?.name ?? '';
    _initialCommand = task?.command ?? '';
    _initialDesc = task?.description ?? '';
    _initialClearBeforeRun = task?.clearBeforeRun ?? false;

    _nameController = TextEditingController(text: _initialName);
    _commandController = TextEditingController(text: _initialCommand);
    _descController = TextEditingController(text: _initialDesc);
    _clearBeforeRun = _initialClearBeforeRun;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _nameController.text != _initialName ||
        _commandController.text != _initialCommand ||
        _descController.text != _initialDesc ||
        _clearBeforeRun != _initialClearBeforeRun;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isDirty) return true;

    final l10n = AppLocalizations.of(context)!;
    final shouldDiscard = await DialogUtils.showConfirmDialog(
      context,
      title: l10n.unsavedTaskChangesTitle,
      message: l10n.unsavedTaskChangesMessage,
      confirmText: l10n.dontSave,
      cancelText: l10n.cancel,
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 28,
      ),
    );
    return shouldDiscard;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final task = RunTask(
      id: widget.initialTask?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      command: _commandController.text.trim(),
      source: TaskSource.custom,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      clearBeforeRun: _clearBeforeRun,
    );

    widget.onSave(task);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.initialTask != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canDiscard = await _confirmDiscardChanges();
        if (canDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? l10n.editTask : l10n.addTask),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.back,
            onPressed: () async {
              final canDiscard = await _confirmDiscardChanges();
              if (canDiscard && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.done,
              onPressed: _save,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.taskNameRequired,
                    hintText: l10n.taskNameHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.taskNameEmptyError : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: l10n.taskDescOptional,
                    hintText: l10n.taskDescHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commandController,
                  minLines: 3,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: l10n.shellCommandRequired,
                    hintText: l10n.shellCommandHint,
                    helperText: l10n.shellCommandHelperText,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.shellCommandEmptyError : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.clearBeforeRun),
                  subtitle: Text(l10n.clearBeforeRunSubtitle, style: const TextStyle(fontSize: 12)),
                  value: _clearBeforeRun,
                  onChanged: (val) => setState(() => _clearBeforeRun = val),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
