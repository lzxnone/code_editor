import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<EditorProvider, bool>((p) => p.isLoading);
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentFile = context.select<EditorProvider, String?>((p) => p.currentFilePath);
    final rootPath = context.select<EditorProvider, String?>((p) => p.rootPath);

    return Scaffold(
      appBar: CodeEditorAppBar(
        filePath: currentFile,
        onUndo: () {},
        onRedo: () {},
        onSave: () {},
        onRun: () {},
        onSettings: () {},
      ),
      drawer: const CodeEditorDrawer(),
      body: CodeEditorWidget(
        filePath: currentFile,
        rootPath: rootPath,
      ),
    );
  }
}
