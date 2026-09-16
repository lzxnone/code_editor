import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/lsp_language_config.dart';
import '../services/internal_engine_service.dart';
import '../services/lsp_config_service.dart';
import '../utils/dialog_utils.dart';
import '../widgets/lsp_language_edit_dialog.dart';

/// 代码补全与语言服务管理视图
class CodeCompletionManagementView extends StatefulWidget {
  const CodeCompletionManagementView({super.key});

  @override
  State<CodeCompletionManagementView> createState() =>
      _CodeCompletionManagementViewState();
}

class _CodeCompletionManagementViewState
    extends State<CodeCompletionManagementView> {
  final _lspService = LspConfigService.instance;
  final _engineService = InternalEngineService.instance;

  final Map<String, bool> _installedStatus = {};
  bool _isLoadingStatus = false;
  bool _engineReady = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _lspService.loadConfigs();
    await _checkCommandsStatus();
  }

  Future<void> _checkCommandsStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);

    final engineReady = await _engineService.isEngineInstalled();
    if (!engineReady) {
      if (mounted) {
        setState(() {
          _engineReady = false;
          _installedStatus.clear();
          _isLoadingStatus = false;
        });
      }
      return;
    }

    final newStatus = <String, bool>{};
    for (final config in _lspService.configs) {
      final isInstalled =
          await _engineService.isCommandInstalled(config.serverCommand);
      newStatus[config.id] = isInstalled;
    }

    if (mounted) {
      setState(() {
        _engineReady = true;
        _installedStatus.addAll(newStatus);
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _handleEdit(LspLanguageConfig config) async {
    final updated = await LspLanguageEditDialog.show(
      context,
      initialConfig: config,
    );
    if (updated != null && mounted) {
      final l10n = AppLocalizations.of(context);
      await _lspService.updateConfig(updated);
      if (mounted && l10n != null) {
        DialogUtils.showSuccessToast(context, l10n.languageConfigSaved);
      }
      _checkCommandsStatus();
    }
  }

  Future<void> _handleAdd() async {
    final newConfig = await LspLanguageEditDialog.show(context);
    if (newConfig != null && mounted) {
      final l10n = AppLocalizations.of(context);
      await _lspService.updateConfig(newConfig);
      if (mounted && l10n != null) {
        DialogUtils.showSuccessToast(context, l10n.languageConfigSaved);
      }
      _checkCommandsStatus();
    }
  }

  Future<void> _handleDelete(LspLanguageConfig config) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteLanguageConfirmTitle),
        content: Text(l10n.deleteLanguageConfirmMessage(config.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _lspService.deleteConfig(config.id);
      setState(() {
        _installedStatus.remove(config.id);
      });
    }
  }

  Future<void> _handleReset() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetDefaultLanguages),
        content: Text(l10n.resetDefaultLanguagesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _lspService.resetToDefaults();
      _checkCommandsStatus();
    }
  }

  Future<void> _handleInstallComponent(LspLanguageConfig config) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await DialogUtils.showSyncLoadingDialog<bool>(
      context,
      message: l10n.installingComponent(config.apkPackage),
      task: () => _engineService.installPackage(config.apkPackage),
    );

    if (!mounted) return;

    if (success) {
      DialogUtils.showSuccessToast(
        context,
        l10n.installComponentSuccess(config.name),
      );
      _checkCommandsStatus();
    } else {
      DialogUtils.showErrorToast(
        context,
        l10n.installComponentFailed('apk add exit with non-zero'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.codeCompletionManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetDefaultLanguages,
            onPressed: _handleReset,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addLanguageConfig,
            onPressed: _handleAdd,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _lspService,
        builder: (context, _) {
          final configs = _lspService.configs;

          return RefreshIndicator(
            onRefresh: _checkCommandsStatus,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildEngineStatusCard(context, theme, l10n),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        l10n.languageSection,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingStatus)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ...configs.map((cfg) => _buildLanguageItem(context, theme, l10n, cfg)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEngineStatusCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isInstalled = _engineReady;
    final colorScheme = theme.colorScheme;

    final (bgColor, borderColor, icon, statusText, subText) = isInstalled
        ? (
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            colorScheme.outlineVariant,
            Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 28),
            l10n.internalEngineStatusReady,
            'Alpine Linux (musl libc)',
          )
        : (
            colorScheme.errorContainer.withValues(alpha: 0.3),
            colorScheme.error.withValues(alpha: 0.5),
            Icon(Icons.warning_amber_outlined, color: colorScheme.error, size: 28),
            l10n.internalEngineStatusNotReady,
            l10n.internalEngineExtracting,
          );

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.internalEngineTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusText • $subText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isInstalled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            if (!isInstalled)
              TextButton(
                onPressed: () async {
                  final ready = await _engineService.ensureEngineReady(context);
                  if (ready && context.mounted) {
                    _checkCommandsStatus();
                  }
                },
                child: Text(l10n.installNow),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    LspLanguageConfig config,
  ) {
    final isInstalled = _installedStatus[config.id] ?? false;
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    config.name.isNotEmpty ? config.name.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            config.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(theme, l10n, isInstalled),
                        ],
                      ),
                      Text(
                        '${config.serverCommand} (${config.apkPackage}) • id: ${config.languageId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: l10n.editLanguageConfig,
                  onPressed: () => _handleEdit(config),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: l10n.delete,
                  onPressed: () => _handleDelete(config),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...config.fileExtensions.map(
                  (ext) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'JetBrains Mono',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (!isInstalled)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _handleInstallComponent(config),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              l10n.installComponent,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    ThemeData theme,
    AppLocalizations l10n,
    bool isInstalled,
  ) {
    final (bgColor, fgColor, text) = isInstalled
        ? (
            Colors.green.withValues(alpha: 0.15),
            Colors.green.shade700,
            l10n.installedStatus,
          )
        : (
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.shade700,
            l10n.notInstalledStatus,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
