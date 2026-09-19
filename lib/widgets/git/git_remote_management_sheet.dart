import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/git_error_mapper.dart';

/// 远程仓库管理面板（底部弹出）
///
/// 支持列出 / 添加 / 编辑地址 / 重命名 / 移除 / 清理失效分支 / 连接自检。
/// 所有操作都经由 [GitProvider]，与同步工具条共用同一套错误处理。
class GitRemoteManagementSheet extends StatelessWidget {
  const GitRemoteManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GitRemoteManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<GitProvider>();
    final remotes = provider.remotes;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.gitRemoteManagement,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('git_remote_add_button'),
                  onPressed: () => _showAddDialog(context, l10n, provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.gitAddRemote),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (remotes.isEmpty)
              _buildEmptyState(context, l10n)
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: remotes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) => _buildRemoteTile(
                    ctx,
                    l10n,
                    provider,
                    remotes[index],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 34,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.gitNoRemoteConfigured,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gitNoRemoteDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteTile(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        remote.isSsh ? Icons.vpn_key_outlined : Icons.language_outlined,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        remote.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            remote.fetchUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5),
          ),
          // 仅当推送地址与抓取地址不同才展示，避免视觉噪音
          if (remote.pushUrl != null)
            Text(
              'push: ${remote.pushUrl}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: l10n.gitRemoteEdit,
        onSelected: (action) =>
            _handleAction(context, l10n, provider, remote, action),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'test', child: Text(l10n.gitCheckConnection)),
          PopupMenuItem(value: 'edit', child: Text(l10n.gitRemoteEdit)),
          PopupMenuItem(value: 'rename', child: Text(l10n.gitRemoteName)),
          PopupMenuItem(value: 'prune', child: Text(l10n.gitRemotePrune)),
          if (remote.host != null)
            PopupMenuItem(value: 'open', child: Text(l10n.gitRemoteFetchUrl)),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: Text(
              l10n.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
    String action,
  ) async {
    switch (action) {
      case 'test':
        await _testConnection(context, l10n, provider, remote);
        break;
      case 'edit':
        await _showEditDialog(context, l10n, provider, remote);
        break;
      case 'rename':
        await _showRenameDialog(context, l10n, provider, remote);
        break;
      case 'prune':
        final res = await provider.pruneRemote(remote.name);
        if (!context.mounted) return;
        DialogUtils.showToast(
          context,
          res.success ? l10n.gitRemotePruned : res.stderr,
          type: res.success ? ToastType.success : ToastType.error,
        );
        break;
      case 'open':
        final url = _webUrlFor(remote);
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
        break;
      case 'remove':
        await _confirmRemove(context, l10n, provider, remote);
        break;
    }
  }

  /// 把 git 地址转换为可在浏览器打开的网页地址
  String? _webUrlFor(GitRemote remote) {
    final host = remote.host;
    final path = remote.repositoryPath;
    if (host == null || path == null) return null;
    final cleanPath = path.replaceAll(RegExp(r'\.git$'), '');
    if (remote.isSsh) {
      return 'https://$host/$cleanPath';
    }
    final uri = Uri.tryParse(remote.fetchUrl);
    if (uri == null) return null;
    return '${uri.scheme}://$host/$cleanPath';
  }

  /// 连接与认证自检：比让用户"推一次试试"友好得多
  Future<void> _testConnection(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
  ) async {
    final res = await provider.checkRemoteAuth(remote.fetchUrl);
    if (!context.mounted) return;
    final error = provider.lastRemoteError;
    if (res.success) {
      DialogUtils.showToast(context, l10n.gitCheckConnectionSuccess, type: ToastType.success);
    } else if (error != null) {
      // 与同步条一致：按错误类型取 l10n 文案，附上 git 原始错误行（若有）
      final detail = error.rawDetail;
      final text = detail == null || detail.isEmpty
          ? error.kind.message(l10n)
          : '${error.kind.message(l10n)}\n$detail';
      DialogUtils.showToast(context, text, type: ToastType.error);
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
  ) async {
    final confirmed = await DialogUtils.showDestructiveConfirmDialog(
      context,
      title: '${l10n.delete} ${remote.name}',
      message: l10n.gitRemoteRemoveConfirm(remote.name),
      icon: Icons.cloud_off_outlined,
    );
    if (!confirmed || !context.mounted) return;

    final res = await provider.removeRemote(remote.name);
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success ? l10n.gitRemoteRemoved(remote.name) : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
  ) async {
    final result = await showDialog<({String name, String url, String pushUrl})>(
      context: context,
      builder: (_) => _RemoteEditDialog(
        title: l10n.gitAddRemote,
        initialName: provider.remotes.isEmpty ? 'origin' : '',
      ),
    );
    if (result == null || !context.mounted) return;

    final res = await provider.addRemote(
      result.name,
      result.url,
      pushUrl: result.pushUrl.isEmpty ? null : result.pushUrl,
    );
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success ? l10n.gitRemoteAdded(result.name) : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
  ) async {
    final result = await showDialog<({String name, String url, String pushUrl})>(
      context: context,
      builder: (_) => _RemoteEditDialog(
        title: l10n.gitRemoteEdit,
        initialName: remote.name,
        initialUrl: remote.fetchUrl,
        initialPushUrl: remote.pushUrl ?? '',
        lockName: true,
      ),
    );
    if (result == null || !context.mounted) return;

    final res = await provider.setRemoteUrl(remote.name, result.url);
    if (!res.success) {
      if (!context.mounted) return;
      DialogUtils.showToast(context, res.stderr, type: ToastType.error);
      return;
    }

    if (result.pushUrl.isNotEmpty && result.pushUrl != remote.pushUrl) {
      await provider.setRemoteUrl(remote.name, result.pushUrl, push: true);
    }
    if (!context.mounted) return;
    DialogUtils.showToast(context, l10n.gitRemoteUrlUpdated, type: ToastType.success);
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    AppLocalizations l10n,
    GitProvider provider,
    GitRemote remote,
  ) async {
    final newName = await DialogUtils.showInputDialog(
      context,
      title: l10n.gitRemoteName,
      hintText: l10n.gitRemoteNameHint,
      initialValue: remote.name,
    );
    if (newName == null || newName.trim().isEmpty || !context.mounted) return;

    final res = await provider.renameRemote(remote.name, newName.trim());
    if (!context.mounted) return;
    DialogUtils.showToast(
      context,
      res.success
          ? l10n.gitRemoteRenamed(remote.name, newName.trim())
          : res.stderr,
      type: res.success ? ToastType.success : ToastType.error,
    );
  }
}

/// 添加 / 编辑远程仓库对话框
class _RemoteEditDialog extends StatefulWidget {
  const _RemoteEditDialog({
    required this.title,
    this.initialName = '',
    this.initialUrl = '',
    this.initialPushUrl = '',
    this.lockName = false,
  });

  final String title;
  final String initialName;
  final String initialUrl;
  final String initialPushUrl;
  final bool lockName;

  @override
  State<_RemoteEditDialog> createState() => _RemoteEditDialogState();
}

class _RemoteEditDialogState extends State<_RemoteEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _pushUrlController;
  String? _nameError;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _urlController = TextEditingController(text: widget.initialUrl);
    _pushUrlController = TextEditingController(text: widget.initialPushUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _pushUrlController.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final pushUrl = _pushUrlController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? l10n.gitRemoteNameRequired : null;
      _urlError = url.isEmpty ? l10n.gitRemoteUrlRequired : null;
    });

    if (name.isEmpty || url.isEmpty) return;

    Navigator.of(context).pop((name: name, url: url, pushUrl: pushUrl));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('git_remote_name_field'),
              controller: _nameController,
              enabled: !widget.lockName,
              decoration: InputDecoration(
                labelText: l10n.gitRemoteName,
                hintText: l10n.gitRemoteNameHint,
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('git_remote_url_field'),
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.gitRemoteUrl,
                hintText: l10n.gitRemoteUrlHint,
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('git_remote_push_url_field'),
              controller: _pushUrlController,
              decoration: InputDecoration(
                labelText: l10n.gitRemotePushUrl,
                hintText: l10n.gitRemotePushUrlHint,
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('git_remote_confirm_button'),
          onPressed: () => _submit(l10n),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
