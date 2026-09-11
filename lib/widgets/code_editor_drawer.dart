import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/widgets/file_directory_history_widget.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CodeEditorDrawer extends StatelessWidget {
  const CodeEditorDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rootPath = context.select<EditorProvider, String?>((p) => p.rootPath);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.fileDirectory,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新目录',
                        onPressed: () => context.read<EditorProvider>().refreshTree(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: l10n.openFileDirectory,
                        onPressed: () => context.read<EditorProvider>().openDirectory(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: l10n.viewFileDirectoryHistory,
                        onPressed: () {
                          FileDirectoryHistoryWidget.show(
                            context,
                            onSelectHistory: (selectedHistory) {
                              context.read<EditorProvider>().switchProject(selectedHistory);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    rootPath ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: FileTreeWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
