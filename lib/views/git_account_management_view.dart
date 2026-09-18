import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/git_account.dart';
import '../services/git_account_service.dart';
import '../utils/dialog_utils.dart';

/// Git 账号与云端凭据管理视图
class GitAccountManagementView extends StatefulWidget {
  const GitAccountManagementView({super.key});

  @override
  State<GitAccountManagementView> createState() => _GitAccountManagementViewState();
}

class _GitAccountManagementViewState extends State<GitAccountManagementView> with SingleTickerProviderStateMixin {
  final GitAccountService _accountService = GitAccountService.instance;
  late TabController _tabController;
  bool _isLoading = false;
  String? _sshPublicKey;
  bool _isGeneratingSsh = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _accountService.loadAccounts();
    final pubKey = await _accountService.getSshPublicKey();
    if (mounted) {
      setState(() {
        _sshPublicKey = pubKey;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gitAccountManagement, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.account_box_outlined, size: 20), text: l10n.gitHostedAccounts),
            Tab(icon: const Icon(Icons.key_outlined, size: 20), text: l10n.gitSshKeys),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.gitAddAccount,
            onPressed: () => _openAddAccountDialog(context, l10n),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAccountsTab(context, theme, l10n),
                _buildSshKeysTab(context, theme, l10n),
              ],
            ),
    );
  }

  Widget _buildAccountsTab(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _accountService,
      builder: (context, _) {
        final accounts = _accountService.accounts;
        if (accounts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_sync_outlined, size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.gitNoAccountsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final acc = accounts[index];
            return _buildAccountCard(context, theme, l10n, acc);
          },
        );
      },
    );
  }

  Widget _buildAccountCard(BuildContext context, ThemeData theme, AppLocalizations l10n, GitAccount account) {
    final colorScheme = theme.colorScheme;
    final platformDisplayName = account.platform == GitPlatform.generic ? l10n.gitPlatformGeneric : account.platform.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: account.isDefault ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: account.isDefault ? 1.6 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像或平台徽标
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: account.avatarUrl != null ? NetworkImage(account.avatarUrl!) : null,
                  child: account.avatarUrl == null
                      ? Icon(_getPlatformIcon(account.platform), color: account.platform.brandColor)
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: account.platform.brandColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 1.5),
                    ),
                    child: Icon(_getPlatformIcon(account.platform), size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // 账号主体详情
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.effectiveName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (account.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.gitDefaultAccountBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$platformDisplayName${account.email.isNotEmpty ? ' · ${account.email}' : ''}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        account.authType == GitAuthType.token ? Icons.token_outlined : Icons.key_outlined,
                        size: 13,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          account.authType == GitAuthType.token ? l10n.gitAuthTypeToken : l10n.gitAuthTypeSsh,
                          style: TextStyle(fontSize: 11, color: colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 快捷操作菜单
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) async {
                switch (val) {
                  case 'default':
                    await _accountService.setDefaultAccount(account.id);
                    if (context.mounted) {
                      DialogUtils.showToast(context, l10n.gitSetAsDefaultSuccess, type: ToastType.success);
                    }
                    break;
                  case 'test':
                    _testAccountConnection(context, l10n, account);
                    break;
                  case 'edit':
                    _openAddAccountDialog(context, l10n, editingAccount: account);
                    break;
                  case 'delete':
                    _confirmDeleteAccount(context, l10n, account);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (!account.isDefault)
                  PopupMenuItem(value: 'default', child: Text(l10n.gitSetAsDefault)),
                PopupMenuItem(value: 'test', child: Text(l10n.gitTestConnection)),
                PopupMenuItem(value: 'edit', child: Text(l10n.gitEdit)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSshKeysTab(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        l10n.gitContainerSshTitle,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_sshPublicKey != null && _sshPublicKey!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _sshPublicKey!,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(l10n.gitCopyPublicKey),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _sshPublicKey!));
                              DialogUtils.showToast(context, l10n.gitPublicKeyCopied, type: ToastType.success);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _isGeneratingSsh ? null : () => _confirmRegenerateSsh(context, l10n),
                          child: _isGeneratingSsh
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(l10n.gitRegenerateKey),
                        ),
                      ],
                    ),
                  ] else ...[
                    FilledButton.icon(
                      icon: _isGeneratingSsh
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(l10n.gitGenerateEd25519Key),
                      onPressed: _isGeneratingSsh ? null : () => _generateSshKey(l10n),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 使用指导步骤 Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.gitSshGuideTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  _buildGuideStep('1', l10n.gitSshGuideStep1),
                  _buildGuideStep('2', l10n.gitSshGuideStep2),
                  _buildGuideStep('3', l10n.gitSshGuideStep3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            child: Text(num, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(GitPlatform platform) {
    switch (platform) {
      case GitPlatform.github:
        return Icons.code_rounded;
      case GitPlatform.gitee:
        return Icons.hub_rounded;
      case GitPlatform.gitlab:
        return Icons.commit_rounded;
      case GitPlatform.generic:
        return Icons.dns_rounded;
    }
  }

  Future<void> _generateSshKey(AppLocalizations l10n) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.gitGeneratingSshKey)),
          ],
        ),
      ),
    );

    setState(() => _isGeneratingSsh = true);
    final res = await _accountService.generateSshKeyPair();

    if (nav.mounted) nav.pop();

    if (mounted) {
      setState(() {
        _isGeneratingSsh = false;
        if (res.success) {
          _sshPublicKey = res.publicKey;
        }
      });
      if (res.success) {
        DialogUtils.showToast(context, l10n.gitSshKeyGenerateSuccess, type: ToastType.success);
      } else {
        DialogUtils.showToast(context, res.error ?? l10n.gitSshKeyGenerateFailed, type: ToastType.error);
      }
    }
  }

  Future<void> _confirmRegenerateSsh(BuildContext context, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.gitRegenerateSshConfirmTitle),
        content: Text(l10n.gitRegenerateSshConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.gitOverwrite)),
        ],
      ),
    );
    if (confirm == true) {
      _generateSshKey(l10n);
    }
  }

  Future<void> _testAccountConnection(BuildContext context, AppLocalizations l10n, GitAccount account) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Text(l10n.gitTestingConnection),
          ],
        ),
      ),
    );

    final res = await _accountService.verifyTokenAndFetchUserInfo(
      account.platform,
      account.token,
      customServerUrl: account.serverUrl,
    );

    if (nav.mounted) nav.pop();

    if (context.mounted) {
      if (res.success) {
        DialogUtils.showToast(
          context,
          l10n.gitTestConnectionSuccess(res.username ?? account.username),
          type: ToastType.success,
        );
      } else {
        DialogUtils.showToast(
          context,
          res.error ?? l10n.gitTestConnectionFailed,
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppLocalizations l10n, GitAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.gitDeleteAccountConfirmTitle(account.effectiveName)),
        content: Text(l10n.gitDeleteAccountConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _accountService.deleteAccount(account.id);
      if (context.mounted) {
        DialogUtils.showToast(context, l10n.gitDeleteAccountSuccess, type: ToastType.success);
      }
    }
  }

  Future<void> _openAddAccountDialog(BuildContext context, AppLocalizations l10n, {GitAccount? editingAccount}) async {
    final res = await showDialog<GitAccount>(
      context: context,
      builder: (ctx) => _AddOrEditAccountDialog(editingAccount: editingAccount),
    );

    if (res != null) {
      await _accountService.saveAccount(res);
      if (context.mounted) {
        DialogUtils.showToast(context, editingAccount != null ? l10n.gitAccountUpdatedSuccess : l10n.gitAccountSavedSuccess, type: ToastType.success);
      }
    }
  }
}

/// 添加或编辑账号弹窗
class _AddOrEditAccountDialog extends StatefulWidget {
  final GitAccount? editingAccount;

  const _AddOrEditAccountDialog({this.editingAccount});

  @override
  State<_AddOrEditAccountDialog> createState() => _AddOrEditAccountDialogState();
}

class _AddOrEditAccountDialogState extends State<_AddOrEditAccountDialog> {
  late GitPlatform _platform;
  late TextEditingController _usernameCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _serverUrlCtrl;
  late TextEditingController _emailCtrl;
  bool _isVerifying = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    final acc = widget.editingAccount;
    _platform = acc?.platform ?? GitPlatform.github;
    _usernameCtrl = TextEditingController(text: acc?.username ?? '');
    _tokenCtrl = TextEditingController(text: acc?.token ?? '');
    _serverUrlCtrl = TextEditingController(text: acc?.serverUrl ?? '');
    _emailCtrl = TextEditingController(text: acc?.email ?? '');
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _tokenCtrl.dispose();
    _serverUrlCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTokenUrl(BuildContext context, AppLocalizations l10n) async {
    final String urlStr;
    switch (_platform) {
      case GitPlatform.github:
        urlStr = 'https://github.com/settings/tokens/new?scopes=repo,read:user,user:email';
        break;
      case GitPlatform.gitee:
        urlStr = 'https://gitee.com/profile/personal_access_tokens/new';
        break;
      case GitPlatform.gitlab:
        urlStr = 'https://gitlab.com/-/user_settings/personal_access_tokens';
        break;
      case GitPlatform.generic:
        urlStr = '';
        break;
    }

    if (urlStr.isEmpty) return;

    Clipboard.setData(ClipboardData(text: urlStr));

    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        debugPrint('[GitAccount] 启动浏览器失败: $e');
      }
    }

    if (context.mounted) {
      DialogUtils.showToast(context, l10n.gitTokenCopiedOpeningBrowser, type: ToastType.info);
    }
  }

  Future<void> _handleSave(AppLocalizations l10n) async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _verifyError = l10n.gitEnterTokenPrompt);
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    // 自动调用 API 校验 Token 并抓取真实身份信息
    final verifyRes = await GitAccountService.instance.verifyTokenAndFetchUserInfo(
      _platform,
      token,
      customServerUrl: _platform == GitPlatform.generic ? _serverUrlCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (!verifyRes.success) {
      setState(() {
        _isVerifying = false;
        _verifyError = verifyRes.error ?? l10n.gitTokenVerifyFailed;
      });
      return;
    }

    final finalUsername = verifyRes.username ?? _usernameCtrl.text.trim();
    final finalEmail = verifyRes.email?.isNotEmpty == true ? verifyRes.email! : _emailCtrl.text.trim();
    final finalServerUrl = _platform == GitPlatform.generic
        ? (_serverUrlCtrl.text.trim().isNotEmpty ? _serverUrlCtrl.text.trim() : _platform.defaultServerUrl)
        : _platform.defaultServerUrl;

    final updated = GitAccount(
      id: widget.editingAccount?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      platform: _platform,
      username: finalUsername,
      displayName: verifyRes.displayName ?? finalUsername,
      email: finalEmail,
      authType: GitAuthType.token,
      token: token,
      serverUrl: finalServerUrl,
      avatarUrl: verifyRes.avatarUrl ?? widget.editingAccount?.avatarUrl,
      isDefault: widget.editingAccount?.isDefault ?? false,
      createdAt: widget.editingAccount?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.editingAccount != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.gitEditAccount : l10n.gitAddAccount),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 平台选择器
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GitPlatform.values.map((p) {
                  final isSelected = _platform == p;
                  final pName = p == GitPlatform.generic ? l10n.gitPlatformGeneric : p.name;
                  return ChoiceChip(
                    label: Text(pName),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: p.brandColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? p.brandColor : null,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _platform = p);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 自建服务器 URL 输入 (多行输入，仅通用/自建 Git 需填写，GitHub、Gitee、GitLab 均为统一官方地址)
              if (_platform == GitPlatform.generic) ...[
                TextField(
                  controller: _serverUrlCtrl,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.gitServerUrl,
                    hintText: 'https://git.example.com',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 令牌输入 (多行输入)
              TextField(
                controller: _tokenCtrl,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.gitTokenLabel,
                  hintText: l10n.gitTokenHint,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_outlined, size: 20),
                    tooltip: l10n.paste,
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        _tokenCtrl.text = data.text!.trim();
                      }
                    },
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              // 快捷前往获取 Token (自建 Git 无统一平台网页，不展示该按钮)
              if (_platform != GitPlatform.generic) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      l10n.gitGetToken,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _openTokenUrl(context, l10n),
                  ),
                ),
              ],

              if (_verifyError != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _verifyError!,
                    style: TextStyle(fontSize: 12, color: colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : () => _handleSave(l10n),
          child: _isVerifying
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.gitVerifyAndSave),
        ),
      ],
    );
  }
}
