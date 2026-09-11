import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/widgets/code_editor_app_bar.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/code_editor_tab_bar.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  static ProjectProvider _getProjectProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  void _handleSave(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    if (tabProvider.currentFilePath == null || tabProvider.currentFilePath!.isEmpty) {
      return;
    }
    final saved = await tabProvider.saveCurrentFile();
    if (saved && context.mounted) {
      final l10n = AppLocalizations.of(context);
      DialogUtils.showSuccessToast(context, l10n?.saveSuccess ?? '保存成功');
    }
  }

  void _handleSaveAll(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    final saved = await tabProvider.saveAllFiles();
    if (saved && context.mounted) {
      final l10n = AppLocalizations.of(context);
      DialogUtils.showSuccessToast(context, l10n?.saveAllSuccess ?? '所有文件已保存');
    }
  }

  void _handleCloseAllTabs(BuildContext context) async {
    await _getTabProvider(context).closeAllTabs(context);
  }

  void _handleCloseProject(BuildContext context) async {
    final tabProvider = _getTabProvider(context);
    final projectProvider = _getProjectProvider(context);
    final canProceed = await tabProvider.checkUnsavedChanges(context);
    if (canProceed && context.mounted) {
      await projectProvider.closeProject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = _getProjectProvider(context, listen: true);
    final tabProvider = _getTabProvider(context, listen: true);

    if (projectProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentFile = tabProvider.currentFilePath;
    final rootPath = projectProvider.rootPath;
    final isModified = tabProvider.isModified;

    return PopScope(
      canPop: !isModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canProceed = await _getTabProvider(context).checkUnsavedChanges(context);
        if (canProceed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: CodeEditorAppBar(
          filePath: currentFile,
          rootPath: rootPath,
          isModified: isModified,
          onSave: () => _handleSave(context),
          onSaveAll: () => _handleSaveAll(context),
          onCloseAllTabs: () => _handleCloseAllTabs(context),
          onCloseProject: () => _handleCloseProject(context),
          onRun: () {},
          onSettings: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SettingsView(),
              ),
            );
          },
        ),
        drawer: const CodeEditorDrawer(),
        body: Column(
          children: [
            const CodeEditorTabBar(),
            Expanded(
              child: CodeEditorWidget(
                filePath: currentFile,
                rootPath: rootPath,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
