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
  String get uiFont => 'Interface Font';

  @override
  String get selectUiFont => 'Select Interface Font';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get selectThemeColor => 'Select Theme Color';

  @override
  String get terminalBackgroundColor => 'Terminal Background';

  @override
  String get selectTerminalBackgroundColor => 'Select Terminal Background';

  @override
  String get uiFontPreview => 'Code Editor interface font preview 123';

  @override
  String get codeFont => 'Code Font';

  @override
  String get selectCodeFont => 'Select Code Font';

  @override
  String get codeFontPreview => 'const app = \"Code Editor\"; // code preview';

  @override
  String get terminalFont => 'Terminal Font';

  @override
  String get selectTerminalFont => 'Select Terminal Font';

  @override
  String get terminalFontPreview => '\$ git status -s # terminal font preview';

  @override
  String fontName(String font) {
    String _temp0 = intl.Intl.selectLogic(font, {
      'system_default': 'System Default',
      'sans_serif': 'Sans-Serif',
      'serif': 'Serif (Songti)',
      'monospace': 'System Monospace',
      'consolas': 'Consolas',
      'courier_new': 'Courier New',
      'menlo': 'Menlo / Monaco',
      'jetbrains_mono': 'JetBrains Mono',
      'fira_code': 'Fira Code',
      'other': '$font',
    });
    return '$_temp0';
  }

  @override
  String get decreaseFontSize => 'Decrease font size';

  @override
  String get increaseFontSize => 'Increase font size';

  @override
  String get fontSizeDialogTitle => 'Editor Font Size';

  @override
  String get indentSize => 'Indent Size';

  @override
  String get selectIndentSize => 'Select Indent Size';

  @override
  String spacesCount(int count) {
    return '$count Spaces';
  }

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
      'Customize keyboard layout and shortcuts';

  @override
  String get terminalVirtualKeyboard => 'Terminal Accessory Keyboard';

  @override
  String get terminalVirtualKeyboardSubtitle =>
      'Show special keys and command shortcuts below the terminal';

  @override
  String get editTerminalVirtualKeyboardConfig =>
      'Edit Terminal Keyboard Config';

  @override
  String get editTerminalVirtualKeyboardConfigSubtitle =>
      'Customize Esc / Tab / Ctrl combos and other terminal keys';

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

  @override
  String get storagePermissionRequiredTitle => 'Storage Access Required';

  @override
  String get storagePermissionRequiredMessage =>
      'Code Editor requires \"All files access\" permission to read, create, and save project files on your device.\n\nPlease enable it in the system settings page.';

  @override
  String get goToSettings => 'Settings';

  @override
  String get terminal => 'Terminal';

  @override
  String terminalWithSystem(String system) {
    return 'Terminal · $system';
  }

  @override
  String get sessionDefaultName => 'Session';

  @override
  String get systemManagement => 'System Management';

  @override
  String get systemManagementTooltip => 'System Management & Selection';

  @override
  String get sessionListTooltip => 'Session List';

  @override
  String get noActiveSessions => 'No active sessions';

  @override
  String get terminalInputHint => 'Enter command...';

  @override
  String get sendCommandTooltip => 'Send Command';

  @override
  String get importNewSystem => 'Import New System';

  @override
  String get importBuiltinAlpine => 'Import from App (Alpine)';

  @override
  String get importExternalTarGz => 'Import from External (.tar.gz)';

  @override
  String get selectSystemDefaultPrompt =>
      'Select a system as default; new terminals will start in this system:';

  @override
  String get noSystemsPrompt =>
      'No systems available. Tap \"+\" at top right to import';

  @override
  String get importBuiltinAlpineTitle => 'Import Built-in Alpine System';

  @override
  String systemNameHintWithDefault(String name) {
    return 'System name (e.g. $name)';
  }

  @override
  String systemImportSuccess(String name) {
    return 'System \"$name\" imported and ready';
  }

  @override
  String get importExternalSystemTitle => 'Import External System';

  @override
  String get systemNameHint => 'System Name';

  @override
  String externalSystemImportSuccess(String name) {
    return 'External system \"$name\" imported and ready';
  }

  @override
  String get deleteSystemConfirmTitle => 'High-Risk Operation: Delete System';

  @override
  String deleteSystemConfirmMessage(String name) {
    return 'Are you sure you want to permanently delete system \"$name\"?\n\n⚠️ This will physically erase all internal data and installed packages. This cannot be undone!\n\nAll associated terminal sessions will also be closed.';
  }

  @override
  String get permanentDelete => 'Permanently Delete';

  @override
  String deleteSystemSuccess(String name) {
    return 'System \"$name\" and associated sessions deleted';
  }

  @override
  String get deleteSystemTooltip =>
      'Permanently delete this system (High risk)';

  @override
  String get preparingInitialization => 'Preparing initialization...';

  @override
  String get cancellingAndCleaning =>
      'Cancelling and cleaning leftover directory...';

  @override
  String cancelledImportSystem(String name) {
    return 'Cancelled importing system \"$name\"';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String importingSystemTitle(String name) {
    return 'Importing: $name';
  }

  @override
  String get cancelImport => 'Cancel Import';

  @override
  String get interrupting => 'Interrupting...';

  @override
  String get sessionDrawerTitle => 'Sessions';

  @override
  String get addTerminalTooltip => 'Add Terminal';

  @override
  String get noSystemSelectedWarning =>
      'No system selected. Please import or select a system first.';

  @override
  String get noSessionsInDrawerPrompt => 'No sessions. Tap top right to add';

  @override
  String confirmDeleteTerminalSession(int index, String name) {
    return 'Are you sure you want to delete terminal \"($index) $name\"?';
  }

  @override
  String deleteSystemFailed(String error) {
    return 'Failed to delete system: $error';
  }

  @override
  String get addSession => 'New Session';

  @override
  String get editorScope => 'Editor';

  @override
  String get terminalScope => 'Terminal';

  @override
  String get virtualKeyboardConfigTitle => 'Accessory Keyboard Config';

  @override
  String virtualKeyboardPageSubtitle(String scope, int page) {
    return '$scope:(Page $page)';
  }

  @override
  String get keyboardRestoreDefaultTooltip => 'Reset to default presets';

  @override
  String get keyboardPageManagementTooltip => 'Page Management';

  @override
  String get keyboardDrawerTitle => 'Pages';

  @override
  String get keyboardNewPage => 'New Page';

  @override
  String keyboardPageItemTitle(int page) {
    return 'Page $page';
  }

  @override
  String keyboardPageItemSubtitle(int count) {
    return '$count rows';
  }

  @override
  String get keyboardDeletePageTooltip => 'Delete page';

  @override
  String get keyboardPageConfigSectionTitle => 'Page Configuration';

  @override
  String get keyboardRowButtons => 'Buttons per row';

  @override
  String keyboardRowGridDescription(int count) {
    return 'Page width divided into $count columns';
  }

  @override
  String get keyboardDecreaseRowButtonsTooltip => 'Decrease buttons per row';

  @override
  String get keyboardIncreaseRowButtonsTooltip => 'Increase buttons per row';

  @override
  String get keyboardPageKeysSectionTitle => 'Page Keys';

  @override
  String get keyboardAddNewRow => 'Add Row';

  @override
  String get keyboardEmptyPageKeysHint => 'No key rows in current page';

  @override
  String get keyboardEmptyRowKeysHint =>
      'No keys in this row, tap \'+\' above to add';

  @override
  String keyboardRowKeyCount(int count) {
    return '$count keys';
  }

  @override
  String get keyboardAddKeyTooltip => 'Add key';

  @override
  String get keyboardDeleteRowTooltip => 'Delete row';

  @override
  String get keyboardEditKeyTooltip => 'Edit key';

  @override
  String get keyboardDeleteKeyTooltip => 'Delete key';

  @override
  String get keyboardNoLabel => '(No label)';

  @override
  String get keyboardResetDefaultTitle => 'Reset to Default';

  @override
  String get keyboardResetDefaultContent =>
      'Are you sure you want to reset the keyboard to default presets? Your custom modifications will be overwritten.';

  @override
  String get keyboardResetDefaultSuccess =>
      'Reset to default presets successfully';

  @override
  String get keyboardDeletePageTitle => 'Delete Page';

  @override
  String keyboardDeletePageContent(int page) {
    return 'Are you sure you want to delete \"Page $page\"?';
  }

  @override
  String get keyboardDeleteRowTitle => 'Delete Key Row';

  @override
  String keyboardDeleteRowContent(int row) {
    return 'Are you sure you want to delete \"Row $row\" and all its keys?';
  }

  @override
  String get keyboardDeleteKeyTitle => 'Delete Key';

  @override
  String keyboardDeleteKeyContent(String key) {
    return 'Are you sure you want to delete key \"$key\"?';
  }

  @override
  String get keyboardKeepAtLeastOnePageWarning => 'Must keep at least one page';

  @override
  String keyboardRowMaxKeysWarning(int count) {
    return 'A row currently has $count keys, row button count cannot be less than $count';
  }

  @override
  String keyboardRowReachedMaxWarning(int count) {
    return 'Key count in this row has reached maximum (max $count keys)';
  }

  @override
  String get keyboardAddKeyTitle => 'Add Key';

  @override
  String get keyboardEditKeyTitle => 'Edit Key';

  @override
  String get keyboardLabelFormField => 'Label';

  @override
  String get keyboardLabelFormFieldHint =>
      'Text displayed on the key, e.g. Tab, (), A';

  @override
  String get keyboardLabelOrIconRequiredError =>
      'Please enter display text or select an icon';

  @override
  String get keyboardIconFormField => 'Icon (Optional)';

  @override
  String keyboardIconName(String icon) {
    String _temp0 = intl.Intl.selectLogic(icon, {
      'undo': 'Undo',
      'redo': 'Redo',
      'tab': 'Indent',
      'untab': 'Outdent',
      'outdent': 'Decrease Indent',
      'arrow_left': 'Left Arrow',
      'arrow_right': 'Right Arrow',
      'arrow_up': 'Up Arrow',
      'arrow_down': 'Down Arrow',
      'home': 'Line Start',
      'end': 'Line End',
      'first_page': 'Document Start',
      'last_page': 'Document End',
      'page_up': 'Page Up',
      'page_down': 'Page Down',
      'enter': 'Enter',
      'space': 'Space',
      'escape': 'Escape',
      'insert': 'Insert',
      'clear': 'Clear',
      'keyboard': 'Keyboard',
      'backspace': 'Backspace',
      'delete': 'Delete',
      'copy': 'Copy',
      'cut': 'Cut',
      'paste': 'Paste',
      'save': 'Save',
      'search': 'Search',
      'select_all': 'Select All',
      'keyboard_hide': 'Hide Keyboard',
      'other': '$icon',
    });
    return '$_temp0';
  }

  @override
  String get keyboardNoIconOption => 'No icon (Use text)';

  @override
  String get keyboardActionFormField => 'Action';

  @override
  String keyboardActionName(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'input': 'Plain Text',
      'pair': 'Pair Symbols',
      'command': 'Editor Command',
      'modifier': 'Modifier Key',
      'key': 'Special Key',
      'other': '$action',
    });
    return '$_temp0';
  }

  @override
  String get keyboardActionInputTerminal => 'Command Shortcut';

  @override
  String get keyboardKeyFormField => 'Special Key';

  @override
  String get keyboardKeyGroupNavigation => 'Navigation';

  @override
  String get keyboardKeyGroupEditing => 'Editing';

  @override
  String get keyboardKeyGroupFunctionKeys => 'Function Keys';

  @override
  String get keyboardKeyGroupLetters => 'Letters';

  @override
  String get keyboardAutoEnter => 'Send Enter after';

  @override
  String keyboardKeyName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'escape': 'Escape',
      'tab': 'Tab',
      'backtab': 'Backtab',
      'returnKey': 'Return',
      'enter': 'Enter',
      'numpadEnter': 'Keypad Enter',
      'backspace': 'Backspace',
      'delete': 'Delete',
      'insert': 'Insert',
      'space': 'Space',
      'numpadClear': 'Clear',
      'arrowUp': 'Up',
      'arrowDown': 'Down',
      'arrowLeft': 'Left',
      'arrowRight': 'Right',
      'home': 'Home',
      'end': 'End',
      'pageUp': 'Page Up',
      'pageDown': 'Page Down',
      'f1': 'F1',
      'f2': 'F2',
      'f3': 'F3',
      'f4': 'F4',
      'f5': 'F5',
      'f6': 'F6',
      'f7': 'F7',
      'f8': 'F8',
      'f9': 'F9',
      'f10': 'F10',
      'f11': 'F11',
      'f12': 'F12',
      'other': '$key',
    });
    return '$_temp0';
  }

  @override
  String get keyboardKeyInvalidError =>
      'This key produces no output in the terminal; please pick a listed special key';

  @override
  String get keyboardValueFormField => 'Input Text';

  @override
  String get keyboardValueFormFieldHint =>
      'Text inserted upon click, e.g. ;, =, ->';

  @override
  String get keyboardValueRequiredError => 'Input text cannot be empty';

  @override
  String get keyboardPairValueFormField => 'Pair Symbols';

  @override
  String get keyboardPairValueFormFieldHint => 'e.g. (), [], \"\", <>';

  @override
  String get keyboardPairValueRequiredError => 'Please enter the pair symbols';

  @override
  String get keyboardPairValueInvalidError =>
      'Enter at least 2 characters with different halves, e.g. (), []';

  @override
  String get keyboardCommandPresetFormField => 'Editor Command';

  @override
  String keyboardCommandName(String command) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'tab': 'Indent',
      'untab': 'Outdent',
      'undo': 'Undo',
      'redo': 'Redo',
      'cursor_left': 'Cursor Left',
      'cursor_right': 'Cursor Right',
      'cursor_up': 'Cursor Up',
      'cursor_down': 'Cursor Down',
      'line_start': 'Move to Line Start',
      'line_end': 'Move to Line End',
      'page_start': 'Move to Document Start',
      'page_end': 'Move to Document End',
      'copy': 'Copy',
      'cut': 'Cut',
      'paste': 'Paste',
      'delete': 'Delete',
      'select_all': 'Select All',
      'keyboard_hide': 'Hide Keyboard',
      'other': '$command',
    });
    return '$_temp0';
  }

  @override
  String get keyboardModifierPresetFormField => 'Terminal Modifier';

  @override
  String keyboardModifierName(String modifier) {
    String _temp0 = intl.Intl.selectLogic(modifier, {
      'ctrl': 'Ctrl Key',
      'alt': 'Alt Key',
      'shift': 'Shift Key',
      'other': '$modifier',
    });
    return '$_temp0';
  }

  @override
  String get keyboardCursorOffsetFormField => 'Cursor Relative Offset';

  @override
  String get keyboardCursorOffsetRequiredError =>
      'Please enter cursor offset (usually -1)';

  @override
  String get keyboardCursorOffsetIntegerError => 'Offset must be an integer';

  @override
  String get recommended => 'Recommended';

  @override
  String get presetColors => 'Preset Colors';

  @override
  String get hexColor => 'Hex Color';

  @override
  String get currentColor => 'Current';

  @override
  String get newColor => 'Preview';

  @override
  String get runTasks => 'Run Tasks';

  @override
  String get projectDetect => 'Detect Project';

  @override
  String get projectDetecting => 'Detecting project...';

  @override
  String get editRunTasks => 'Edit Run Tasks';

  @override
  String get projectSection => 'Project';

  @override
  String get showHiddenFiles => 'Show Hidden Files';

  @override
  String get showHiddenFilesSubtitle =>
      'Show hidden files and folders starting with dot (.) in file tree';

  @override
  String get searchTasksHint => 'Search tasks...';

  @override
  String get noTasksAvailable => 'No executable tasks available';

  @override
  String get noMatchingTasks => 'No matching tasks found';

  @override
  String get userCustomTasks => 'User Custom Tasks';

  @override
  String get systemDetectedTasks => 'System Detected Tasks';

  @override
  String get editCustomTasksTooltip => 'Edit Custom Tasks';

  @override
  String get runTasksConfig => 'Run Tasks Configuration';

  @override
  String get editTask => 'Edit Task';

  @override
  String get addTask => 'Add Task';

  @override
  String get runTasksConfigSubtitle =>
      'Configuration will be saved to .code_editor/run_tasks.json in project root';

  @override
  String get noCustomTasksInProject => 'No custom tasks in current project';

  @override
  String get createNow => 'Create Now';

  @override
  String get saveAndApply => 'Save & Apply';

  @override
  String get taskNameRequired => 'Task Name *';

  @override
  String get taskNameHint => 'e.g. Build & Run Debug';

  @override
  String get taskNameEmptyError => 'Please enter task name';

  @override
  String get shellCommandRequired => 'Shell Command *';

  @override
  String get shellCommandHint => 'e.g. cmake -B build && cmake --build build';

  @override
  String get shellCommandEmptyError => 'Please enter command';

  @override
  String get taskDescOptional => 'Description (Optional)';

  @override
  String get taskDescHint => 'Briefly describe the task purpose';

  @override
  String get clearBeforeRun => 'Clear Screen (clear)';

  @override
  String get clearBeforeRunSubtitle =>
      'Clear terminal output before executing task';

  @override
  String get runTasksUpdated => 'Run tasks configuration updated';

  @override
  String detectCompletedMessage(int count) {
    return 'Detection completed, found $count tasks';
  }

  @override
  String get pleaseOpenProjectFirst => 'Please open a project first';

  @override
  String deleteTaskConfirmMessage(String name) {
    return 'Are you sure you want to delete task \"$name\"?';
  }

  @override
  String deleteSelectedTasksConfirmMessage(int count) {
    return 'Are you sure you want to delete the selected $count tasks?';
  }

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get selectTasksToDelete => 'Select Tasks to Delete';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get unsavedTaskChangesTitle => 'Unsaved Task Changes';

  @override
  String get unsavedTaskChangesMessage =>
      'The task has been modified. Do you want to discard unsaved changes and leave?';
}
