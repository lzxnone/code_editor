import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/lsp_language_config.dart';
import '../providers/settings_provider.dart';
import '../services/internal_engine_service.dart';
import '../services/lsp/lsp_manager.dart';
import '../services/lsp_config_service.dart';
import '../utils/dialog_utils.dart';
import '../widgets/lsp_language_edit_dialog.dart';
import 'main_view.dart';

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
  final Set<String> _expandedConfigIds = {};
  /// 记录正在进行后台安装/卸载任务的语言配置 ID 及其动作类型（'install' 或 'uninstall'）
  final Map<String, String> _busyConfigActions = {};
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
        _installedStatus
          ..clear()
          ..addAll(newStatus);
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _handleToggleEnabled(LspLanguageConfig config) async {
    final updated = config.copyWith(enabled: !config.enabled);
    if (!updated.enabled) {
      await LspManager.instance.stopSession(config.id);
    }
    await _lspService.updateConfig(updated);
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
      if (l10n == null) return;

      final hasPkg = newConfig.package.trim().isNotEmpty || (newConfig.installCommand?.trim().isNotEmpty ?? false);
      if (hasPkg) {
        final success = await DialogUtils.showSyncLoadingDialog<bool>(
          context,
          message: l10n.installingComponent(newConfig.name),
          task: () => InternalEngineService.instance.installLspConfig(newConfig),
        );

        if (!mounted) return;

        if (success) {
          await _lspService.updateConfig(newConfig);
          if (mounted) {
            DialogUtils.showSuccessToast(context, l10n.installComponentSuccess(newConfig.name));
            _checkCommandsStatus();
          }
        } else {
          if (mounted) {
            DialogUtils.showErrorToast(
              context,
              l10n.installComponentFailed('apt exit with non-zero code'),
            );
          }
        }
      } else {
        // 无系统依赖包名直接保存配置
        await _lspService.updateConfig(newConfig);
        if (mounted) {
          DialogUtils.showSuccessToast(context, l10n.languageConfigSaved);
          _checkCommandsStatus();
        }
      }
    }
  }

  Future<void> _handleDelete(LspLanguageConfig config) async {
    final l10n = AppLocalizations.of(context)!;
    final isInstalled = _installedStatus[config.id] ?? false;
    final hasPackage = config.package.trim().isNotEmpty;

    final contentText = (isInstalled && hasPackage)
        ? l10n.deleteLanguageWithPackageConfirmMessage(config.name)
        : l10n.deleteLanguageConfirmMessage(config.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteLanguageConfirmTitle),
        content: Text(contentText),
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
      // 1. 删除前先优雅停用后台语言服务并清理活跃会话
      await LspManager.instance.stopSession(config.id);
      if (!mounted) return;

      if (isInstalled && hasPackage) {
        // 同步弹出卸载 dialog，与安装组件保持一致的同步交互体验
        final success = await DialogUtils.showSyncLoadingDialog<bool>(
          context,
          message: l10n.uninstallingComponent(config.name),
          task: () => InternalEngineService.instance.uninstallPackage(
            config.package,
            serverCommand: config.serverCommand,
          ),
        );

        if (!mounted) return;

        if (success == true) {
          DialogUtils.showSuccessToast(
            context,
            l10n.uninstallComponentSuccess(config.name),
          );
        } else {
          // 卸载失败：给出明确提示并中止，避免误删本地配置导致状态脱节
          DialogUtils.showErrorToast(
            context,
            l10n.uninstallComponentFailed('apt purge non-zero or binary retained'),
          );
          return;
        }
      }

      // 2. 卸载成功（或纯配置项无包）：删除本地配置并清除防打扰白名单
      await _lspService.deleteConfig(config.id);
      MainView.clearPromptedLanguage(config.id);

      if (mounted) {
        setState(() {
          _installedStatus.remove(config.id);
          _expandedConfigIds.remove(config.id);
        });
        _checkCommandsStatus();
      }
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
                _buildCompletionSwitchesCard(context, theme, l10n),
                const SizedBox(height: 12),
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
                if (configs.isEmpty)
                  _buildEmptyPlaceholder(context, theme, l10n)
                else
                  ...configs.map((cfg) => _buildLanguageItem(context, theme, l10n, cfg)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletionSwitchesCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final settings = context.watch<SettingsProvider?>();
    if (settings == null) return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.completionSourceSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.hub_outlined),
              title: Text(l10n.lspCompletionTitle),
              value: settings.enableLspCompletion,
              onChanged: (val) => settings.setEnableLspCompletion(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.code_off_rounded,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.emptyLspLanguagesTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

    final (bgColor, borderColor, icon, statusText) = isInstalled
        ? (
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            colorScheme.outlineVariant,
            Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 28),
            l10n.internalEngineStatusReady,
          )
        : (
            colorScheme.errorContainer.withValues(alpha: 0.3),
            colorScheme.error.withValues(alpha: 0.5),
            Icon(Icons.warning_amber_outlined, color: colorScheme.error, size: 28),
            l10n.internalEngineStatusNotReady,
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
              child: Text(
                statusText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isInstalled ? null : colorScheme.error,
                ),
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
    final isExpanded = _expandedConfigIds.contains(config.id);
    final busyAction = _busyConfigActions[config.id];
    final isBusy = busyAction != null;
    final colorScheme = theme.colorScheme;

    // 状态描边：正在处理为品牌强调色(Primary)；启用状态为绿色；未启用时保持普通灰色描边
    final BorderSide borderSide;
    if (isBusy) {
      borderSide = BorderSide(color: colorScheme.primary, width: 1.5);
    } else if (config.enabled) {
      borderSide = const BorderSide(color: Colors.green, width: 1.5);
    } else {
      borderSide = BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5));
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: borderSide,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：点击折叠/展开，仅显示头像、主标题和折叠指示图标
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedConfigIds.remove(config.id);
                } else {
                  _expandedConfigIds.add(config.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: config.enabled
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: Text(
                      config.name.isNotEmpty ? config.name.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(
                        color: config.enabled
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            config.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: config.enabled ? null : colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBusy) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            busyAction == 'uninstall'
                                ? l10n.uninstallingStatus
                                : l10n.installingStatus,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // 展开区域：显示文件扩展名标签与功能菜单选项
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件后缀标签
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: config.fileExtensions.map(
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
                    ).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 功能菜单：启用/停用、安装组件（若未安装）、编辑、删除
                  // 正在进行后台任务时，所有操作均被禁用以防止并发冲突
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 启用 / 停用
                      if (!isBusy)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          onPressed: () => _handleToggleEnabled(config),
                          icon: Icon(
                            config.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            size: 16,
                          ),
                          label: Text(config.enabled ? l10n.disable : l10n.enable),
                        ),

                      // 编辑配置（后台任务进行中禁用）
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: isBusy ? null : () => _handleEdit(config),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(l10n.edit),
                      ),

                      // 删除配置（后台任务进行中禁用）
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isBusy ? colorScheme.outline : colorScheme.error,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: isBusy ? null : () => _handleDelete(config),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(l10n.delete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
