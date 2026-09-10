import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/file_directory_history.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/services/file_directory_history_service.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:code_editor/widgets/file_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  List<FileItem> _items = [];
  FileDirectoryHistory _history = const FileDirectoryHistory(rootPath: null, lastOpenedFilePath: "未命名");
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFileItems();
  }

  Future<void> _loadFileItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FileDirectoryHistory? lastHistory = await FileDirectoryHistoryService.instance.getLastHistory();
      if(lastHistory == null) {
        if(mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }else {
        final path = lastHistory.rootPath;
        List<FileItem> items = (path != null && path.trim().isNotEmpty)
            ? await FileService.instance.buildTree(
                path,
                openDirectoryPaths: lastHistory.openDirectoryPaths,
              )
            : [];
        if(mounted) {
          setState(() {
            _items = items;
            _history = lastHistory;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if(_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final fileName = _history.lastOpenedFilePath;
    final rootPath = _history.rootPath;

    return Scaffold(
      //顶部导航栏
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        title: Text(fileName != null ? p.basename(fileName) : ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: l10n.undo,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: l10n.redo,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: l10n.save,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: l10n.run,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () {},
          ),
        ],
      ),

      //侧边栏
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(l10n.fileDirectory, style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold
                    )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.folder_open),
                      tooltip: l10n.openFileDirectory,
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: l10n.viewFileDirectoryHistory,
                      onPressed: () {},
                    ),
                  ]),
                  Text(rootPath ?? '')
                ],
              ),
            ),
            FileTreeWidget(rootFileItem: _items.isEmpty ? null : _items[0])
          ],
        ),
      ),

      body: CodeEditorWidget(filePath: _history.lastOpenedFilePath, rootPath: _history.rootPath)
    );
  }
}
