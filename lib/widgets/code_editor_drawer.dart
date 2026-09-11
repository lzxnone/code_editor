import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/widgets/file_directory_history_widget.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CodeEditorDrawer extends StatelessWidget {
  const CodeEditorDrawer({super.key});

  static ProjectProvider _getProjectProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
    } catch (_) {
      final editor = listen ? context.watch<EditorProvider>() : context.read<EditorProvider>();
      return editor.projectProvider;
    }
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    try {
      return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
    } catch (_) {
      final editor = listen ? context.watch<EditorProvider>() : context.read<EditorProvider>();
      return editor.tabProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final projectProvider = _getProjectProvider(context, listen: true);
    final rootPath = projectProvider.rootPath;

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
                        tooltip: l10n.refreshDirectory,
                        onPressed: () => _getProjectProvider(context).refreshTree(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: l10n.openFileDirectory,
                        onPressed: () async {
                          final canProceed = await _getTabProvider(context).checkUnsavedChanges(context);
                          if (!canProceed || !context.mounted) return;
                          _getProjectProvider(context).openDirectory();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: l10n.viewFileDirectoryHistory,
                        onPressed: () {
                          FileDirectoryHistoryWidget.show(
                            context,
                            onSelectHistory: (selectedHistory) async {
                              final canProceed = await _getTabProvider(context).checkUnsavedChanges(context);
                              if (!canProceed || !context.mounted) return;
                              _getProjectProvider(context).switchProject(selectedHistory);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    rootPath ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
