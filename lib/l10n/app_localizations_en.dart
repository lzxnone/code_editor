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
  String get terminalFontSize => 'Terminal Font Size';

  @override
  String get terminalFontSizeDialogTitle => 'Terminal Font Size';

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
  String get showLineNumbers => 'Show Line Numbers';

  @override
  String get showLineNumbersSubtitle =>
      'Display line numbers and code folding markers on the left';

  @override
  String get pinLineNumbers => 'Pin Line Numbers';

  @override
  String get pinLineNumbersSubtitle =>
      'Keep line numbers pinned to the left during horizontal scroll';

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
  String get importFromApp => 'Import from App';

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
  String get distroManagementTitle => 'System Management';

  @override
  String get installedStatus => 'Ready';

  @override
  String get notInstalledStatus => 'Component Not Installed';

  @override
  String get downloadingStatus => 'Downloading';

  @override
  String get downloadAction => 'Download';

  @override
  String get installAction => 'Install';

  @override
  String get builtinTag => 'Built-in';

  @override
  String get cancelDownloadAction => 'Cancel Download';

  @override
  String get cancelDownloadConfirmTitle => 'Cancel Download';

  @override
  String get cancelDownloadConfirmMessage =>
      'Are you sure you want to cancel the downloading system package? The downloaded parts will be discarded.';

  @override
  String get deletingSystemProgress =>
      'Deleting system and cleaning storage, please wait...';

  @override
  String get cannotDeleteBuiltinSystem =>
      'Built-in system is protected and cannot be deleted';

  @override
  String get recommendedTag => 'Recommended';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String deleteSystemSuccess(String name) {
    return 'System \"$name\" and associated sessions deleted';
  }

  @override
  String get deletePackageConfirmTitle => 'Confirm Delete Package';

  @override
  String deletePackageConfirmMessage(String name) {
    return 'Are you sure you want to delete the package for \"$name\"? You can download it again at any time.';
  }

  @override
  String get deletingPackageProgress => 'Deleting package, please wait...';

  @override
  String deletePackageSuccess(String name) {
    return 'Deleted \"$name\" package';
  }

  @override
  String get deletePackageTooltip => 'Delete downloaded system package';

  @override
  String importSystemInstanceTitle(String name) {
    return 'Create $name System Instance';
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
  String get resyncModuleTasks => 'Resync Real Tasks';

  @override
  String get syncingTasks => 'Introspecting tasks in background...';

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
  String get clearBeforeRun => 'Clear Screen';

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

  @override
  String get downloadSection => 'Download';

  @override
  String get downloadSource => 'Download Source';

  @override
  String get selectDownloadSource => 'Select Download Source';

  @override
  String mirrorName(String mirror) {
    String _temp0 = intl.Intl.selectLogic(mirror, {
      'tsinghua': 'Tsinghua TUNA Mirror (Recommended)',
      'bfsu': 'BFSU Open Source Mirror',
      'iscas': 'ISCAS Open Source Mirror',
      'official': 'LinuxContainers Official Mirror',
      'other': '$mirror',
    });
    return '$_temp0';
  }

  @override
  String get unnamedTask => 'Unnamed Task';

  @override
  String get shellCommandHelperText =>
      'Supports single-line commands (e.g. make) or multi-line Shell scripts (packaged and executed automatically)';

  @override
  String get detectedTaskCmakeBuildRunDesc =>
      'Configure, build, and try launching the target executable';

  @override
  String get detectedTaskCmakeBuildDesc =>
      'Only execute cmake generation and build';

  @override
  String get detectedTaskCmakeCleanDesc => 'Clean build cache directory';

  @override
  String get detectedTaskGradleRunDesc => 'Execute application main entrypoint';

  @override
  String get detectedTaskGradleAssembleDesc => 'Build debug output package';

  @override
  String get detectedTaskGradleBuildDesc => 'Execute full build and tests';

  @override
  String get detectedTaskMakeDefaultDesc =>
      'Execute default Makefile build target';

  @override
  String get detectedTaskNpmStartDesc =>
      'Start Node service or frontend development environment';

  @override
  String get detectedTaskNpmTestDesc => 'Execute npm test suite';

  @override
  String get detectedTaskCargoRunDesc => 'Compile and run Rust project';

  @override
  String get detectedTaskCargoBuildDesc => 'Compile Rust project only';

  @override
  String get detectedTaskDartRunDesc => 'Launch Dart application';

  @override
  String get detectedTaskSinglePythonDesc => 'Run current Python script';

  @override
  String get detectedTaskSingleCDesc =>
      'Compile and execute current C source file';

  @override
  String get detectedTaskSingleCppDesc =>
      'Compile and execute current C++ source file';

  @override
  String get detectedTaskSingleShDesc => 'Run current Shell script';

  @override
  String get detectedTaskSingleDartDesc => 'Run current Dart file';

  @override
  String get detectedTaskSingleGoDesc => 'Run current Go source file';

  @override
  String get detectedTaskSingleRustDesc =>
      'Compile and execute current Rust source file';

  @override
  String get detectedTaskSingleJsDesc => 'Run current JavaScript script';

  @override
  String get detectedTaskSingleJavaDesc =>
      'Run current Java source file directly';

  @override
  String get detectedTaskSingleTsDesc => 'Run current TypeScript script';

  @override
  String get detectedTaskSingleLuaDesc => 'Run current Lua script';

  @override
  String get detectedTaskSinglePerlDesc => 'Run current Perl script';

  @override
  String get detectedTaskSinglePhpDesc => 'Run current PHP script';

  @override
  String get detectedTaskPythonPipInstallDesc => 'Install requirements via pip';

  @override
  String get detectedTaskPythonRunMainDesc =>
      'Execute Python project main entrypoint';

  @override
  String get detectedTaskPythonPytestDesc => 'Run pytest test suite';

  @override
  String get detectedTaskMavenPackageDesc =>
      'Package Maven project (mvn package)';

  @override
  String get detectedTaskMavenCompileDesc =>
      'Compile Maven project sources (mvn compile)';

  @override
  String get detectedTaskMavenTestDesc => 'Run Maven unit tests (mvn test)';

  @override
  String get detectedTaskMavenCleanDesc =>
      'Clean Maven target output directory (mvn clean)';

  @override
  String get missingDistroTitle => 'System Environment Not Ready';

  @override
  String get noDistroAvailableContent =>
      'No available Linux execution environment detected.\n\nProject tasks need to run inside a Linux container. Please install or download a Linux system first (e.g. Ubuntu or Alpine).';

  @override
  String distroNotInstalledContent(String distro) {
    return 'System \"$distro\" is not installed or has been removed.\n\nPlease install it in System Management or select another available system.';
  }

  @override
  String get openFromApp => 'Open from App';

  @override
  String get openFromExternal => 'Open from External';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get newProject => 'New Project';

  @override
  String get newProjectTitle => 'New Project';

  @override
  String get projectNameHint => 'Enter project name';

  @override
  String get renameProject => 'Rename Project';

  @override
  String get deleteProject => 'Delete Project';

  @override
  String deleteProjectConfirmMessage(String name) {
    return 'Are you sure you want to delete project \"$name\"? This action cannot be undone.';
  }

  @override
  String get projectAlreadyExists => 'A project with this name already exists';

  @override
  String get noProjects => 'No projects yet, click top right to create one';

  @override
  String get projectCreated => 'Project created successfully';

  @override
  String get projectRenamed => 'Project renamed successfully';

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String get importFromExternal => 'Import from External';

  @override
  String get confirmProjectNameTitle => 'Confirm Project Name';

  @override
  String get importingProject => 'Importing project...';

  @override
  String get projectImported => 'Project imported successfully';

  @override
  String importProjectFailed(String error) {
    return 'Failed to import project: $error';
  }

  @override
  String get unsupportedProjectArchiveFormat =>
      'Unsupported file format. Only archive files (.zip, .tar.gz, .tar.xz, .tar, etc.) are supported';

  @override
  String get unsupportedDistroArchiveFormat =>
      'Unsupported file format. Only system archives (.tar.gz, .tar.xz, .tar) are supported';

  @override
  String get exportProject => 'Export Project';

  @override
  String get exportProjectTooltip => 'Export as ZIP archive';

  @override
  String get exportingProject => 'Compressing and exporting project...';

  @override
  String get projectExported => 'Project exported successfully';

  @override
  String exportProjectFailed(String error) {
    return 'Failed to export project: $error';
  }

  @override
  String get selectExportDirectory => 'Select Export Destination Folder';

  @override
  String targetFileAlreadyExists(String name) {
    return 'Target file \"$name\" already exists. Overwrite?';
  }

  @override
  String get overwrite => 'Overwrite';

  @override
  String get batteryOptimizationTitle =>
      'Background Running & Battery Optimization';

  @override
  String get batteryOptimizationMessage =>
      'To prevent terminal sessions from being killed by the system in the background, it is recommended to disable battery optimization or set it to \'Unrestricted\'.\n\nWould you like to go to settings to configure it?';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String probeBannerPreparing(String module) {
    return 'Preparing $module environment…';
  }

  @override
  String probeBannerDetecting(String module) {
    return 'Detecting $module tasks…';
  }

  @override
  String get probeBannerFinalizing => 'Finalizing detection result…';

  @override
  String probePhaseQueued(String module) {
    return '$module queued…';
  }

  @override
  String probePhaseCheckingDependency(String module) {
    return 'Checking $module dependencies…';
  }

  @override
  String probePhaseInstallingDependency(String module) {
    return 'Installing $module dependencies…';
  }

  @override
  String probeDoneWithCount(String module, int count) {
    return '$module finished · $count tasks found';
  }

  @override
  String probeFailureDependencyInstallFailed(String tool) {
    return 'Failed to auto-install dependency $tool';
  }

  @override
  String get taskTypeSingleFile => 'Current File Task';

  @override
  String get taskTypeOther => 'Other Tasks';

  @override
  String get probeAlreadyRunning =>
      'Detection already in progress, please wait…';

  @override
  String get probeBusyEnterTerminalTitle => 'Task detection in progress';

  @override
  String get probeBusyEnterTerminalMessage =>
      'Project task detection is running in the background (it uses the current container for build-tool introspection and dependency installation).\n\nEntering the terminal and running installs or builds may block or conflict with it.\n\nDo you still want to open the terminal?';

  @override
  String get probeEnterTerminalAnyway => 'Open Terminal Anyway';

  @override
  String get probeCancelConfirmTitle => 'Cancel this detection?';

  @override
  String get probeCancelConfirmMessage =>
      'The running detection will be aborted immediately: results of finished modules are kept, unfinished modules will be skipped.';

  @override
  String get probeKeepDetecting => 'Keep detecting';

  @override
  String get cancelProbe => 'Cancel detection';

  @override
  String get probeBudgetExceededTitle =>
      'Detection aborted (time budget exceeded)';

  @override
  String probeBudgetExceededMessage(int completed, int total) {
    return '$completed/$total modules finished; the rest were skipped. You can re-detect later.';
  }

  @override
  String get probeBannerClose => 'Close';

  @override
  String probeDone(String module) {
    return '$module task detection finished';
  }

  @override
  String probeFailedTitle(String module) {
    return '$module task detection failed';
  }

  @override
  String probeFailureToolchainMissing(String tool) {
    return '$tool was not found in the current system. Install it in System Management first.';
  }

  @override
  String probeFailureExecutionFailed(String detail) {
    return 'Build tool execution failed: $detail';
  }

  @override
  String get probeFailureUnparsable =>
      'Unable to parse build tool output (possible version mismatch)';

  @override
  String get probeFailureTimeout => 'Detection timed out and was aborted';

  @override
  String noticeQueueMore(int count) {
    return '$count more in progress';
  }

  @override
  String importFilesSuccess(int count) {
    return 'Successfully imported $count files';
  }

  @override
  String importFilesFailed(String error) {
    return 'Failed to import files: $error';
  }

  @override
  String get codeCompletionManagement => 'Code Completion Management';

  @override
  String get codeCompletionSubtitle =>
      'Manage language servers and code intelligence toolchains';

  @override
  String get completionSourceSection => 'Completion Data Sources & Switches';

  @override
  String get localCompletionTitle => 'Local Base Completion';

  @override
  String get localCompletionSubtitle =>
      'Built-in language keywords and document lexical heuristic extraction';

  @override
  String get lspCompletionTitle => 'Backend Language Server';

  @override
  String get lspCompletionSubtitle =>
      'Request real semantic types and function parameters from background compilers';

  @override
  String get internalEngineTitle =>
      'Runtime & Code Intelligence Engine (Ubuntu)';

  @override
  String get internalEngineStatusReady => 'Engine Ready';

  @override
  String get internalEngineStatusNotReady => 'Engine Not Started';

  @override
  String get internalEngineExtracting =>
      'Preparing built-in Ubuntu environment & intelligence engine...';

  @override
  String get installComponent => 'Install Component';

  @override
  String installingComponent(String pkg) {
    return 'Installing $pkg...';
  }

  @override
  String installComponentSuccess(String name) {
    return '$name component installed successfully';
  }

  @override
  String installComponentFailed(String error) {
    return 'Failed to install component: $error';
  }

  @override
  String uninstallingComponent(String pkg) {
    return 'Uninstalling $pkg and cleaning configuration...';
  }

  @override
  String get editLanguageConfig => 'Edit Language Configuration';

  @override
  String get addLanguageConfig => 'Add Language Configuration';

  @override
  String get deleteLanguageConfirmTitle => 'Delete Language Configuration';

  @override
  String deleteLanguageConfirmMessage(String name) {
    return 'Are you sure you want to delete the code completion configuration for $name?';
  }

  @override
  String deleteLanguageWithPackageConfirmMessage(String name) {
    return 'Are you sure you want to delete the code completion configuration for $name? Installed packages will be uninstalled.';
  }

  @override
  String get resetDefaultLanguages => 'Reset Default Configurations';

  @override
  String get resetDefaultLanguagesConfirm =>
      'Are you sure you want to reset all language configurations to official default presets?';

  @override
  String get languageDisplayName => 'Language Name';

  @override
  String get languageDisplayNameHint => 'e.g. C / C++';

  @override
  String get languageIdField => 'Language ID';

  @override
  String get languageIdFieldHint =>
      'For LSP protocol identification, e.g. cpp, rust';

  @override
  String get fileExtensionsField => 'File Extensions';

  @override
  String get fileExtensionsFieldHint => 'Comma-separated, e.g. .c, .cpp, .h';

  @override
  String get serverCommandField => 'Server Command';

  @override
  String get serverCommandFieldHint => 'e.g. clangd';

  @override
  String get serverArgsField => 'Server Arguments';

  @override
  String get serverArgsFieldHint => 'Space or comma-separated arguments';

  @override
  String get apkPackageField => 'Ubuntu Package Name (APT)';

  @override
  String get apkPackageFieldHint =>
      'For one-click install, e.g. clangd or python3-pylsp';

  @override
  String lspPackageMissingTitle(String language) {
    return '$language code intelligence component not installed';
  }

  @override
  String get lspPackageMissingMessage =>
      'Install the component to enable code completion and error diagnostics';

  @override
  String get installNow => 'Install Now';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get languageConfigSaved => 'Language configuration saved';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get edit => 'Edit';

  @override
  String componentQueued(String name) {
    return '$name queued…';
  }

  @override
  String uninstallComponentSuccess(String name) {
    return '$name component uninstalled successfully';
  }

  @override
  String uninstallComponentFailed(String error) {
    return 'Failed to uninstall component: $error';
  }

  @override
  String get installingStatus => 'Installing…';

  @override
  String get uninstallingStatus => 'Uninstalling…';

  @override
  String get emptyLspLanguagesTitle =>
      'No code intelligence components installed';

  @override
  String get emptyLspLanguagesSubtitle =>
      'Open any source file to trigger installation on demand, or click \"+\" to add manually';

  @override
  String lspQuickFixTitle(int line) {
    return 'Code Issues & Fixes (Line $line)';
  }

  @override
  String get lspNoFixAvailable => 'No automated fixes available';

  @override
  String diagnosticLinePrefix(int line, String message) {
    return 'Line $line: $message';
  }

  @override
  String get quickFixButton => 'Fix';

  @override
  String get containerSection => 'Container';

  @override
  String get destroyAndRebuildContainer => 'Destroy and Rebuild Container';

  @override
  String get destroyAndRebuildContainerSubtitle =>
      'Clear installed environments in container and re-extract clean container';

  @override
  String get destroyContainerConfirmTitle => 'Destroy and Rebuild Container';

  @override
  String get destroyContainerConfirmMessage =>
      'This will permanently delete all installed packages and configurations in the Ubuntu container (project files will not be affected) and re-extract a clean container system. Continue?';

  @override
  String get destroyContainerButton => 'Destroy & Rebuild';

  @override
  String get containerRebuiltSuccess => 'Container rebuilt successfully';

  @override
  String containerRebuildFailed(String error) {
    return 'Failed to rebuild container: $error';
  }

  @override
  String get containerRuntimeMode => 'Container Runtime Mode';

  @override
  String get containerRuntimeModeAuto => 'Auto';

  @override
  String get containerRuntimeModeProot => 'PRoot';

  @override
  String get containerRuntimeModeChroot => 'Chroot';

  @override
  String get selectContainerRuntimeMode => 'Select Container Runtime Mode';

  @override
  String containerRuntimeToast(String mode) {
    return 'Current container runtime: $mode';
  }

  @override
  String get chrootDisabledNoRoot => 'Unavailable without Root permission';

  @override
  String get chrootFailedFallbackToProot =>
      'Chroot mount or permission failed, automatically fell back to PRoot';

  @override
  String get drawerTabExplorer => 'Explorer';

  @override
  String get drawerTabSearch => 'Search';

  @override
  String get drawerTabGit => 'Source Control';

  @override
  String get searchHint => 'Search';

  @override
  String get replaceHint => 'Replace';

  @override
  String get matchCase => 'Match Case';

  @override
  String get matchWholeWord => 'Match Whole Word';

  @override
  String get useRegularExpression => 'Use Regular Expression';

  @override
  String get invalidRegularExpression => 'Invalid regular expression';

  @override
  String get projectDirectoryNotFound => 'Project directory does not exist';

  @override
  String get searchMoreOptions => 'More Options';

  @override
  String get searchModeText => 'Text Search';

  @override
  String get searchModeFileName => 'File Name Search';

  @override
  String get replaceAllInFile => 'Replace All in This File';

  @override
  String get replaceAllInProject => 'Replace All';

  @override
  String get replaceSingleMatch => 'Replace';

  @override
  String searchResultStats(int fileCount, int matchCount) {
    return '$matchCount results in $fileCount files';
  }

  @override
  String get noSearchResults => 'No results found';

  @override
  String searchError(String error) {
    return 'Search failed: $error';
  }

  @override
  String replaceSuccess(int count) {
    return 'Replaced $count occurrences';
  }

  @override
  String get expandAll => 'Expand All';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String searchLoadMoreFiles(int count) {
    return 'Load more files ($count remaining)';
  }

  @override
  String searchLoadMoreMatches(int count) {
    return 'Load more matches ($count remaining)';
  }

  @override
  String get confirmReplaceAllTitle => 'Confirm Replace All';

  @override
  String confirmReplaceAllMessage(
    int matchCount,
    int fileCount,
    String replaceText,
  ) {
    return 'Are you sure you want to replace all $matchCount occurrences in $fileCount files with \"$replaceText\"? This will modify files on disk.';
  }

  @override
  String get confirmReplaceFileTitle => 'Replace in File';

  @override
  String confirmReplaceFileMessage(
    String fileName,
    int matchCount,
    String replaceText,
  ) {
    return 'Are you sure you want to replace all $matchCount occurrences in \"$fileName\" with \"$replaceText\"?';
  }

  @override
  String get gitNotInstalled => 'Git Not Found';

  @override
  String get gitNotInstalledDesc =>
      'Git command-line tool was not found on your system. Please install git in your terminal or Linux container (e.g. apt update && apt install -y git).';

  @override
  String get gitNeedInstall => 'Git Installation Required';

  @override
  String get gitInstallAction => 'Install Git';

  @override
  String get gitInstallingProgress => 'Installing Git...';

  @override
  String get gitInstallSuccess => 'Git installed successfully';

  @override
  String gitInstallFailed(String error) {
    return 'Failed to install Git: $error';
  }

  @override
  String get gitNoRepoFound => 'No Git Repository';

  @override
  String get gitNoRepoDesc =>
      'Initialize a Git repository to start version control, branch management, and tracking code changes.';

  @override
  String get gitInitRepo => 'Initialize Repository';

  @override
  String get gitInitializing => 'Initializing Git repository...';

  @override
  String get gitInitSuccess => 'Git repository initialized successfully';

  @override
  String gitInitFailed(String error) {
    return 'Failed to initialize Git repository: $error';
  }

  @override
  String get gitRepository => 'Repository';

  @override
  String gitCurrentBranch(String branch) {
    return 'Branch: $branch';
  }

  @override
  String get gitSwitchRepo => 'Switch Repository';

  @override
  String get gitRefresh => 'Refresh Git';

  @override
  String get gitChanges => 'Changes';

  @override
  String get gitStagedChanges => 'Staged Changes';

  @override
  String get gitNoChanges => 'No changes detected';

  @override
  String get gitStatusUntracked => 'Untracked';

  @override
  String get gitStatusModified => 'Modified';

  @override
  String get gitStatusAdded => 'Added';

  @override
  String get gitStatusDeleted => 'Deleted';

  @override
  String get gitStatusRenamed => 'Renamed';

  @override
  String get gitStatusConflict => 'Conflict';

  @override
  String gitMultipleReposDetected(int count) {
    return 'Multiple Repositories ($count)';
  }

  @override
  String get gitStageChange => 'Stage Changes';

  @override
  String get gitUnstageChange => 'Unstage Changes';

  @override
  String get gitStageAll => 'Stage All Changes';

  @override
  String get gitUnstageAll => 'Unstage All Changes';

  @override
  String get gitStageSuccess => 'Staged';

  @override
  String get gitUnstageSuccess => 'Unstaged';

  @override
  String get gitCommit => 'Commit';

  @override
  String get gitCommitMessageHint => 'Message';

  @override
  String get gitCommitSuccess => 'Commit successful';

  @override
  String gitCommitFailed(String error) {
    return 'Commit failed: $error';
  }

  @override
  String get gitDiscardChange => 'Discard Changes';

  @override
  String get gitDiscardConfirm => 'Discard Changes?';

  @override
  String gitDiscardConfirmDesc(String fileName) {
    return 'Are you sure you want to discard all unstaged changes in \"$fileName\"? This cannot be undone.';
  }

  @override
  String get gitNoCommitMessage => 'Please enter a commit message';

  @override
  String get gitNoStagedChangesToCommit =>
      'There are no staged changes. Would you like to stage all changes and commit?';

  @override
  String get gitStageAllAndCommit => 'Stage All and Commit';

  @override
  String get gitGraphTitle => 'Graph';

  @override
  String get gitNoCommits => 'No commit history';

  @override
  String get gitCommitDetails => 'Commit Details';

  @override
  String get gitCommitAuthor => 'Author';

  @override
  String get gitCommitDate => 'Date';

  @override
  String get gitCommitHash => 'Commit Hash';

  @override
  String get gitCopyHash => 'Copy Hash';

  @override
  String get gitHashCopied => 'Commit hash copied to clipboard';

  @override
  String get gitCommitParent => 'Parent';

  @override
  String get gitDiscardAll => 'Discard All Changes';

  @override
  String get gitDiscardAllChangesTitle => 'Discard All Changes?';

  @override
  String get gitDiscardAllChangesConfirm =>
      'Are you sure you want to discard all unstaged changes? Modified files will be restored and untracked files will be cleaned. This cannot be undone.';

  @override
  String get gitDiscardAllStagedTitle => 'Discard All Staged Changes?';

  @override
  String get gitDiscardAllStagedConfirm =>
      'Are you sure you want to discard all staged changes? This cannot be undone.';

  @override
  String get gitBranches => 'Branches';

  @override
  String get gitCreateBranch => 'Create Branch';

  @override
  String get gitBranchNameHint => 'Enter branch name';

  @override
  String gitSwitchBranchSuccess(String branch) {
    return 'Switched to branch $branch';
  }

  @override
  String gitCreateBranchSuccess(String branch) {
    return 'Created and switched to branch $branch';
  }

  @override
  String get gitDeleteBranch => 'Delete Branch';

  @override
  String gitDeleteBranchConfirm(String branch) {
    return 'Are you sure you want to delete branch $branch?';
  }

  @override
  String gitDeleteBranchSuccess(String branch) {
    return 'Deleted branch $branch';
  }

  @override
  String get gitCannotDeleteCurrentBranch => 'Cannot delete the current branch';

  @override
  String get gitUndoLastCommit => 'Undo Last Commit';

  @override
  String get gitUndoLastCommitConfirm =>
      'Are you sure you want to undo the last commit? Changes will be kept in the staging area.';

  @override
  String get gitUndoLastCommitSuccess => 'Undid last commit';

  @override
  String get gitStash => 'Stash';

  @override
  String get gitStashChanges => 'Stash Changes';

  @override
  String get gitStashChangesSuccess => 'Stashed current changes';

  @override
  String get gitStashPop => 'Pop Latest Stash';

  @override
  String get gitStashPopSuccess => 'Restored latest stash';

  @override
  String get gitNoStashFound => 'No stashes found';

  @override
  String get gitAddToGitignore => 'Add to .gitignore';

  @override
  String get gitAddedToGitignore => 'Added to .gitignore';

  @override
  String get gitMoreActions => 'More Actions';

  @override
  String get gitOpenFile => 'Open File';

  @override
  String get gitTags => 'Tags';

  @override
  String get gitCreateTag => 'Create Tag';

  @override
  String get gitTagNameHint => 'Enter tag name (e.g. v1.0.0)';

  @override
  String get gitTagMessageHint => 'Tag message (optional)';

  @override
  String get gitDeleteTag => 'Delete Tag';

  @override
  String gitDeleteTagConfirm(String tag) {
    return 'Are you sure you want to delete tag $tag?';
  }

  @override
  String gitCreateTagSuccess(String tag) {
    return 'Created tag $tag';
  }

  @override
  String gitDeleteTagSuccess(String tag) {
    return 'Deleted tag $tag';
  }

  @override
  String gitSwitchTagSuccess(String tag) {
    return 'Checked out to tag $tag';
  }

  @override
  String get gitNoTags => 'No tags';

  @override
  String get gitSelectBranchToDelete => 'Select branch to delete';

  @override
  String get gitSelectTagToDelete => 'Select tag to delete';

  @override
  String get gitSearchBranches => 'Search branches...';

  @override
  String get gitSearchTags => 'Search tags...';

  @override
  String get gitNoBranches => 'No branches';

  @override
  String get gitRemoteBranches => 'Remote Branches';

  @override
  String get gitLocalBranches => 'Local Branches';

  @override
  String get gitNoRemoteBranches => 'No remote branches yet — fetch first';

  @override
  String get gitCheckoutRemoteBranch => 'Check out as local branch';

  @override
  String get gitRemoteBranchCheckedOut => 'Already checked out locally';

  @override
  String gitCheckoutRemoteBranchSuccess(String remote, String branch) {
    return 'Created and switched to local branch $branch from $remote';
  }

  @override
  String get gitSearchRemoteBranches => 'Search remote branches...';

  @override
  String get gitRepairCheck => 'Repository Check';

  @override
  String get gitRepairCheckRunning => 'Checking...';

  @override
  String get gitRepairCheckHealthy =>
      'Repository is intact, no missing objects';

  @override
  String get gitRepairCheckHealthyHint =>
      'Object database verified. Committing and syncing should work normally.';

  @override
  String gitRepairCheckObjectLoss(int count) {
    return 'Missing objects detected ($count problems)';
  }

  @override
  String get gitRepairCheckObjectLossHint =>
      'This kind of damage causes \"Error building trees\" on commit. It usually happens when the container is rebuilt and .git/objects is lost. Back up the project directory first, then follow the advice below.';

  @override
  String gitRepairCheckDangling(int count) {
    return '$count dangling objects (normal, no action needed)';
  }

  @override
  String get gitRepairCheckFailed => 'The check could not complete';

  @override
  String get gitRepairCheckFailedHint =>
      'The repository may be large or the command timed out. Try again later.';

  @override
  String get gitRepairCheckRerun => 'Run Again';

  @override
  String get gitRepairAdviceTitle => 'How to handle this';

  @override
  String get gitRepairAdviceRemoveStale =>
      'Uncommitted broken entries: run git reset to realign the index with the last commit, then stage the files again.';

  @override
  String get gitRepairAdviceRestore =>
      'Damaged committed history: re-clone from the remote, or restore from another copy.';

  @override
  String get gitClone => 'Clone Repository';

  @override
  String get gitCloneUrl => 'Repository URL';

  @override
  String get gitCloneUrlHint => 'https://github.com/user/repo.git';

  @override
  String get gitCloneDirName => 'Local directory name';

  @override
  String get gitCloneDirNameHint => 'Leave empty to derive from the URL';

  @override
  String get gitCloneBranch => 'Branch (optional)';

  @override
  String get gitCloneBranchHint =>
      'Leave empty to use the remote default branch';

  @override
  String get gitCloneDepth => 'Shallow clone depth (optional)';

  @override
  String get gitCloneDepthHint => 'e.g. 1 clones only the latest commit';

  @override
  String get gitCloneUrlRequired => 'Please enter a repository URL';

  @override
  String get gitCloneDirRequired => 'Please enter a local directory name';

  @override
  String get gitCloneDirExists =>
      'Directory already exists, choose another name';

  @override
  String get gitCloneRunning => 'Cloning...';

  @override
  String gitCloneSuccess(String name) {
    return 'Clone complete: $name';
  }

  @override
  String get gitCloneFailed => 'Clone failed';

  @override
  String get gitCloneCancel => 'Cancel clone';

  @override
  String gitPushTargetTooltip(String name, String reason) {
    return 'Push target: $name\n$reason';
  }

  @override
  String get gitPushReasonPushRemote =>
      'Set by branch config branch.*.pushRemote';

  @override
  String get gitPushReasonPushDefault =>
      'Set by repo config remote.pushDefault';

  @override
  String get gitPushReasonUpstream => 'The upstream remote of this branch';

  @override
  String get gitPushReasonBranchRemote =>
      'Set by branch config branch.*.remote';

  @override
  String get gitPushReasonFallback => 'Default remote (origin preferred)';

  @override
  String get gitPushReasonOverridden =>
      'You switched it manually in this session';

  @override
  String gitFetchTargetTooltip(String name) {
    return 'Fetch target: $name';
  }

  @override
  String get gitTogglePushTarget => 'Choose push target';

  @override
  String get gitSyncCloudTooltip => 'Sync: fetch / pull / push';

  @override
  String gitPushTargetChanged(String name) {
    return 'Push target switched to $name';
  }

  @override
  String get gitPushTargetDiffers => 'Push target differs from upstream';

  @override
  String gitPushTargetDiffersNotice(String upstream, String push) {
    return 'Pull from $upstream, push to $push';
  }

  @override
  String get gitRemoteRoleUpstream => 'Upstream (fetch)';

  @override
  String get gitErrAuthFailed =>
      'Authentication failed: invalid or expired token, or username mismatch';

  @override
  String get gitErrAuthFailedHint =>
      'Check the token in Git Accounts, and make sure the username matches your login name on that platform.';

  @override
  String get gitErrWritePermissionDenied =>
      'This account has no write access to this repository';

  @override
  String get gitErrWritePermissionDeniedHint =>
      'If this is someone else\'s repository (upstream), fork it to your own account first, then point the remote at your fork (e.g. https://github.com/your-name/repo.git).';

  @override
  String get gitErrRepositoryNotFound =>
      'Repository not found, or this account has no access to it';

  @override
  String get gitErrRepositoryNotFoundHint =>
      'GitHub returns 404 for both \"no permission\" and \"does not exist\". Verify the remote URL and that the token can access this repository.';

  @override
  String get gitErrProxyAuthRequired =>
      'The network proxy requires authentication';

  @override
  String get gitErrProxyAuthRequiredHint =>
      'This network goes through an authenticated proxy (HTTP 407). Check the proxy configuration and credentials inside the container.';

  @override
  String get gitErrRequestRejected => 'The server rejected this request';

  @override
  String get gitErrRequestRejectedHint =>
      'Usually means the pushed content or branch reference is invalid (HTTP 422), e.g. a branch name that violates platform rules or a blocked commit.';

  @override
  String get gitErrRateLimited =>
      'Too many requests, rate limited by the platform';

  @override
  String get gitErrRateLimitedHint =>
      'Wait a few minutes and retry (HTTP 429). Retrying repeatedly will extend the limit.';

  @override
  String get gitErrHttpError => 'The server returned an error status code';

  @override
  String get gitErrHttpErrorHint =>
      'Check the status code below: 401 invalid token, 403 no permission, 404 not found or no access, 407 proxy auth required, 429 rate limited.';

  @override
  String get gitErrPasswordAuthDisabled =>
      'This platform has disabled password authentication';

  @override
  String get gitErrPasswordAuthDisabledHint =>
      'Add the account again using a personal access token (PAT) in Git Accounts.';

  @override
  String get gitErrNetworkUnreachable =>
      'Cannot reach the remote server over the network';

  @override
  String get gitErrNetworkUnreachableHint =>
      'Check your network connection and the container DNS configuration (/etc/resolv.conf).';

  @override
  String get gitErrSshPublicKeyDenied =>
      'SSH public key authentication was rejected';

  @override
  String get gitErrSshPublicKeyDeniedHint =>
      'Make sure the container\'s public key is added to the platform\'s SSH keys, or switch to HTTPS with an access token.';

  @override
  String get gitErrSshKeyUnusable =>
      'The SSH private key is unusable (bad permissions or format)';

  @override
  String get gitErrSshKeyUnusableHint =>
      'The private key must have mode 600. You can regenerate the key pair in Git Accounts.';

  @override
  String get gitErrHostKeyUnverified =>
      'The server host fingerprint is not confirmed yet, connection aborted';

  @override
  String get gitErrHostKeyUnverifiedHint =>
      'The first connection requires confirming the host fingerprint. If the server key changed, clear ~/.ssh/known_hosts in the container and retry.';

  @override
  String get gitErrNonFastForward =>
      'Push rejected: the remote has commits you do not have locally';

  @override
  String get gitErrNonFastForwardHint =>
      'Pull first (rebase mode) to merge the remote changes, then push again.';

  @override
  String get gitErrStaleForcePush =>
      'Force push rejected: someone else updated the remote branch';

  @override
  String get gitErrStaleForcePushHint =>
      'Fetch the latest remote state first, review the differences, then force push again.';

  @override
  String get gitErrConflictDetected =>
      'Merge/rebase conflicts must be resolved manually';

  @override
  String get gitErrConflictDetectedHint =>
      'Resolve the conflicting files one by one, or abort this operation (git rebase --abort).';

  @override
  String get gitErrLocalChanges =>
      'Local uncommitted changes would be overwritten, operation aborted';

  @override
  String get gitErrLocalChangesHint =>
      'Commit your changes first, or stash them, then retry.';

  @override
  String get gitErrNoUpstream =>
      'This branch is not tracking a remote branch yet';

  @override
  String get gitErrNoUpstreamHint =>
      'Use Publish Branch to push it to the remote and set up tracking.';

  @override
  String get gitErrRefLockFailed =>
      'A Git reference file is locked (stale lock)';

  @override
  String get gitErrRefLockFailedHint =>
      'Another Git process may be running. Retry shortly, or remove the .lock files under .git.';

  @override
  String get gitErrOutOfSpace => 'Not enough storage space on the device';

  @override
  String get gitErrOutOfSpaceHint =>
      'Free up space in the container or on the device, then retry.';

  @override
  String get gitErrTimeout => 'Operation timed out';

  @override
  String get gitErrTimeoutHint =>
      'Large repositories or slow networks can time out. Watch the progress in the terminal instead, or retry on a better connection.';

  @override
  String get gitErrIncomplete =>
      'The operation did not finish, and no specific error was returned';

  @override
  String get gitErrIncompleteHint =>
      'It was most likely interrupted by a timeout or a dropped connection. For large repositories, run fetch in the terminal to watch progress, or retry on a better connection.';

  @override
  String get gitErrUnknown => 'Git operation failed';

  @override
  String get gitErrUnknownHint => 'Expand the raw output below for details.';

  @override
  String get gitRawOutput => 'Raw output';

  @override
  String gitElapsed(String time) {
    return 'Elapsed $time';
  }

  @override
  String gitElapsedMinutesSeconds(int minutes, String seconds) {
    return '$minutes:$seconds';
  }

  @override
  String get gitFetch => 'Fetch';

  @override
  String get gitFetchTooltip =>
      'Fetch the latest commits from the remote without merging';

  @override
  String get gitPull => 'Pull';

  @override
  String get gitPullTooltip =>
      'Pull remote commits and rebase the current branch onto them';

  @override
  String get gitPush => 'Push';

  @override
  String get gitPushTooltip => 'Push local commits to the remote';

  @override
  String get gitPublishBranch => 'Publish Branch';

  @override
  String get gitPublishBranchTooltip =>
      'Push this local branch to the remote and set up tracking';

  @override
  String get gitSync => 'Sync';

  @override
  String get gitSyncTooltip => 'Pull remote changes, then push local commits';

  @override
  String get gitCancelOperation => 'Cancel';

  @override
  String get gitRemoteOperationRunning => 'Remote operation in progress...';

  @override
  String get gitRemoteOperationCancelled => 'Operation cancelled';

  @override
  String get gitRemoteOperationBusy =>
      'Another remote operation is already running';

  @override
  String get gitFetchSuccess => 'Fetch completed';

  @override
  String get gitFetchNoChanges => 'Already up to date';

  @override
  String get gitPullSuccess => 'Pull completed';

  @override
  String get gitPullAlreadyUpToDate => 'Already up to date, nothing to pull';

  @override
  String get gitPushSuccess => 'Push completed';

  @override
  String get gitPushUpToDate => 'Remote is already up to date, nothing to push';

  @override
  String get gitNoRemoteConfigured => 'No Remote Configured';

  @override
  String get gitNoRemoteDesc =>
      'Add a remote repository URL to fetch, pull, and push your code.';

  @override
  String get gitAddRemote => 'Add Remote';

  @override
  String get gitRemoteManagement => 'Remote Repositories';

  @override
  String get gitRemoteName => 'Remote Name';

  @override
  String get gitRemoteNameHint => 'e.g. origin';

  @override
  String get gitRemoteUrl => 'Remote URL';

  @override
  String get gitRemoteUrlHint =>
      'https://github.com/user/repo.git or git@github.com:user/repo.git';

  @override
  String get gitRemotePushUrl => 'Push URL (optional)';

  @override
  String get gitRemotePushUrlHint => 'Leave empty to use the fetch URL';

  @override
  String get gitRemoteNameRequired => 'Please enter a remote name';

  @override
  String get gitRemoteUrlRequired => 'Please enter a remote URL';

  @override
  String gitRemoteAdded(String name) {
    return 'Added remote $name';
  }

  @override
  String gitRemoteRemoved(String name) {
    return 'Removed remote $name';
  }

  @override
  String gitRemoteRenamed(String old, String newName) {
    return 'Renamed $old to $newName';
  }

  @override
  String get gitRemoteUrlUpdated => 'Remote URL updated';

  @override
  String get gitRemotePruned => 'Pruned stale remote branches';

  @override
  String gitRemoteRemoveConfirm(String name) {
    return 'Remove remote $name? Your local code will not be deleted.';
  }

  @override
  String get gitRemoteEdit => 'Edit Remote';

  @override
  String get gitRemoteFetchUrl => 'Fetch URL';

  @override
  String get gitRemoteSetPushUrl => 'Set Push URL';

  @override
  String get gitRemotePrune => 'Prune Stale Branches';

  @override
  String get gitCheckConnection => 'Test Connection';

  @override
  String get gitCheckConnectionSuccess => 'Connection OK, authentication works';

  @override
  String get gitNoRemotes => 'No remotes';

  @override
  String get gitFetchFailed => 'Fetch failed';

  @override
  String get gitPullFailed => 'Pull failed';

  @override
  String get gitPushFailed => 'Push failed';

  @override
  String get gitForcePush => 'Force Push';

  @override
  String get gitForcePushTooltip =>
      'Overwrite the remote branch (uses --force-with-lease for safety)';

  @override
  String get gitForcePushWarning =>
      'Force pushing overwrites the remote branch with your local commits and may discard other people\'s work.';

  @override
  String get gitForcePushConfirm => 'Confirm Force Push';

  @override
  String gitForcePushConfirmDesc(String branch) {
    return 'This rewrites the history of remote branch $branch. Only use it when you are certain nobody else pushed new commits.';
  }

  @override
  String get gitForcePushUseLease => 'Use safe force push (--force-with-lease)';

  @override
  String get gitPullThenPush => 'Pull Then Push';

  @override
  String get gitPullThenPushDesc =>
      'The remote has commits you do not have. Pull and merge them before pushing.';

  @override
  String get gitConflictAbort => 'Abort Rebase';

  @override
  String get gitConflictAbortConfirm =>
      'Abort this rebase and return to the state before it started?';

  @override
  String get gitUncommittedChangesTitle => 'Uncommitted Changes';

  @override
  String get gitUncommittedChangesDesc =>
      'Local uncommitted changes must be handled before pulling, or they may be overwritten.';

  @override
  String get gitUncommittedStashAndPull => 'Stash and Pull';

  @override
  String get gitUncommittedCommitFirst => 'Commit First';

  @override
  String get gitUncommittedCancel => 'Cancel';

  @override
  String get gitStashAndPullSuccess =>
      'Stashed local changes and pulled successfully';

  @override
  String get gitViewOperationLog => 'View Details';

  @override
  String get gitHideOperationLog => 'Hide Details';

  @override
  String gitAheadBehind(int ahead, int behind) {
    return '$ahead ahead / $behind behind';
  }

  @override
  String get gitUpstreamGone => 'Upstream branch no longer exists';

  @override
  String gitBehindTooltip(int behind) {
    return '$behind commits behind the remote';
  }

  @override
  String gitAheadTooltip(int ahead) {
    return '$ahead commits ahead of the remote';
  }

  @override
  String get gitDiff => 'Diff';

  @override
  String get gitDiffOriginal => 'Original';

  @override
  String get gitDiffModified => 'Modified';

  @override
  String get gitDiffSplitView => 'Split View';

  @override
  String get gitDiffUnifiedView => 'Unified View';

  @override
  String get gitDiffPrevChange => 'Previous Change';

  @override
  String get gitDiffNextChange => 'Next Change';

  @override
  String get gitDiffBinaryOrEmpty =>
      'Binary or unsupported file for comparison';

  @override
  String get gitDiffNoChanges =>
      'This file is identical to the base version, no differences found';

  @override
  String get gitDiffStageTooltip => 'Stage this file';

  @override
  String get gitDiffUnstageTooltip => 'Unstage this file';

  @override
  String get gitDiffDiscardTooltip => 'Discard changes in this file';

  @override
  String get gitExpandAll => 'Expand All';

  @override
  String gitLoadMoreCommits(int count) {
    return 'Load more commits ($count)';
  }

  @override
  String gitLoadedCommitsCount(int loaded, int total) {
    return 'Showing $loaded of $total commits';
  }

  @override
  String gitAllCommitsLoaded(int count) {
    return 'All $count commits loaded';
  }

  @override
  String get gitLoadingMoreCommits => 'Loading more commits...';

  @override
  String get searchExpandAllMatchesInFile => 'Expand all matches';

  @override
  String get preserveCase => 'Preserve Case';

  @override
  String get replaceMoreOptions => 'More Replace Options';

  @override
  String get searchRefresh => 'Refresh';

  @override
  String get searchPreviousMatch => 'Previous Match';

  @override
  String get searchNextMatch => 'Next Match';

  @override
  String get replaceCurrentMatch => 'Replace';

  @override
  String get gitAccountManagement => 'Git Accounts';

  @override
  String get gitEdit => 'Edit';

  @override
  String get gitHostedAccounts => 'Hosted Accounts';

  @override
  String get gitSshKeys => 'SSH Keys';

  @override
  String get gitAddAccount => 'Add Git Account';

  @override
  String get gitEditAccount => 'Edit Git Account';

  @override
  String get gitNoAccountsTitle => 'No Git Accounts Connected';

  @override
  String get gitNoAccountsSubtitle =>
      'Connect GitHub, Gitee, etc. for seamless passwordless pushing and pulling.';

  @override
  String get gitAddFirstAccount => 'Add First Git Account';

  @override
  String get gitDefaultAccountBadge => 'Default';

  @override
  String get gitSetAsDefault => 'Set as Default';

  @override
  String get gitSetAsDefaultSuccess => 'Set as default account';

  @override
  String get gitTestConnection => 'Test Connection';

  @override
  String get gitTestingConnection => 'Testing platform connection...';

  @override
  String gitTestConnectionSuccess(String username) {
    return 'Connection successful! Verified user: $username';
  }

  @override
  String get gitTestConnectionFailed => 'Verification failed';

  @override
  String get gitDeleteAccount => 'Delete Account';

  @override
  String gitDeleteAccountConfirmTitle(String name) {
    return 'Delete account $name?';
  }

  @override
  String get gitDeleteAccountConfirmMessage =>
      'Credentials will be removed from local storage and the container. Remote operations will require re-authentication.';

  @override
  String get gitDeleteAccountSuccess => 'Account deleted';

  @override
  String get gitAccountSavedSuccess => 'Account added successfully';

  @override
  String get gitAccountUpdatedSuccess => 'Account updated successfully';

  @override
  String get gitContainerSshTitle => 'Container Built-in SSH Key';

  @override
  String get gitContainerSshSubtitle =>
      'Used for SSH clone and push (git@github.com:... or git@gitee.com:...).';

  @override
  String get gitCopyPublicKey => 'Copy Public Key';

  @override
  String get gitPublicKeyCopied => 'Public key copied to clipboard';

  @override
  String get gitRegenerateKey => 'Regenerate';

  @override
  String get gitNoSshKeyNotice =>
      'No SSH key pair generated yet. Once generated, you can copy and paste it into GitHub/Gitee SSH Keys settings.';

  @override
  String get gitGenerateEd25519Key => 'Generate Ed25519 SSH Key';

  @override
  String get gitGeneratingSshKey => 'Generating SSH Key...';

  @override
  String get gitSshKeyGenerateSuccess => 'SSH key generated successfully';

  @override
  String get gitSshKeyGenerateFailed => 'Generation failed';

  @override
  String get gitRegenerateSshConfirmTitle => 'Regenerate SSH Key?';

  @override
  String get gitRegenerateSshConfirmMessage =>
      'Regenerating will overwrite the existing key. The old public key on GitHub/Gitee will become invalid.';

  @override
  String get gitOverwrite => 'Overwrite';

  @override
  String get gitSshGuideTitle => 'How to configure on cloud platforms?';

  @override
  String get gitSshGuideStep1 => 'Click [Copy Public Key] above;';

  @override
  String get gitSshGuideStep2 =>
      'Open GitHub or Gitee settings in browser (Settings -> SSH Keys);';

  @override
  String get gitSshGuideStep3 =>
      'Click \"New SSH Key\", paste the public key into the Key field and save.';

  @override
  String get gitServerUrl => 'Server URL';

  @override
  String get gitTokenLabel => 'Personal Access Token';

  @override
  String get gitTokenHint => 'Enter PAT created on platform';

  @override
  String get gitGetToken => 'Get Token';

  @override
  String get gitTokenCopiedOpeningBrowser =>
      'Token URL copied, opening browser...';

  @override
  String get gitEnterTokenPrompt => 'Please enter Personal Access Token';

  @override
  String get gitTokenVerifyFailed =>
      'Token verification failed. Please check permissions or validity';

  @override
  String get gitVerifyAndSave => 'Verify & Save';

  @override
  String get gitAuthTypeToken => 'Personal Access Token';

  @override
  String get gitAuthTypeSsh => 'SSH Key Pair';

  @override
  String get gitPlatformGeneric => 'Generic / Self-hosted Git';
}
