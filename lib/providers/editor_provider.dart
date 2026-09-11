import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/file_directory_history.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:flutter/material.dart';

/// 组合门面 Provider，委托给 SettingsProvider, ProjectProvider, TabProvider，
/// 保持向下兼容性与测试透明度。
class EditorProvider extends ChangeNotifier {
  final SettingsProvider settingsProvider;
  final ProjectProvider projectProvider;
  final TabProvider tabProvider;

  EditorProvider({
    SettingsProvider? settings,
    ProjectProvider? project,
    TabProvider? tab,
  })  : settingsProvider = settings ?? SettingsProvider(),
        projectProvider = project ?? ProjectProvider(),
        tabProvider = tab ?? TabProvider() {
    tabProvider.bindProjectProvider(projectProvider);
    settingsProvider.addListener(notifyListeners);
    projectProvider.addListener(notifyListeners);
    tabProvider.addListener(notifyListeners);
  }

  @override
  void dispose() {
    settingsProvider.removeListener(notifyListeners);
    projectProvider.removeListener(notifyListeners);
    tabProvider.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> init() async {
    await settingsProvider.init();
    await projectProvider.init();
    await tabProvider.init();
  }

  // =================== Settings Provider Getters & Methods ===================
  EditorTheme get editorTheme => settingsProvider.editorTheme;
  ThemeMode get appThemeMode => settingsProvider.appThemeMode;
  double get fontSize => settingsProvider.fontSize;
  bool get wordWrap => settingsProvider.wordWrap;
  Locale? get locale => settingsProvider.locale;

  Future<void> setEditorTheme(EditorTheme theme) => settingsProvider.setEditorTheme(theme);
  Future<void> setAppThemeMode(ThemeMode mode) => settingsProvider.setAppThemeMode(mode);
  Future<void> setFontSize(double size) => settingsProvider.setFontSize(size);
  Future<void> setWordWrap(bool wrap) => settingsProvider.setWordWrap(wrap);
  Future<void> setLocale(Locale? newLocale) => settingsProvider.setLocale(newLocale);

  // =================== Project Provider Getters & Methods ===================
  FileDirectoryHistory get history => projectProvider.history;
  String? get rootPath => projectProvider.rootPath;
  List<String> get openDirectoryPaths => projectProvider.openDirectoryPaths;
  List<FileItem> get items => projectProvider.items;
  bool get isLoading => projectProvider.isLoading;
  FileItem? get cutItem => projectProvider.cutItem;
  FileItem? get copiedItem => projectProvider.copiedItem;
  bool get canPaste => projectProvider.canPaste;

  bool isItemCut(String path) => projectProvider.isItemCut(path);
  Future<void> openDirectory() => projectProvider.openDirectory();
  Future<void> switchProject(FileDirectoryHistory selectedHistory) => projectProvider.switchProject(selectedHistory);
  Future<void> toggleDirectory(FileItem item, bool expanded) => projectProvider.toggleDirectory(item, expanded);
  Future<void> refreshTree() => projectProvider.refreshTree();
  void cut(FileItem item) => projectProvider.cut(item);
  void copy(FileItem item) => projectProvider.copy(item);
  Future<void> paste(FileItem targetDir) => projectProvider.paste(targetDir);
  Future<void> createFile(String parentDir, String name) => projectProvider.createFile(parentDir, name);
  Future<void> createDirectory(String parentDir, String name) => projectProvider.createDirectory(parentDir, name);
  Future<void> rename(FileItem item, String newName) => projectProvider.rename(item, newName);
  Future<void> delete(FileItem item) => projectProvider.delete(item);

  @visibleForTesting
  void setHistoryForTesting(FileDirectoryHistory history) {
    // ignore: invalid_use_of_visible_for_testing_member
    projectProvider.setHistoryForTesting(history);
  }

  // =================== Tab Provider Getters & Methods ===================
  List<EditorTabItem> get openTabs => tabProvider.openTabs;
  EditorTabItem? get activeTab => tabProvider.activeTab;
  String? get currentFilePath => tabProvider.currentFilePath;
  bool get isModified => tabProvider.isModified;

  bool isFileSelected(String path) => tabProvider.isFileSelected(path);
  Future<void> selectFile(FileItem item) => tabProvider.selectFile(item);
  Future<void> openFile(String path, {String? content}) => tabProvider.openFile(path, content: content);
  Future<bool> closeTab(BuildContext context, int index) => tabProvider.closeTab(context, index);
  Future<void> reorderTabs(int oldIndex, int newIndex) => tabProvider.reorderTabs(oldIndex, newIndex);
  Future<bool> saveTab(EditorTabItem tab) => tabProvider.saveTab(tab);
  Future<bool> saveCurrentFile() => tabProvider.saveCurrentFile();
  Future<bool> saveAllFiles() => tabProvider.saveAllFiles();
  Future<bool> checkUnsavedChanges(BuildContext context) => tabProvider.checkUnsavedChanges(context);
  void registerSaveHandler(Future<bool> Function()? handler) => tabProvider.registerSaveHandler(handler);
  void setModified(bool modified) => tabProvider.setModified(modified);
  void updateActiveTabContent(String content, {bool? isModified}) =>
      tabProvider.updateActiveTabContent(content, isModified: isModified);

  @visibleForTesting
  void setOpenTabsForTesting(List<EditorTabItem> tabs, {String? activePath}) {
    // ignore: invalid_use_of_visible_for_testing_member
    tabProvider.setOpenTabsForTesting(tabs, activePath: activePath);
  }
}
