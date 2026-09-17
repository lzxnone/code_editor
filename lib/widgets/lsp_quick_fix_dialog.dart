import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../l10n/app_localizations.dart';
import '../services/lsp/lsp_manager.dart';
import '../services/lsp/lsp_protocol.dart';
import '../services/lsp/lsp_workspace_edit_applier.dart';

/// 快速修复操作弹窗（展示诊断信息及 LSP CodeAction 选项）
class LspQuickFixDialog {
  static Future<void> show(
    BuildContext context, {
    required String filePath,
    required int lineIndex,
    required List<LspDiagnostic> diagnostics,
    required CodeLineEditingController controller,
    VoidCallback? onDismiss,
  }) async {
    final session = LspManager.instance.getExistingSession(filePath);
    List<LspCodeAction> actions = [];

    if (session != null && diagnostics.isNotEmpty && lineIndex < controller.lineCount) {
      final lineLength = controller.codeLines[lineIndex].text.length;
      final range = LspRange(
        start: LspPosition.pos(lineIndex, 0),
        end: LspPosition.pos(lineIndex, lineLength),
      );
      try {
        actions = await session.getCodeActions(filePath, range, diagnostics);
      } catch (_) {}
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx) ?? AppLocalizations.of(context)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.lspQuickFixTitle(lineIndex + 1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...diagnostics.map((d) {
                  final isErr = d.severity == LspDiagnosticSeverity.error;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isErr ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isErr ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isErr ? Icons.error_outline : Icons.warning_amber_outlined,
                          size: 18,
                          color: isErr ? Colors.redAccent : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16),
                if (actions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.lspNoFixAvailable,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...actions.map((act) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_fix_high, color: Colors.blueAccent),
                      title: Text(act.title, style: const TextStyle(fontSize: 14)),
                      trailing: act.isPreferred ? Chip(label: Text(l10n.recommended, style: const TextStyle(fontSize: 11))) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (act.edit != null) {
                          LspWorkspaceEditApplier.applyWorkspaceEdit(
                            controller,
                            act.edit!,
                            currentFilePath: filePath,
                          );
                        }
                        onDismiss?.call();
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
