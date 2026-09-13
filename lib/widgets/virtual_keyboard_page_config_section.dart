import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 虚拟小键盘当前页的基础属性配置板块（行按钮数）
class VirtualKeyboardPageConfigSection extends StatelessWidget {
  final int count;
  final ValueChanged<int> onCountChanged;

  const VirtualKeyboardPageConfigSection({
    super.key,
    required this.count,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.keyboardPageConfigSectionTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.keyboardRowButtons, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      l10n.keyboardRowGridDescription(count),
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 18),
                      tooltip: l10n.keyboardDecreaseRowButtonsTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: count > 3 ? () => onCountChanged(count - 1) : null,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 44),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: l10n.keyboardIncreaseRowButtonsTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: count < 12 ? () => onCountChanged(count + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
