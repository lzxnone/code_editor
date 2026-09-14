import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/services/distro_download_manager.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 独立的系统管理与发行版包选择视图页面
///
/// 功能：
/// 1. AppBar 包含返回键与标题“系统管理”（遵循 l10n 国际化）。
/// 2. 列举当前架构支持的系统安装包（左侧图标、两行名称与版本，无高亮选框，无“内置”字样）。
/// 3. 安装包项分为两种状态：
///    - 已就绪 (zip 存在)：
///      * 不显示“已安装”文本，不显示“安装”按键；
///      * Ubuntu 和 Alpine 为内置包，受保护右侧不显示删除按键；
///      * 在线下载的系统包右侧显示红色删除按钮（二次确认后居中同步转圈删除离线包）；
///      * 用户直接点击该项卡片，即代表选中该安装包，返回上一页进行解压创建系统。
///    - 未下载 / 下载中：
///      * 未下载显示“下载”按键；
///      * 下载中显示百分比进度条与取消按键（取消后清空临时文件）。
class DistroManagementView extends StatefulWidget {
  const DistroManagementView({super.key});

  @override
  State<DistroManagementView> createState() => _DistroManagementViewState();
}

class _DistroManagementViewState extends State<DistroManagementView> {
  final DistroDownloadManager _downloadManager = DistroDownloadManager();
  final Set<String> _downloadedPackageIds = {};

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadProgressChanged);
    _checkDownloadedPackages();
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onDownloadProgressChanged);
    super.dispose();
  }

  void _onDownloadProgressChanged() {
    if (mounted) {
      for (final entry in _downloadManager.allProgress.entries) {
        if (entry.value.state == DistroDownloadState.completed) {
          _downloadedPackageIds.add(entry.key);
        }
      }
      setState(() {});
    }
  }

  Future<void> _checkDownloadedPackages() async {
    final distros = DistroRepository.currentArchDistros;
    final Set<String> downloaded = {};
    for (final d in distros) {
      if (!d.isBuiltin && d.currentPackageSource != null) {
        if (await _downloadManager.isPackageDownloaded(d.id, d.currentPackageSource)) {
          downloaded.add(d.id);
        }
      }
    }
    for (final entry in _downloadManager.allProgress.entries) {
      if (entry.value.state == DistroDownloadState.completed) {
        downloaded.add(entry.key);
      }
    }
    if (mounted) {
      setState(() {
        _downloadedPackageIds.clear();
        _downloadedPackageIds.addAll(downloaded);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 当前架构支持的发行版清单
    final distros = DistroRepository.currentArchDistros;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.distroManagementTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: distros.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = distros[index];
          final downloadProgress = _downloadManager.getProgress(item.id);
          final isDownloaded = _downloadedPackageIds.contains(item.id) ||
              downloadProgress?.state == DistroDownloadState.completed;
          final isReady = item.isBuiltin || isDownloaded;
          final isDownloading = downloadProgress?.state == DistroDownloadState.downloading;

          return _buildDistroCard(
            context: context,
            theme: theme,
            l10n: l10n,
            item: item,
            isReady: isReady,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
          );
        },
      ),
    );
  }

  Widget _buildDistroCard({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required DistroManifestItem item,
    required bool isReady,
    required bool isDownloading,
    required DistroDownloadProgress? downloadProgress,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: isReady
            ? () {
                // 点击已就绪的安装包 item：代表选择该 zip，返回上一页解压创建系统
                Navigator.of(context).pop(item);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 1. 系统左侧品牌图标
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: item.brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: item.brandColor.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: item.assetIconPath != null
                        ? Image.asset(
                            item.assetIconPath!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              item.iconData,
                              color: item.brandColor,
                              size: 26,
                            ),
                          )
                        : Icon(
                            item.iconData,
                            color: item.brandColor,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 14),

                  // 2. 中间两行文本 (系统名与推荐标签 + 版本)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isRecommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(
                                    color: Colors.amber.shade800.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  l10n.recommendedTag,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.version,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 3. 右侧状态与操作按钮
                  const SizedBox(width: 10),
                  _buildTrailingAction(
                    context: context,
                    theme: theme,
                    l10n: l10n,
                    item: item,
                    isReady: isReady,
                    isDownloading: isDownloading,
                    downloadProgress: downloadProgress,
                  ),
                ],
              ),

              // 若处于下载中，展示下载进度条与百分比
              if (isDownloading && downloadProgress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: LinearProgressIndicator(
                          value: downloadProgress.totalBytes > 0
                              ? downloadProgress.progress
                              : null,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(downloadProgress.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingAction({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required DistroManifestItem item,
    required bool isReady,
    required bool isDownloading,
    required DistroDownloadProgress? downloadProgress,
  }) {
    if (isReady) {
      // 对于已就绪 (已安装) 的 item (zip 文件)：
      // 不显示“已安装”文本，不显示“安装”按键。
      // 对于内置 ubuntu 和 alpine，受保护无按键 (SizedBox.shrink)；
      // 其他在线下载完成的包，右侧直接显示红色删除按钮
      if (item.isBuiltin) {
        return const SizedBox.shrink();
      }

      return IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
        tooltip: l10n.deletePackageTooltip,
        onPressed: () => _handleDeleteDownloadedPackage(item),
      );
    }

    if (isDownloading) {
      // 下载中状态：显示取消下载按钮
      return IconButton(
        icon: const Icon(Icons.cancel_outlined, color: Colors.grey, size: 22),
        tooltip: l10n.cancelDownloadAction,
        onPressed: () => _handleCancelDownload(item),
      );
    }

    // 未就绪/未下载状态：显示下载按钮
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.download_outlined, size: 18),
      label: Text(l10n.downloadAction),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        textStyle: const TextStyle(fontSize: 13.0),
      ),
      onPressed: () => _handleStartDownload(item),
    );
  }

  /// 启动在线下载
  Future<void> _handleStartDownload(DistroManifestItem item) async {
    final url = item.currentPackageSource;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final mirror = settings.downloadMirror;
    if (url == null || url.isEmpty) return;

    // 前置资源检测：若已下载完备，立即更新状态并拒绝重复下载
    if (await _downloadManager.isPackageDownloaded(item.id, url)) {
      if (mounted) {
        setState(() {
          _downloadedPackageIds.add(item.id);
        });
      }
      return;
    }

    final targetFile = await _downloadManager.startDownload(
      distroId: item.id,
      downloadUrl: url,
      mirror: mirror,
      manifestItem: item,
    );

    if (targetFile != null && mounted) {
      setState(() {
        _downloadedPackageIds.add(item.id);
      });
    } else if (mounted) {
      final progress = _downloadManager.getProgress(item.id);
      if (progress?.state == DistroDownloadState.failed) {
        DialogUtils.showErrorToast(
          context,
          l10n.downloadFailed(progress?.errorMessage ?? ''),
        );
      }
    }
  }

  /// 取消下载确认弹窗
  Future<void> _handleCancelDownload(DistroManifestItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: l10n.cancelDownloadConfirmTitle,
      message: l10n.cancelDownloadConfirmMessage,
    );

    if (confirmed && mounted) {
      await _downloadManager.cancelDownload(item.id);
    }
  }

  /// 删除已下载的系统安装包（弹确认 Dialog -> 居中转圈同步 Dialog -> 完成）
  Future<void> _handleDeleteDownloadedPackage(DistroManifestItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: l10n.deletePackageConfirmTitle,
      message: l10n.deletePackageConfirmMessage(item.name),
      confirmText: l10n.permanentDelete,
    );

    if (!confirmed || !mounted) return;

    // 弹出居中转圈的同步等待弹窗，直至删除完毕
    await DialogUtils.showSyncLoadingDialog<void>(
      context,
      message: l10n.deletingPackageProgress,
      task: () async {
        try {
          await _downloadManager.deletePackage(item.id, item.currentPackageSource);
          if (mounted) {
            setState(() {
              _downloadedPackageIds.remove(item.id);
            });
          }
        } catch (e) {
          if (mounted) {
            DialogUtils.showErrorToast(context, e.toString());
          }
        }
      },
    );

    if (mounted) {
      DialogUtils.showToast(context, l10n.deletePackageSuccess(item.name));
    }
  }
}
