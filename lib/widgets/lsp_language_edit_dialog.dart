import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/lsp_language_config.dart';

/// 语言配置编辑 / 新增弹窗表单
class LspLanguageEditDialog extends StatefulWidget {
  final LspLanguageConfig? initialConfig;

  const LspLanguageEditDialog({
    super.key,
    this.initialConfig,
  });

  /// 快捷弹出对话框，返回修改后的配置或 null（若取消）
  static Future<LspLanguageConfig?> show(
    BuildContext context, {
    LspLanguageConfig? initialConfig,
  }) {
    return showDialog<LspLanguageConfig>(
      context: context,
      builder: (ctx) => LspLanguageEditDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<LspLanguageEditDialog> createState() => _LspLanguageEditDialogState();
}

class _LspLanguageEditDialogState extends State<LspLanguageEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _languageIdController;
  late final TextEditingController _extensionsController;
  late final TextEditingController _commandController;
  late final TextEditingController _argsController;
  late final TextEditingController _packageController;

  @override
  void initState() {
    super.initState();
    final init = widget.initialConfig;
    _nameController = TextEditingController(text: init?.name ?? '');
    _languageIdController = TextEditingController(text: init?.languageId ?? '');
    _extensionsController = TextEditingController(
      text: init?.fileExtensions.join(', ') ?? '',
    );
    _commandController = TextEditingController(text: init?.serverCommand ?? '');
    _argsController = TextEditingController(
      text: init?.serverArgs.join(' ') ?? '',
    );
    _packageController = TextEditingController(text: init?.package ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _languageIdController.dispose();
    _extensionsController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _packageController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawExtensions = _extensionsController.text.split(RegExp(r'[,，\s]+'));
    final cleanedExtensions = <String>[];
    for (final raw in rawExtensions) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final withDot = trimmed.startsWith('.') ? trimmed : '.$trimmed';
      if (!cleanedExtensions.contains(withDot)) {
        cleanedExtensions.add(withDot);
      }
    }

    final rawArgs = _argsController.text.trim();
    final cleanedArgs = rawArgs.isEmpty
        ? <String>[]
        : rawArgs
            .split(RegExp(r'[\s,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final id = widget.initialConfig?.id ??
        _nameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    final updated = LspLanguageConfig(
      id: id.isEmpty ? 'custom_lang_${DateTime.now().millisecondsSinceEpoch}' : id,
      name: _nameController.text.trim(),
      languageId: _languageIdController.text.trim(),
      fileExtensions: cleanedExtensions,
      serverCommand: _commandController.text.trim(),
      serverArgs: cleanedArgs,
      package: _packageController.text.trim(),
      enabled: widget.initialConfig?.enabled ?? true,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.initialConfig != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.editLanguageConfig : l10n.addLanguageConfig),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.languageDisplayName,
                  hintText: l10n.languageDisplayNameHint,
                  prefixIcon: const Icon(Icons.title, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _languageIdController,
                decoration: InputDecoration(
                  labelText: l10n.languageIdField,
                  hintText: l10n.languageIdFieldHint,
                  prefixIcon: const Icon(Icons.code, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extensionsController,
                decoration: InputDecoration(
                  labelText: l10n.fileExtensionsField,
                  hintText: l10n.fileExtensionsFieldHint,
                  prefixIcon: const Icon(Icons.extension_outlined, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commandController,
                decoration: InputDecoration(
                  labelText: l10n.serverCommandField,
                  hintText: l10n.serverCommandFieldHint,
                  prefixIcon: const Icon(Icons.terminal, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _argsController,
                decoration: InputDecoration(
                  labelText: l10n.serverArgsField,
                  hintText: l10n.serverArgsFieldHint,
                  prefixIcon: const Icon(Icons.tune, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _packageController,
                decoration: InputDecoration(
                  labelText: l10n.apkPackageField,
                  hintText: l10n.apkPackageFieldHint,
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _onSave,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
