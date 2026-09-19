import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../services/internal_project_service.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/git_error_mapper.dart';

/// 仓库完整性自检面板（底部弹出）
///
/// 起因：`.git/objects` 中的对象在 PRoot 容器重建等场景下会丢失，而用户
/// 只会在某次提交时撞上 `invalid object ... Error building trees`，完全
/// 不知道原因。这个面板把问题提前暴露，并给出可执行的处置建议。
class GitRepairPanel extends StatefulWidget {
  const GitRepairPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GitRepairPanel(),
    );
  }

  @override
  State<GitRepairPanel> createState() => _GitRepairPanelState();
}

class _GitRepairPanelState extends State<GitRepairPanel> {
  @override
  void initState() {
    super.initState();
    // 打开即自动跑一次；面板本身不产生副作用（fsck 只读）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GitProvider>();
      if (provider.fsckReport == null && !provider.isFsckRunning) {
        provider.runFsck();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<GitProvider>();
    final report = provider.fsckReport;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.gitRepairCheck,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('git_fsck_rerun_button'),
                  onPressed: provider.isFsckRunning ? null : provider.runFsck,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.gitRepairCheckRerun),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.isFsckRunning)
              _buildRunning(theme, l10n)
            else if (report == null)
              _buildRunning(theme, l10n)
            else
              _buildReport(theme, l10n, report),
          ],
        ),
      ),
    );
  }

  Widget _buildRunning(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.gitRepairCheckRunning,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(
    ThemeData theme,
    AppLocalizations l10n,
    GitFsckReport report,
  ) {
    final colorScheme = theme.colorScheme;

    // 三种结局：健康 / 对象丢失 / 未能完成
    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String hint;

    if (report.isHealthy) {
      bg = colorScheme.primaryContainer.withValues(alpha: 0.5);
      fg = colorScheme.onPrimaryContainer;
      icon = Icons.verified_outlined;
      title = l10n.gitRepairCheckHealthy;
      hint = l10n.gitRepairCheckHealthyHint;
    } else if (report.hasObjectLoss) {
      bg = colorScheme.errorContainer.withValues(alpha: 0.5);
      fg = colorScheme.onErrorContainer;
      icon = Icons.report_problem_outlined;
      title = l10n.gitRepairCheckObjectLoss(report.problemCount);
      hint = l10n.gitRepairCheckObjectLossHint;
    } else {
      bg = colorScheme.tertiaryContainer.withValues(alpha: 0.5);
      fg = colorScheme.onTertiaryContainer;
      icon = Icons.help_outline;
      title = l10n.gitRepairCheckFailed;
      hint = l10n.gitRepairCheckFailedHint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hint,
                      style: TextStyle(fontSize: 11, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 悬空对象是正常现象，只在存在时用一行说明，避免制造焦虑
        if (report.dangling.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.gitRepairCheckDangling(report.dangling.length),
            style: TextStyle(
              fontSize: 10.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        // 具体问题明细（最多展示若干条，避免超长）
        if (report.problemCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                [...report.missing, ...report.corrupt].take(30).join('\n'),
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.gitRepairAdviceTitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          _buildAdvice(l10n.gitRepairAdviceRemoveStale, colorScheme),
          const SizedBox(height: 3),
          _buildAdvice(l10n.gitRepairAdviceRestore, colorScheme),
        ],
      ],
    );
  }

  Widget _buildAdvice(String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 4, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 克隆远端仓库对话框
class GitCloneDialog extends StatefulWidget {
  const GitCloneDialog({super.key});

  /// 返回克隆成功后的目标目录路径；取消或失败返回 null
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const GitCloneDialog(),
    );
  }

  @override
  State<GitCloneDialog> createState() => _GitCloneDialogState();
}

class _GitCloneDialogState extends State<GitCloneDialog> {
  final _urlCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _depthCtrl = TextEditingController();

  String? _urlError;
  String? _dirError;
  bool _cloning = false;
  GitOperationProgress? _progress;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _dirCtrl.dispose();
    _branchCtrl.dispose();
    _depthCtrl.dispose();
    super.dispose();
  }

  /// 从仓库地址推导默认目录名：`.../llama.cpp.git` → `llama.cpp`
  String _deriveDirName(String url) {
    var path = url.trim();
    // scp 风格 git@host:owner/repo.git
    final scpMatch = RegExp(r'^[^@]+@[^:]+:(.+)$').firstMatch(path);
    if (scpMatch != null) path = scpMatch.group(1)!;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    return segments.last.replaceAll(RegExp(r'\.git$'), '');
  }

  Future<void> _submit(AppLocalizations strings) async {
    final url = _urlCtrl.text.trim();
    final dirName = _dirCtrl.text.trim().isEmpty
        ? _deriveDirName(url)
        : _dirCtrl.text.trim();

    setState(() {
      _urlError = url.isEmpty ? strings.gitCloneUrlRequired : null;
      _dirError = dirName.isEmpty ? strings.gitCloneDirRequired : null;
    });
    if (url.isEmpty || dirName.isEmpty) return;

    final projectsDir = await InternalProjectService.instance.getProjectsDirectory();
    if (!mounted) return;
    final targetDir = Directory(p.join(projectsDir.path, dirName));
    if (targetDir.existsSync()) {
      setState(() => _dirError = strings.gitCloneDirExists);
      return;
    }

    final depthText = _depthCtrl.text.trim();
    final depth = depthText.isEmpty ? null : int.tryParse(depthText);

    setState(() {
      _cloning = true;
      _progress = null;
    });

    // 在 async gap 之前取出 provider，避免跨越 await 使用 BuildContext
    final provider = context.read<GitProvider>();

    // 克隆期间订阅进度；Provider 会持续 notifyListeners
    void listener() {
      if (!mounted) return;
      final progress = provider.cloneProgress;
      if (progress != _progress) setState(() => _progress = progress);
    }

    provider.addListener(listener);
    try {
      final res = await provider.cloneRepository(
        parentDir: projectsDir.path,
        url: url,
        targetDirName: dirName,
        branch: _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
        depth: depth,
      );
      if (!mounted) return;

      if (res.success) {
        Navigator.of(context).pop(targetDir.path);
      } else if (res.cancelled) {
        // 取消：清理可能残留的半成品目录，避免留下不可用的项目
        try {
          if (targetDir.existsSync()) targetDir.deleteSync(recursive: true);
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        setState(() => _cloning = false);
        DialogUtils.showToast(
          context,
          provider.lastRemoteError?.kind.message(strings) ??
              strings.gitCloneFailed,
          type: ToastType.error,
        );
      }
    } finally {
      provider.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.gitClone),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('git_clone_url_field'),
              controller: _urlCtrl,
              enabled: !_cloning,
              decoration: InputDecoration(
                labelText: l10n.gitCloneUrl,
                hintText: l10n.gitCloneUrlHint,
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('git_clone_dir_field'),
              controller: _dirCtrl,
              enabled: !_cloning,
              decoration: InputDecoration(
                labelText: l10n.gitCloneDirName,
                hintText: l10n.gitCloneDirNameHint,
                errorText: _dirError,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _branchCtrl,
                    enabled: !_cloning,
                    decoration: InputDecoration(
                      labelText: l10n.gitCloneBranch,
                      hintText: l10n.gitCloneBranchHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _depthCtrl,
                    enabled: !_cloning,
                    decoration: InputDecoration(
                      labelText: l10n.gitCloneDepth,
                      hintText: l10n.gitCloneDepthHint,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_cloning) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _progress?.raw.isNotEmpty == true
                          ? '${l10n.gitCloneRunning} ${_progress!.raw}'
                          : l10n.gitCloneRunning,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _progress?.percent != null
                      ? _progress!.percent! / 100.0
                      : null,
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cloning
              ? () => context.read<GitProvider>().cancelClone()
              : () => Navigator.of(context).pop(),
          child: Text(_cloning ? l10n.gitCloneCancel : l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('git_clone_confirm_button'),
          onPressed: _cloning ? null : () => _submit(l10n),
          child: Text(l10n.gitClone),
        ),
      ],
    );
  }
}
