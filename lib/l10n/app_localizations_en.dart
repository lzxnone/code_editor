// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Code Editor';

  @override
  String get run => 'Run';

  @override
  String get settings => 'Settings';

  @override
  String get fileDirectory => 'Project';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get save => 'Save';

  @override
  String get openFileDirectory => 'Open Project';

  @override
  String get openProjectPrompt =>
      'Please tap the button above to open a project';

  @override
  String get viewProjectHistory => 'View Project History';

  @override
  String get more => 'More';

  @override
  String get noOpenDirectory => 'No project opened';

  @override
  String get noOpenFile => 'No file opened';

  @override
  String get unnamed => 'Untitled';

  @override
  String get unknownDirectory => 'Unknown Directory';

  @override
  String get projectHistory => 'Project History';

  @override
  String get noHistory => 'No history records';

  @override
  String get deleteThisHistory => 'Delete this record';

  @override
  String get deleteHistoryTitle => 'Delete History';

  @override
  String get deleteHistoryMessage =>
      'Are you sure you want to remove this project from history?';

  @override
  String get remove => 'Remove';

  @override
  String get historyRemoved => 'History record removed';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get closeAllTabs => 'Close All Tabs';

  @override
  String get closeProject => 'Close Project';

  @override
  String get gotIt => 'Got it';

  @override
  String get done => 'Done';

  @override
  String get newFile => 'New File';

  @override
  String get newFolder => 'New Folder';

  @override
  String get fileNameHint => 'File name (e.g. main.dart)';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String get rename => 'Rename';

  @override
  String get newName => 'New name';

  @override
  String get cut => 'Cut';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select All';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get copyRelativePath => 'Copy Relative Path';

  @override
  String get copiedPathToClipboard => 'Full path copied to clipboard';

  @override
  String get copiedRelativePathToClipboard =>
      'Relative path copied to clipboard';

  @override
  String cutItem(Object name) {
    return 'Cut: $name';
  }

  @override
  String copiedItem(Object name) {
    return 'Copied: $name';
  }

  @override
  String get operationSuccess => 'Operation successful';

  @override
  String operationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String createFileFailed(Object error) {
    return 'Failed to create file: $error';
  }

  @override
  String createFolderFailed(Object error) {
    return 'Failed to create folder: $error';
  }

  @override
  String renameFailed(Object error) {
    return 'Failed to rename: $error';
  }

  @override
  String deleteFailed(Object error) {
    return 'Failed to delete: $error';
  }

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String confirmDeleteMessage(Object name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';

  @override
  String get nameInvalidChars =>
      'Name cannot contain invalid characters (\\/:*?\"<>|)';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get appThemeMode => 'App Theme Mode';

  @override
  String get followSystem => 'Follow System';

  @override
  String get followSystemSubtitle => 'Match system appearance automatically';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get lightModeSubtitle => 'Always stay light';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Always stay dark';

  @override
  String get selectAppTheme => 'Select App Theme';

  @override
  String get editorSection => 'Editor';

  @override
  String get codeHighlightTheme => 'Code Highlight Theme';

  @override
  String get selectCodeHighlightTheme => 'Select Code Highlight Theme';

  @override
  String get darkThemeCategory => 'Dark Theme';

  @override
  String get lightThemeCategory => 'Light Theme';

  @override
  String get codeFontSize => 'Font Size';

  @override
  String get decreaseFontSize => 'Decrease font size';

  @override
  String get increaseFontSize => 'Increase font size';

  @override
  String get fontSizeDialogTitle => 'Editor Font Size';

  @override
  String get wordWrap => 'Word Wrap';

  @override
  String get wordWrapSubtitle => 'Wrap long lines to fit the editor width';

  @override
  String get virtualKeyboard => 'Accessory Keyboard';

  @override
  String get virtualKeyboardSubtitle =>
      'Show accessory symbols and shortcuts below the code editor';

  @override
  String get editVirtualKeyboardConfig => 'Edit Keyboard Config';

  @override
  String get editVirtualKeyboardConfigSubtitle =>
      'Customize keyboard layout and shortcuts (JSON)';

  @override
  String get virtualKeyboardDialogTitle => 'Keyboard Config (JSON)';

  @override
  String get resetDefault => 'Reset to Default';

  @override
  String get configFormatError => 'Configuration format error';

  @override
  String get configSavedSuccess => 'Keyboard configuration saved';

  @override
  String get formatJson => 'Format';

  @override
  String get languageSection => 'Language';

  @override
  String get appLanguage => 'App Language';

  @override
  String get selectLanguage => 'Select App Language';

  @override
  String get languageFollowSystem => 'Follow System';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get refreshDirectory => 'Refresh Project';

  @override
  String get back => 'Back';

  @override
  String get darkLabel => 'Dark';

  @override
  String get lightLabel => 'Light';

  @override
  String get saveSuccess => 'Saved successfully';

  @override
  String saveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get saveChangesTitle => 'Save Changes';

  @override
  String saveChangesMessage(Object name) {
    return 'File \"$name\" has been modified, save changes?';
  }

  @override
  String get dontSave => 'Don\'t Save';

  @override
  String get saveAll => 'Save All';

  @override
  String get saveAllSuccess => 'All files saved';

  @override
  String get saveAllPromptTitle => 'Save All Changes?';

  @override
  String get saveAllPromptMessage =>
      'There are unsaved changes in the project. Do you want to save all files?';

  @override
  String get fileConflictTitle => 'File Changed Externally';

  @override
  String fileConflictMessage(Object name) {
    return 'File \"$name\" has been changed on disk. How would you like to proceed?';
  }

  @override
  String get reloadFromDisk => 'Reload from Disk';

  @override
  String get keepLocal => 'Keep Local Changes';
}
