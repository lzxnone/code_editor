import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class CodeEditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? filePath;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final VoidCallback? onRun;
  final VoidCallback? onSettings;

  const CodeEditorAppBar({
    super.key,
    required this.filePath,
    this.onUndo,
    this.onRedo,
    this.onSave,
    this.onRun,
    this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final path = filePath;

    return AppBar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      title: Text(path != null && path.isNotEmpty ? p.basename(path) : ''),
      actions: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.undo),
          tooltip: l10n.undo,
          onPressed: onUndo ?? () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.redo),
          tooltip: l10n.redo,
          onPressed: onRedo ?? () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.save_outlined),
          tooltip: l10n.save,
          onPressed: onSave ?? () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_arrow),
          tooltip: l10n.run,
          onPressed: onRun ?? () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.settings),
          tooltip: l10n.settings,
          onPressed: onSettings ?? () {},
        ),
      ],
    );
  }
}
