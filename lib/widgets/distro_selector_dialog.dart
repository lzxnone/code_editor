import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/services/distro_download_manager.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/distro_management_view.dart';
import 'package:code_editor/widgets/distro_extract_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// 独立的 Linux 系统选择与管理对话框
class DistroSelectorDialog extends StatelessWidget {
  const DistroSelectorDialog({super.key});

  /// 打开系统选择与管理对话框
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const DistroSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final distroProvider = context.watch<DistroProvider>();
    final systems = distroProvider.installedSystems;
    final selectedSystem = distroProvider.selectedSystem;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20.0, 16.0, 12.0, 8.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      title: Row(
        children: [
          const Icon(Icons.dns_outlined, size: 22, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.systemManagement,
              style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            ),
          ),
          // 导入按钮与下拉选项
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
            tooltip: l10n.importNewSystem,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            onSelected: (action) => _handleImportAction(context, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'management_view',
                child: Row(
                  children: [
                    const Icon(Icons.apps_rounded, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.importFromApp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'external',
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.importExternalTarGz,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                l10n.selectSystemDefaultPrompt,
                style: TextStyle(
                  fontSize: 12.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: systems.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_clear_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noSystemsPrompt,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      itemCount: systems.length,
                      itemBuilder: (context, index) {
                        final system = systems[index];
                        final isSelected = system == selectedSystem;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Material(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.0),
                            child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                            title: Text(
                              system,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? theme.colorScheme.primary : null,
                                fontSize: 14.0,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              tooltip: l10n.deleteSystemTooltip,
                              onPressed: () => _handleDeleteSystem(context, system),
                            ),
                            onTap: () {
                              distroProvider.selectSystem(system);
                            },
                          ),
                        ),
                      );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  /// 处理导入菜单操作
  bool _isValidDistroArchive(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.xz') ||
        lower.endsWith('.txz') ||
        lower.endsWith('.tar');
  }

  Future<void> _handleImportAction(BuildContext context, String action) async {
    final distroProvider = context.read<DistroProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (action == 'management_view') {
      // 1. 跳转到应用内系统管理页面
      final selectedItem = await Navigator.of(context).push<DistroManifestItem>(
        MaterialPageRoute(builder: (_) => const DistroManagementView()),
      );

      if (selectedItem != null && context.mounted) {
        // 用户直接点击已经安装的 item 本身，代表用户选择了那个 zip，返回后解压创建系统
        await _handleCreateSystemFromManifest(context, selectedItem);
      }
    } else if (action == 'external') {
      // 2. 从外部选择 .tar.gz / .tar.xz 压缩包导入
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['tar', 'gz', 'tgz', 'xz', 'txz'],
      );

      if (result == null || result.files.single.path == null || !context.mounted) return;
      final filePath = result.files.single.path!;

      if (!_isValidDistroArchive(filePath)) {
        if (context.mounted) {
          DialogUtils.showErrorToast(context, l10n.unsupportedDistroArchiveFormat);
        }
        return;
      }

      final file = File(filePath);

      // 提取默认名称（去掉 .tar.gz, .tgz 等后缀）
      String baseName = p.basename(filePath);
      if (baseName.endsWith('.tar.gz')) {
        baseName = baseName.substring(0, baseName.length - 7);
      } else if (baseName.endsWith('.tgz')) {
        baseName = baseName.substring(0, baseName.length - 4);
      } else {
        baseName = p.basenameWithoutExtension(filePath);
      }
      baseName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      if (baseName.isEmpty) baseName = 'custom_linux';

      final defaultName = _generateUniqueSystemName(baseName, distroProvider.installedSystems);

      final systemName = await DialogUtils.showInputDialog(
        context,
        title: l10n.importExternalSystemTitle,
        hintText: l10n.systemNameHint,
        initialValue: defaultName,
      );

      if (systemName == null || systemName.trim().isEmpty || !context.mounted) return;
      final cleanName = systemName.trim();

      // 模态同步解压
      final success = await DistroExtractDialog.show(
        context: context,
        systemName: cleanName,
        task: (onProgress, isCancelled) {
          return distroProvider.importFromCustomTarGz(
            systemName: cleanName,
            tarGzFile: file,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        },
      );

      if (success && context.mounted) {
        DialogUtils.showSuccessToast(context, l10n.externalSystemImportSuccess(cleanName));
      }
    }
  }

  /// 从选中的发行版安装包解压创建新的系统实例
  Future<void> _handleCreateSystemFromManifest(BuildContext context, DistroManifestItem item) async {
    final distroProvider = context.read<DistroProvider>();
    final l10n = AppLocalizations.of(context)!;

    final defaultName = _generateUniqueSystemName(item.id, distroProvider.installedSystems);
    final systemName = await DialogUtils.showInputDialog(
      context,
      title: l10n.importSystemInstanceTitle(item.name),
      hintText: l10n.systemNameHintWithDefault(defaultName),
      initialValue: defaultName,
    );

    if (systemName == null || systemName.trim().isEmpty || !context.mounted) return;
    final cleanName = systemName.trim();

    // 模态同步解压
    final success = await DistroExtractDialog.show(
      context: context,
      systemName: cleanName,
      task: (onProgress, isCancelled) async {
        if (item.id == 'ubuntu') {
          return distroProvider.importBuiltinUbuntu(
            systemName: cleanName,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        } else if (item.id == 'alpine') {
          return distroProvider.importBuiltinAlpine(
            systemName: cleanName,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        } else {
          final file = await DistroDownloadManager().getPackageFile(item.id, item.currentPackageSource!);
          return distroProvider.importFromCustomTarGz(
            systemName: cleanName,
            tarGzFile: file,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        }
      },
    );

    if (success && context.mounted) {
      DialogUtils.showSuccessToast(context, l10n.systemImportSuccess(cleanName));
      await distroProvider.refreshSystems();
      await distroProvider.selectSystem(cleanName);
    }
  }

  /// 高危操作：二次确认删除系统
  Future<void> _handleDeleteSystem(BuildContext context, String systemName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.deleteSystemConfirmTitle,
      message: l10n.deleteSystemConfirmMessage(systemName),
      confirmText: l10n.permanentDelete,
    );

    if (confirmed && context.mounted) {
      final distroProvider = context.read<DistroProvider>();
      final terminalProvider = context.read<TerminalProvider?>();
      try {
        await distroProvider.deleteSystem(systemName);
        terminalProvider?.removeSessionsForDistro(systemName);
        if (!distroProvider.hasAnySystem) {
          terminalProvider?.clearAllSessions();
        }
        if (context.mounted) {
          DialogUtils.showToast(context, l10n.deleteSystemSuccess(systemName));
        }
      } catch (e) {
        if (context.mounted) {
          DialogUtils.showErrorToast(context, l10n.deleteSystemFailed(e.toString()));
        }
      }
    }
  }

  /// 自动生成不重复的系统实例名
  String _generateUniqueSystemName(String prefix, List<String> existingSystems) {
    if (!existingSystems.contains(prefix)) return prefix;
    int index = 1;
    while (existingSystems.contains('${prefix}_$index')) {
      index++;
    }
    return '${prefix}_$index';
  }
}
