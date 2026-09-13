import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码编辑器'**
  String get appTitle;

  /// No description provided for @run.
  ///
  /// In zh, this message translates to:
  /// **'运行'**
  String get run;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @fileDirectory.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get fileDirectory;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @openFileDirectory.
  ///
  /// In zh, this message translates to:
  /// **'打开项目'**
  String get openFileDirectory;

  /// No description provided for @openProjectPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请点击上方按钮打开项目'**
  String get openProjectPrompt;

  /// No description provided for @viewProjectHistory.
  ///
  /// In zh, this message translates to:
  /// **'查看项目历史'**
  String get viewProjectHistory;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @noOpenDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前未打开项目'**
  String get noOpenDirectory;

  /// No description provided for @noOpenFile.
  ///
  /// In zh, this message translates to:
  /// **'当前未打开文件'**
  String get noOpenFile;

  /// No description provided for @unnamed.
  ///
  /// In zh, this message translates to:
  /// **'未命名'**
  String get unnamed;

  /// No description provided for @unknownDirectory.
  ///
  /// In zh, this message translates to:
  /// **'未知目录'**
  String get unknownDirectory;

  /// No description provided for @projectHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史项目'**
  String get projectHistory;

  /// No description provided for @noHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get noHistory;

  /// No description provided for @deleteThisHistory.
  ///
  /// In zh, this message translates to:
  /// **'删除此记录'**
  String get deleteThisHistory;

  /// No description provided for @deleteHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除历史记录'**
  String get deleteHistoryTitle;

  /// No description provided for @deleteHistoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要从历史记录中移除该项目吗？'**
  String get deleteHistoryMessage;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @historyRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已移除历史记录'**
  String get historyRemoved;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @closeAllTabs.
  ///
  /// In zh, this message translates to:
  /// **'关闭所有标签'**
  String get closeAllTabs;

  /// No description provided for @closeProject.
  ///
  /// In zh, this message translates to:
  /// **'关闭当前项目'**
  String get closeProject;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @newFile.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get newFile;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @fileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'文件名 (例如: main.dart)'**
  String get fileNameHint;

  /// No description provided for @folderNameHint.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名'**
  String get folderNameHint;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @newName.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get newName;

  /// No description provided for @cut.
  ///
  /// In zh, this message translates to:
  /// **'剪切'**
  String get cut;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @copyPath.
  ///
  /// In zh, this message translates to:
  /// **'复制路径'**
  String get copyPath;

  /// No description provided for @copyRelativePath.
  ///
  /// In zh, this message translates to:
  /// **'复制相对路径'**
  String get copyRelativePath;

  /// No description provided for @copiedPathToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制完整路径到剪贴板'**
  String get copiedPathToClipboard;

  /// No description provided for @copiedRelativePathToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制相对路径到剪贴板'**
  String get copiedRelativePathToClipboard;

  /// No description provided for @cutItem.
  ///
  /// In zh, this message translates to:
  /// **'已剪切: {name}'**
  String cutItem(Object name);

  /// No description provided for @copiedItem.
  ///
  /// In zh, this message translates to:
  /// **'已复制: {name}'**
  String copiedItem(Object name);

  /// No description provided for @operationSuccess.
  ///
  /// In zh, this message translates to:
  /// **'操作成功'**
  String get operationSuccess;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败: {error}'**
  String operationFailed(Object error);

  /// No description provided for @createFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建文件失败: {error}'**
  String createFileFailed(Object error);

  /// No description provided for @createFolderFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建文件夹失败: {error}'**
  String createFolderFailed(Object error);

  /// No description provided for @renameFailed.
  ///
  /// In zh, this message translates to:
  /// **'重命名失败: {error}'**
  String renameFailed(Object error);

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败: {error}'**
  String deleteFailed(Object error);

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 \"{name}\" 吗？此操作不可恢复。'**
  String confirmDeleteMessage(Object name);

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空'**
  String get nameCannotBeEmpty;

  /// No description provided for @nameInvalidChars.
  ///
  /// In zh, this message translates to:
  /// **'名称不能包含非法字符 (\\/:*?\"<>|)'**
  String get nameInvalidChars;

  /// No description provided for @appearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceSection;

  /// No description provided for @appThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'应用主题模式'**
  String get appThemeMode;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @followSystemSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自动与系统深浅色外观保持一致'**
  String get followSystemSubtitle;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @lightModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终保持明亮外观'**
  String get lightModeSubtitle;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终保持暗黑外观'**
  String get darkModeSubtitle;

  /// No description provided for @selectAppTheme.
  ///
  /// In zh, this message translates to:
  /// **'选择应用主题'**
  String get selectAppTheme;

  /// No description provided for @editorSection.
  ///
  /// In zh, this message translates to:
  /// **'编辑区'**
  String get editorSection;

  /// No description provided for @codeHighlightTheme.
  ///
  /// In zh, this message translates to:
  /// **'代码高亮主题'**
  String get codeHighlightTheme;

  /// No description provided for @selectCodeHighlightTheme.
  ///
  /// In zh, this message translates to:
  /// **'选择代码高亮主题'**
  String get selectCodeHighlightTheme;

  /// No description provided for @darkThemeCategory.
  ///
  /// In zh, this message translates to:
  /// **'暗色系'**
  String get darkThemeCategory;

  /// No description provided for @lightThemeCategory.
  ///
  /// In zh, this message translates to:
  /// **'浅色系'**
  String get lightThemeCategory;

  /// No description provided for @codeFontSize.
  ///
  /// In zh, this message translates to:
  /// **'代码字号缩放'**
  String get codeFontSize;

  /// No description provided for @uiFont.
  ///
  /// In zh, this message translates to:
  /// **'界面字体'**
  String get uiFont;

  /// No description provided for @selectUiFont.
  ///
  /// In zh, this message translates to:
  /// **'选择界面字体'**
  String get selectUiFont;

  /// No description provided for @themeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题颜色'**
  String get themeColor;

  /// No description provided for @selectThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'选择主题颜色'**
  String get selectThemeColor;

  /// No description provided for @terminalBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'终端背景颜色'**
  String get terminalBackgroundColor;

  /// No description provided for @selectTerminalBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'选择终端背景颜色'**
  String get selectTerminalBackgroundColor;

  /// No description provided for @uiFontPreview.
  ///
  /// In zh, this message translates to:
  /// **'代码编辑器界面字体预览 Code Editor 123'**
  String get uiFontPreview;

  /// No description provided for @codeFont.
  ///
  /// In zh, this message translates to:
  /// **'代码字体'**
  String get codeFont;

  /// No description provided for @selectCodeFont.
  ///
  /// In zh, this message translates to:
  /// **'选择代码字体'**
  String get selectCodeFont;

  /// No description provided for @codeFontPreview.
  ///
  /// In zh, this message translates to:
  /// **'const app = \"Code Editor\"; // 代码预览'**
  String get codeFontPreview;

  /// No description provided for @terminalFont.
  ///
  /// In zh, this message translates to:
  /// **'终端字体'**
  String get terminalFont;

  /// No description provided for @selectTerminalFont.
  ///
  /// In zh, this message translates to:
  /// **'选择终端字体'**
  String get selectTerminalFont;

  /// No description provided for @terminalFontPreview.
  ///
  /// In zh, this message translates to:
  /// **'\$ git status -s # 终端字体预览'**
  String get terminalFontPreview;

  /// No description provided for @fontName.
  ///
  /// In zh, this message translates to:
  /// **'{font, select, system_default{系统默认} sans_serif{无衬线体} serif{衬线体（宋体）} monospace{系统等宽} consolas{Consolas} courier_new{Courier New} menlo{Menlo / Monaco} jetbrains_mono{JetBrains Mono} fira_code{Fira Code} other{{font}}}'**
  String fontName(String font);

  /// No description provided for @decreaseFontSize.
  ///
  /// In zh, this message translates to:
  /// **'减小字号'**
  String get decreaseFontSize;

  /// No description provided for @increaseFontSize.
  ///
  /// In zh, this message translates to:
  /// **'增大字号'**
  String get increaseFontSize;

  /// No description provided for @fontSizeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码字号'**
  String get fontSizeDialogTitle;

  /// No description provided for @indentSize.
  ///
  /// In zh, this message translates to:
  /// **'缩进大小'**
  String get indentSize;

  /// No description provided for @selectIndentSize.
  ///
  /// In zh, this message translates to:
  /// **'选择缩进空格数'**
  String get selectIndentSize;

  /// 缩进空格数量展示
  ///
  /// In zh, this message translates to:
  /// **'{count} 个空格'**
  String spacesCount(int count);

  /// No description provided for @wordWrap.
  ///
  /// In zh, this message translates to:
  /// **'自动换行'**
  String get wordWrap;

  /// No description provided for @wordWrapSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'长代码行超出边界时自动折行'**
  String get wordWrapSubtitle;

  /// No description provided for @virtualKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'辅助小键盘'**
  String get virtualKeyboard;

  /// No description provided for @virtualKeyboardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在代码编辑区底部显示辅助符号与快捷键'**
  String get virtualKeyboardSubtitle;

  /// No description provided for @editVirtualKeyboardConfig.
  ///
  /// In zh, this message translates to:
  /// **'编辑键盘配置'**
  String get editVirtualKeyboardConfig;

  /// No description provided for @editVirtualKeyboardConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义小键盘按键布局与快捷键'**
  String get editVirtualKeyboardConfigSubtitle;

  /// No description provided for @terminalVirtualKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'终端小键盘'**
  String get terminalVirtualKeyboard;

  /// No description provided for @terminalVirtualKeyboardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在终端下方显示常用特殊键与指令快捷键'**
  String get terminalVirtualKeyboardSubtitle;

  /// No description provided for @editTerminalVirtualKeyboardConfig.
  ///
  /// In zh, this message translates to:
  /// **'编辑终端键盘配置'**
  String get editTerminalVirtualKeyboardConfig;

  /// No description provided for @editTerminalVirtualKeyboardConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义 Esc / Tab / Ctrl 组合等终端专用按键'**
  String get editTerminalVirtualKeyboardConfigSubtitle;

  /// No description provided for @virtualKeyboardDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'小键盘配置 (JSON)'**
  String get virtualKeyboardDialogTitle;

  /// No description provided for @resetDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get resetDefault;

  /// No description provided for @configFormatError.
  ///
  /// In zh, this message translates to:
  /// **'配置格式错误'**
  String get configFormatError;

  /// No description provided for @configSavedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'小键盘配置已保存'**
  String get configSavedSuccess;

  /// No description provided for @formatJson.
  ///
  /// In zh, this message translates to:
  /// **'格式化'**
  String get formatJson;

  /// No description provided for @languageSection.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageSection;

  /// No description provided for @appLanguage.
  ///
  /// In zh, this message translates to:
  /// **'应用语言'**
  String get appLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择应用语言'**
  String get selectLanguage;

  /// No description provided for @languageFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageFollowSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @refreshDirectory.
  ///
  /// In zh, this message translates to:
  /// **'刷新项目'**
  String get refreshDirectory;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @darkLabel.
  ///
  /// In zh, this message translates to:
  /// **'暗色'**
  String get darkLabel;

  /// No description provided for @lightLabel.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get lightLabel;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get saveSuccess;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String saveFailed(Object error);

  /// No description provided for @saveChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存更改'**
  String get saveChangesTitle;

  /// No description provided for @saveChangesMessage.
  ///
  /// In zh, this message translates to:
  /// **'文件 \"{name}\" 已被修改，是否保存更改？'**
  String saveChangesMessage(Object name);

  /// No description provided for @dontSave.
  ///
  /// In zh, this message translates to:
  /// **'不保存'**
  String get dontSave;

  /// No description provided for @saveAll.
  ///
  /// In zh, this message translates to:
  /// **'保存所有'**
  String get saveAll;

  /// No description provided for @saveAllSuccess.
  ///
  /// In zh, this message translates to:
  /// **'所有文件已保存'**
  String get saveAllSuccess;

  /// No description provided for @saveAllPromptTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存所有更改？'**
  String get saveAllPromptTitle;

  /// No description provided for @saveAllPromptMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前项目中有未保存的修改，是否保存所有文件？'**
  String get saveAllPromptMessage;

  /// No description provided for @fileConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'外部文件已被更改'**
  String get fileConflictTitle;

  /// No description provided for @fileConflictMessage.
  ///
  /// In zh, this message translates to:
  /// **'文件 \"{name}\" 已在外部被更改。您希望如何处理？'**
  String fileConflictMessage(Object name);

  /// No description provided for @reloadFromDisk.
  ///
  /// In zh, this message translates to:
  /// **'用磁盘内容覆盖'**
  String get reloadFromDisk;

  /// No description provided for @keepLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本地修改'**
  String get keepLocal;

  /// No description provided for @storagePermissionRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要存储访问权限'**
  String get storagePermissionRequiredTitle;

  /// No description provided for @storagePermissionRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'代码编辑器需要“管理所有文件”权限，以便在您的设备上读取、新建和保存项目文件。\n\n请在接下来的系统设置页面中开启该权限。'**
  String get storagePermissionRequiredMessage;

  /// No description provided for @goToSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get goToSettings;

  /// No description provided for @terminal.
  ///
  /// In zh, this message translates to:
  /// **'终端'**
  String get terminal;

  /// No description provided for @terminalWithSystem.
  ///
  /// In zh, this message translates to:
  /// **'终端 · {system}'**
  String terminalWithSystem(String system);

  /// No description provided for @sessionDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get sessionDefaultName;

  /// No description provided for @systemManagement.
  ///
  /// In zh, this message translates to:
  /// **'系统管理'**
  String get systemManagement;

  /// No description provided for @systemManagementTooltip.
  ///
  /// In zh, this message translates to:
  /// **'系统管理与选择'**
  String get systemManagementTooltip;

  /// No description provided for @sessionListTooltip.
  ///
  /// In zh, this message translates to:
  /// **'会话列表'**
  String get sessionListTooltip;

  /// No description provided for @noActiveSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无活跃会话'**
  String get noActiveSessions;

  /// No description provided for @terminalInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入命令...'**
  String get terminalInputHint;

  /// No description provided for @sendCommandTooltip.
  ///
  /// In zh, this message translates to:
  /// **'发送命令'**
  String get sendCommandTooltip;

  /// No description provided for @importNewSystem.
  ///
  /// In zh, this message translates to:
  /// **'导入新系统'**
  String get importNewSystem;

  /// No description provided for @importBuiltinAlpine.
  ///
  /// In zh, this message translates to:
  /// **'从软件中导入 (Alpine)'**
  String get importBuiltinAlpine;

  /// No description provided for @importExternalTarGz.
  ///
  /// In zh, this message translates to:
  /// **'从外部导入 (.tar.gz)'**
  String get importExternalTarGz;

  /// No description provided for @selectSystemDefaultPrompt.
  ///
  /// In zh, this message translates to:
  /// **'选择系统将设为默认系统，新建终端时从该系统中启动：'**
  String get selectSystemDefaultPrompt;

  /// No description provided for @noSystemsPrompt.
  ///
  /// In zh, this message translates to:
  /// **'暂无系统，请点击右上角 \"+\" 导入'**
  String get noSystemsPrompt;

  /// No description provided for @importBuiltinAlpineTitle.
  ///
  /// In zh, this message translates to:
  /// **'从软件导入 Alpine 系统'**
  String get importBuiltinAlpineTitle;

  /// No description provided for @systemNameHintWithDefault.
  ///
  /// In zh, this message translates to:
  /// **'系统名称（如 {name}）'**
  String systemNameHintWithDefault(String name);

  /// No description provided for @systemImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'系统 \"{name}\" 导入并就绪'**
  String systemImportSuccess(String name);

  /// No description provided for @importExternalSystemTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入外部系统'**
  String get importExternalSystemTitle;

  /// No description provided for @systemNameHint.
  ///
  /// In zh, this message translates to:
  /// **'系统名称'**
  String get systemNameHint;

  /// No description provided for @externalSystemImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'外部系统 \"{name}\" 导入并就绪'**
  String externalSystemImportSuccess(String name);

  /// No description provided for @deleteSystemConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'高危操作：确认删除系统'**
  String get deleteSystemConfirmTitle;

  /// No description provided for @deleteSystemConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要彻底删除系统 \"{name}\" 吗？\n\n⚠️ 该操作将物理级清除该系统及其所有内部数据与已安装软件包，此操作不可逆！\n\n该系统关联的所有终端会话也将被同步关闭。'**
  String deleteSystemConfirmMessage(String name);

  /// No description provided for @permanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get permanentDelete;

  /// No description provided for @deleteSystemSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除系统 \"{name}\" 及关联会话'**
  String deleteSystemSuccess(String name);

  /// No description provided for @deleteSystemTooltip.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除该系统 (高危)'**
  String get deleteSystemTooltip;

  /// No description provided for @preparingInitialization.
  ///
  /// In zh, this message translates to:
  /// **'准备初始化...'**
  String get preparingInitialization;

  /// No description provided for @cancellingAndCleaning.
  ///
  /// In zh, this message translates to:
  /// **'正在取消并清理残余目录...'**
  String get cancellingAndCleaning;

  /// No description provided for @cancelledImportSystem.
  ///
  /// In zh, this message translates to:
  /// **'已取消导入系统 \"{name}\"'**
  String cancelledImportSystem(String name);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String importFailed(String error);

  /// No description provided for @importingSystemTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在导入: {name}'**
  String importingSystemTitle(String name);

  /// No description provided for @cancelImport.
  ///
  /// In zh, this message translates to:
  /// **'取消导入'**
  String get cancelImport;

  /// No description provided for @interrupting.
  ///
  /// In zh, this message translates to:
  /// **'正在中断...'**
  String get interrupting;

  /// No description provided for @sessionDrawerTitle.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get sessionDrawerTitle;

  /// No description provided for @addTerminalTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加终端'**
  String get addTerminalTooltip;

  /// No description provided for @noSystemSelectedWarning.
  ///
  /// In zh, this message translates to:
  /// **'当前未选择任何系统，请先导入或选择系统'**
  String get noSystemSelectedWarning;

  /// No description provided for @noSessionsInDrawerPrompt.
  ///
  /// In zh, this message translates to:
  /// **'暂无会话，请点击右上角添加'**
  String get noSessionsInDrawerPrompt;

  /// No description provided for @confirmDeleteTerminalSession.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除终端 \"({index}) {name}\" 吗？'**
  String confirmDeleteTerminalSession(int index, String name);

  /// No description provided for @deleteSystemFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除系统失败: {error}'**
  String deleteSystemFailed(String error);

  /// No description provided for @addSession.
  ///
  /// In zh, this message translates to:
  /// **'新增会话'**
  String get addSession;

  /// No description provided for @editorScope.
  ///
  /// In zh, this message translates to:
  /// **'编辑区'**
  String get editorScope;

  /// No description provided for @terminalScope.
  ///
  /// In zh, this message translates to:
  /// **'终端'**
  String get terminalScope;

  /// No description provided for @virtualKeyboardConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'小键盘配置'**
  String get virtualKeyboardConfigTitle;

  /// No description provided for @virtualKeyboardPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{scope}:(第 {page} 页)'**
  String virtualKeyboardPageSubtitle(String scope, int page);

  /// No description provided for @keyboardRestoreDefaultTooltip.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认预设'**
  String get keyboardRestoreDefaultTooltip;

  /// No description provided for @keyboardPageManagementTooltip.
  ///
  /// In zh, this message translates to:
  /// **'页面管理'**
  String get keyboardPageManagementTooltip;

  /// No description provided for @keyboardDrawerTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面'**
  String get keyboardDrawerTitle;

  /// No description provided for @keyboardNewPage.
  ///
  /// In zh, this message translates to:
  /// **'新建页面'**
  String get keyboardNewPage;

  /// No description provided for @keyboardPageItemTitle.
  ///
  /// In zh, this message translates to:
  /// **'第 {page} 页'**
  String keyboardPageItemTitle(int page);

  /// No description provided for @keyboardPageItemSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 行'**
  String keyboardPageItemSubtitle(int count);

  /// No description provided for @keyboardDeletePageTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除页面'**
  String get keyboardDeletePageTooltip;

  /// No description provided for @keyboardPageConfigSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面配置'**
  String get keyboardPageConfigSectionTitle;

  /// No description provided for @keyboardRowButtons.
  ///
  /// In zh, this message translates to:
  /// **'行按钮数'**
  String get keyboardRowButtons;

  /// No description provided for @keyboardRowGridDescription.
  ///
  /// In zh, this message translates to:
  /// **'页面宽度等分为 {count} 格'**
  String keyboardRowGridDescription(int count);

  /// No description provided for @keyboardDecreaseRowButtonsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'减少每行按键数'**
  String get keyboardDecreaseRowButtonsTooltip;

  /// No description provided for @keyboardIncreaseRowButtonsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'增加每行按键数'**
  String get keyboardIncreaseRowButtonsTooltip;

  /// No description provided for @keyboardPageKeysSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面按键'**
  String get keyboardPageKeysSectionTitle;

  /// No description provided for @keyboardAddNewRow.
  ///
  /// In zh, this message translates to:
  /// **'添加新行'**
  String get keyboardAddNewRow;

  /// No description provided for @keyboardEmptyPageKeysHint.
  ///
  /// In zh, this message translates to:
  /// **'当前页面暂无按键行'**
  String get keyboardEmptyPageKeysHint;

  /// No description provided for @keyboardEmptyRowKeysHint.
  ///
  /// In zh, this message translates to:
  /// **'行内暂无按键，点击上方“+”添加'**
  String get keyboardEmptyRowKeysHint;

  /// No description provided for @keyboardRowKeyCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个按键'**
  String keyboardRowKeyCount(int count);

  /// No description provided for @keyboardAddKeyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加按键'**
  String get keyboardAddKeyTooltip;

  /// No description provided for @keyboardDeleteRowTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除整行'**
  String get keyboardDeleteRowTooltip;

  /// No description provided for @keyboardEditKeyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑按键'**
  String get keyboardEditKeyTooltip;

  /// No description provided for @keyboardDeleteKeyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除按键'**
  String get keyboardDeleteKeyTooltip;

  /// No description provided for @keyboardNoLabel.
  ///
  /// In zh, this message translates to:
  /// **'(无标签)'**
  String get keyboardNoLabel;

  /// No description provided for @keyboardResetDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认配置'**
  String get keyboardResetDefaultTitle;

  /// No description provided for @keyboardResetDefaultContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要将小键盘恢复为初始默认预设吗？当前自定义修改将被覆盖。'**
  String get keyboardResetDefaultContent;

  /// No description provided for @keyboardResetDefaultSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认预设'**
  String get keyboardResetDefaultSuccess;

  /// No description provided for @keyboardDeletePageTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除页面'**
  String get keyboardDeletePageTitle;

  /// No description provided for @keyboardDeletePageContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除“第 {page} 页”吗？'**
  String keyboardDeletePageContent(int page);

  /// No description provided for @keyboardDeleteRowTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除按键行'**
  String get keyboardDeleteRowTitle;

  /// No description provided for @keyboardDeleteRowContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除“第 {row} 行”及其包含的所有按键吗？'**
  String keyboardDeleteRowContent(int row);

  /// No description provided for @keyboardDeleteKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除按键'**
  String get keyboardDeleteKeyTitle;

  /// No description provided for @keyboardDeleteKeyContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除按键“{key}”吗？'**
  String keyboardDeleteKeyContent(String key);

  /// No description provided for @keyboardKeepAtLeastOnePageWarning.
  ///
  /// In zh, this message translates to:
  /// **'至少需要保留一个页面'**
  String get keyboardKeepAtLeastOnePageWarning;

  /// No description provided for @keyboardRowMaxKeysWarning.
  ///
  /// In zh, this message translates to:
  /// **'当前存在包含 {count} 个按键的行，行按钮数不能小于 {count}'**
  String keyboardRowMaxKeysWarning(int count);

  /// No description provided for @keyboardRowReachedMaxWarning.
  ///
  /// In zh, this message translates to:
  /// **'当前行按键数已达到上限（最多 {count} 个按键）'**
  String keyboardRowReachedMaxWarning(int count);

  /// No description provided for @keyboardAddKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加按键'**
  String get keyboardAddKeyTitle;

  /// No description provided for @keyboardEditKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑按键'**
  String get keyboardEditKeyTitle;

  /// No description provided for @keyboardLabelFormField.
  ///
  /// In zh, this message translates to:
  /// **'显示文本'**
  String get keyboardLabelFormField;

  /// No description provided for @keyboardLabelFormFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'按键上显示的文本，如 Tab、()、A'**
  String get keyboardLabelFormFieldHint;

  /// No description provided for @keyboardLabelOrIconRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'请输入显示文本或选择图标'**
  String get keyboardLabelOrIconRequiredError;

  /// No description provided for @keyboardIconFormField.
  ///
  /// In zh, this message translates to:
  /// **'图标 (可选)'**
  String get keyboardIconFormField;

  /// No description provided for @keyboardIconName.
  ///
  /// In zh, this message translates to:
  /// **'{icon, select, undo{撤销} redo{重做} tab{向右缩进} untab{向左缩进} outdent{减少缩进} arrow_left{左箭头} arrow_right{右箭头} arrow_up{上箭头} arrow_down{下箭头} home{移至行首} end{移至行尾} first_page{移至文首} last_page{移至文末} page_up{上翻页} page_down{下翻页} enter{回车} space{空格} escape{退出} insert{插入} clear{清除} keyboard{键盘} backspace{退格} delete{删除} copy{复制} cut{剪切} paste{粘贴} save{保存} search{搜索} select_all{全选} keyboard_hide{收起小键盘} other{{icon}}}'**
  String keyboardIconName(String icon);

  /// No description provided for @keyboardNoIconOption.
  ///
  /// In zh, this message translates to:
  /// **'无图标 (使用文本显示)'**
  String get keyboardNoIconOption;

  /// No description provided for @keyboardActionFormField.
  ///
  /// In zh, this message translates to:
  /// **'动作类型'**
  String get keyboardActionFormField;

  /// No description provided for @keyboardActionName.
  ///
  /// In zh, this message translates to:
  /// **'{action, select, input{普通文本} pair{成对符号} command{编辑器命令} modifier{修饰键} key{特殊键} other{{action}}}'**
  String keyboardActionName(String action);

  /// No description provided for @keyboardActionInputTerminal.
  ///
  /// In zh, this message translates to:
  /// **'指令快捷键'**
  String get keyboardActionInputTerminal;

  /// No description provided for @keyboardKeyFormField.
  ///
  /// In zh, this message translates to:
  /// **'特殊键'**
  String get keyboardKeyFormField;

  /// No description provided for @keyboardKeyGroupNavigation.
  ///
  /// In zh, this message translates to:
  /// **'导航键'**
  String get keyboardKeyGroupNavigation;

  /// No description provided for @keyboardKeyGroupEditing.
  ///
  /// In zh, this message translates to:
  /// **'编辑键'**
  String get keyboardKeyGroupEditing;

  /// No description provided for @keyboardKeyGroupFunctionKeys.
  ///
  /// In zh, this message translates to:
  /// **'功能键'**
  String get keyboardKeyGroupFunctionKeys;

  /// No description provided for @keyboardKeyGroupLetters.
  ///
  /// In zh, this message translates to:
  /// **'字母键'**
  String get keyboardKeyGroupLetters;

  /// No description provided for @keyboardAutoEnter.
  ///
  /// In zh, this message translates to:
  /// **'发送后自动回车'**
  String get keyboardAutoEnter;

  /// No description provided for @keyboardKeyName.
  ///
  /// In zh, this message translates to:
  /// **'{key, select, escape{退出} tab{Tab} backtab{反向制表} returnKey{回车} enter{回车} numpadEnter{小键盘回车} backspace{退格} delete{删除} insert{插入} space{空格} numpadClear{清除} arrowUp{上} arrowDown{下} arrowLeft{左} arrowRight{右} home{行首} end{行尾} pageUp{上翻页} pageDown{下翻页} f1{F1} f2{F2} f3{F3} f4{F4} f5{F5} f6{F6} f7{F7} f8{F8} f9{F9} f10{F10} f11{F11} f12{F12} other{{key}}}'**
  String keyboardKeyName(String key);

  /// No description provided for @keyboardKeyInvalidError.
  ///
  /// In zh, this message translates to:
  /// **'该键在终端中不会产生任何输出，请选择列表中的特殊键'**
  String get keyboardKeyInvalidError;

  /// No description provided for @keyboardValueFormField.
  ///
  /// In zh, this message translates to:
  /// **'输入文本内容'**
  String get keyboardValueFormField;

  /// No description provided for @keyboardValueFormFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'点击后直接插入的文本，如 ;、=、->'**
  String get keyboardValueFormFieldHint;

  /// No description provided for @keyboardValueRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'输入文本不能为空'**
  String get keyboardValueRequiredError;

  /// No description provided for @keyboardPairValueFormField.
  ///
  /// In zh, this message translates to:
  /// **'成对符号'**
  String get keyboardPairValueFormField;

  /// No description provided for @keyboardPairValueFormFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 ()、[]、\"\"、<>'**
  String get keyboardPairValueFormFieldHint;

  /// No description provided for @keyboardPairValueRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'请输入成对符号'**
  String get keyboardPairValueRequiredError;

  /// No description provided for @keyboardPairValueInvalidError.
  ///
  /// In zh, this message translates to:
  /// **'请输入至少 2 个字符且左右不同的成对符号，如 ()、[]'**
  String get keyboardPairValueInvalidError;

  /// No description provided for @keyboardCommandPresetFormField.
  ///
  /// In zh, this message translates to:
  /// **'编辑器命令'**
  String get keyboardCommandPresetFormField;

  /// No description provided for @keyboardCommandName.
  ///
  /// In zh, this message translates to:
  /// **'{command, select, tab{向右缩进} untab{向左缩进} undo{撤销} redo{重做} cursor_left{光标左移} cursor_right{光标右移} cursor_up{光标上移} cursor_down{光标下移} line_start{移动至行首} line_end{移动至行尾} page_start{移动至文首} page_end{移动至文末} copy{复制} cut{剪切} paste{粘贴} delete{删除} select_all{全选} keyboard_hide{收起小键盘} other{{command}}}'**
  String keyboardCommandName(String command);

  /// No description provided for @keyboardModifierPresetFormField.
  ///
  /// In zh, this message translates to:
  /// **'终端修饰键'**
  String get keyboardModifierPresetFormField;

  /// No description provided for @keyboardModifierName.
  ///
  /// In zh, this message translates to:
  /// **'{modifier, select, ctrl{Ctrl 键} alt{Alt 键} shift{Shift 键} other{{modifier}}}'**
  String keyboardModifierName(String modifier);

  /// No description provided for @keyboardCursorOffsetFormField.
  ///
  /// In zh, this message translates to:
  /// **'光标相对偏移'**
  String get keyboardCursorOffsetFormField;

  /// No description provided for @keyboardCursorOffsetRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'请输入光标偏移（通常为 -1）'**
  String get keyboardCursorOffsetRequiredError;

  /// No description provided for @keyboardCursorOffsetIntegerError.
  ///
  /// In zh, this message translates to:
  /// **'偏移量必须为整数'**
  String get keyboardCursorOffsetIntegerError;

  /// No description provided for @recommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get recommended;

  /// No description provided for @presetColors.
  ///
  /// In zh, this message translates to:
  /// **'预设颜色'**
  String get presetColors;

  /// No description provided for @hexColor.
  ///
  /// In zh, this message translates to:
  /// **'十六进制颜色'**
  String get hexColor;

  /// No description provided for @currentColor.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentColor;

  /// No description provided for @newColor.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get newColor;

  /// No description provided for @runTasks.
  ///
  /// In zh, this message translates to:
  /// **'运行任务'**
  String get runTasks;

  /// No description provided for @projectDetect.
  ///
  /// In zh, this message translates to:
  /// **'项目探测'**
  String get projectDetect;

  /// No description provided for @projectDetecting.
  ///
  /// In zh, this message translates to:
  /// **'正在探测项目...'**
  String get projectDetecting;

  /// No description provided for @editRunTasks.
  ///
  /// In zh, this message translates to:
  /// **'运行任务编辑'**
  String get editRunTasks;

  /// No description provided for @projectSection.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get projectSection;

  /// No description provided for @showHiddenFiles.
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏文件'**
  String get showHiddenFiles;

  /// No description provided for @showHiddenFilesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在文件树中展示以点 (.) 开头的隐藏文件与文件夹'**
  String get showHiddenFilesSubtitle;

  /// No description provided for @searchTasksHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索指定任务...'**
  String get searchTasksHint;

  /// No description provided for @noTasksAvailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无可执行任务'**
  String get noTasksAvailable;

  /// No description provided for @noMatchingTasks.
  ///
  /// In zh, this message translates to:
  /// **'无匹配的任务'**
  String get noMatchingTasks;

  /// No description provided for @userCustomTasks.
  ///
  /// In zh, this message translates to:
  /// **'用户自定义任务'**
  String get userCustomTasks;

  /// No description provided for @systemDetectedTasks.
  ///
  /// In zh, this message translates to:
  /// **'系统动态探测任务'**
  String get systemDetectedTasks;

  /// No description provided for @editCustomTasksTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑自定义任务'**
  String get editCustomTasksTooltip;

  /// No description provided for @runTasksConfig.
  ///
  /// In zh, this message translates to:
  /// **'运行任务配置'**
  String get runTasksConfig;

  /// No description provided for @editTask.
  ///
  /// In zh, this message translates to:
  /// **'编辑任务'**
  String get editTask;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'新增任务'**
  String get addTask;

  /// No description provided for @runTasksConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置将自动保存至项目根目录下的 .code_editor/run_tasks.json'**
  String get runTasksConfigSubtitle;

  /// No description provided for @noCustomTasksInProject.
  ///
  /// In zh, this message translates to:
  /// **'当前项目暂无自定义任务'**
  String get noCustomTasksInProject;

  /// No description provided for @createNow.
  ///
  /// In zh, this message translates to:
  /// **'立即创建'**
  String get createNow;

  /// No description provided for @saveAndApply.
  ///
  /// In zh, this message translates to:
  /// **'保存并应用'**
  String get saveAndApply;

  /// No description provided for @taskNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'任务名称 *'**
  String get taskNameRequired;

  /// No description provided for @taskNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如: 编译并运行 Debug'**
  String get taskNameHint;

  /// No description provided for @taskNameEmptyError.
  ///
  /// In zh, this message translates to:
  /// **'请输入任务名称'**
  String get taskNameEmptyError;

  /// No description provided for @shellCommandRequired.
  ///
  /// In zh, this message translates to:
  /// **'Shell 执行指令 *'**
  String get shellCommandRequired;

  /// No description provided for @shellCommandHint.
  ///
  /// In zh, this message translates to:
  /// **'如: cmake -B build && cmake --build build'**
  String get shellCommandHint;

  /// No description provided for @shellCommandEmptyError.
  ///
  /// In zh, this message translates to:
  /// **'请输入执行指令'**
  String get shellCommandEmptyError;

  /// No description provided for @taskDescOptional.
  ///
  /// In zh, this message translates to:
  /// **'任务描述（选填）'**
  String get taskDescOptional;

  /// No description provided for @taskDescHint.
  ///
  /// In zh, this message translates to:
  /// **'简要说明此任务的用途'**
  String get taskDescHint;

  /// No description provided for @clearBeforeRun.
  ///
  /// In zh, this message translates to:
  /// **'执行前清屏 (clear)'**
  String get clearBeforeRun;

  /// No description provided for @clearBeforeRunSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在终端输出任务结果前清理历史屏幕'**
  String get clearBeforeRunSubtitle;

  /// No description provided for @runTasksUpdated.
  ///
  /// In zh, this message translates to:
  /// **'运行任务配置已更新'**
  String get runTasksUpdated;

  /// No description provided for @detectCompletedMessage.
  ///
  /// In zh, this message translates to:
  /// **'探测完成，发现 {count} 个可用任务'**
  String detectCompletedMessage(int count);

  /// No description provided for @pleaseOpenProjectFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先打开一个项目'**
  String get pleaseOpenProjectFirst;

  /// No description provided for @deleteTaskConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除任务 \"{name}\" 吗？'**
  String deleteTaskConfirmMessage(String name);

  /// No description provided for @deleteSelectedTasksConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个任务吗？'**
  String deleteSelectedTasksConfirmMessage(int count);

  /// No description provided for @deleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除选中'**
  String get deleteSelected;

  /// No description provided for @selectTasksToDelete.
  ///
  /// In zh, this message translates to:
  /// **'选择要删除的任务'**
  String get selectTasksToDelete;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String selectedCount(int count);

  /// No description provided for @unsavedTaskChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'未保存的任务更改'**
  String get unsavedTaskChangesTitle;

  /// No description provided for @unsavedTaskChangesMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前任务内容已被修改，是否放弃未保存的修改并返回？'**
  String get unsavedTaskChangesMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
