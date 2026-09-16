import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 取消"正在进行的探测"前的二次确认。
///
/// 背景：探测会在容器里长时间运行（构建工具自省 + 依赖安装），一个误触就会把整轮
/// 探测 kill 掉（已完成的模块结果保留，未完成的模块会被跳过）。因此 × 这类破坏性关闭
/// 需要用户明确确认。
///
/// 返回 true = 确认取消（真的中止探测）；false = 放弃取消（探测继续）。
/// 点弹窗外部/返回键按"放弃取消"处理（保守：不打断正在跑的探测）。
Future<bool> confirmCancelProbe(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.probeCancelConfirmTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Text(l10n.probeCancelConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.probeKeepDetecting),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(l10n.cancelProbe),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
