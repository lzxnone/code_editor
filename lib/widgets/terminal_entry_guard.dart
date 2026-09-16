import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 「进入终端」前的探测占用确认。
///
/// 背景：任务探测会占用当前容器执行构建工具自省与依赖自动安装；此时进入终端并在里面
/// 做安装软件包、构建等操作，可能与探测互相阻塞（包管理器锁、构建缓存写冲突）或产生异常。
/// 因此主页面「更多 → 终端」入口在探测进行中时先弹提示，由用户决定是否仍进入。
///
/// 返回 true = 继续进入终端；false = 取消（不进入）。
/// 点弹窗外部/返回键同样按"取消"处理（保守策略：不进入）。
Future<bool> confirmEnterTerminalWhileProbing(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.probeBusyEnterTerminalTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Text(l10n.probeBusyEnterTerminalMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.terminal, size: 18),
          label: Text(l10n.probeEnterTerminalAnyway),
        ),
      ],
    ),
  );

  return result ?? false;
}
