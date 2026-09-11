import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class CodeEditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? filePath;
  final String? rootPath;
  final bool isModified;
  final VoidCallback? onSave;
  final VoidCallback? onSaveAll;
  final VoidCallback? onRun;
  final VoidCallback? onSettings;

  const CodeEditorAppBar({
    super.key,
    required this.filePath,
    this.rootPath,
    this.isModified = false,
    this.onSave,
    this.onSaveAll,
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

    final String titleText;
    final String? subtitleText;
    if (path != null && path.isNotEmpty) {
      final base = p.basename(path);
      titleText = isModified ? '* $base' : base;

      if (rootPath != null && rootPath!.trim().isNotEmpty) {
        final cleanRoot = p.normalize(rootPath!.trim());
        final cleanFile = p.normalize(path.trim());
        final dirPath = p.dirname(cleanFile);

        if (dirPath == cleanRoot || !p.isWithin(cleanRoot, cleanFile)) {
          subtitleText = '/';
        } else {
          final rel = p.relative(dirPath, from: cleanRoot);
          final formattedRel = rel.replaceAll(r'\', '/');
          subtitleText = formattedRel.startsWith('/') ? formattedRel : '/$formattedRel';
        }
      } else {
        subtitleText = '/';
      }
    } else {
      titleText = '';
      subtitleText = null;
    }

    return AppBar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onSurface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titleText,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitleText != null)
            Text(
              subtitleText,
              style: TextStyle(
                fontSize: 11.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_arrow),
          tooltip: l10n.run,
          onPressed: onRun ?? () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.save_outlined),
          tooltip: l10n.save,
          onPressed: onSave ?? () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.more,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            if (value == 'save_all') {
              onSaveAll?.call();
            } else if (value == 'settings') {
              onSettings?.call();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'save_all',
              child: Row(
                children: [
                  const Icon(Icons.save_as_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.saveAll),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.settings),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
