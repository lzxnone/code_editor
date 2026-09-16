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

  /// No description provided for @terminalFontSize.
  ///
  /// In zh, this message translates to:
  /// **'终端字号'**
  String get terminalFontSize;

  /// No description provided for @terminalFontSizeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'终端字号'**
  String get terminalFontSizeDialogTitle;

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

  /// No description provided for @showLineNumbers.
  ///
  /// In zh, this message translates to:
  /// **'显示行号'**
  String get showLineNumbers;

  /// No description provided for @showLineNumbersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在代码左侧显示行号与折叠标记'**
  String get showLineNumbersSubtitle;

  /// No description provided for @pinLineNumbers.
  ///
  /// In zh, this message translates to:
  /// **'固定行号'**
  String get pinLineNumbers;

  /// No description provided for @pinLineNumbersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'水平滚动代码时行号固定在左侧'**
  String get pinLineNumbersSubtitle;

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

  /// No description provided for @importFromApp.
  ///
  /// In zh, this message translates to:
  /// **'从软件中导入'**
  String get importFromApp;

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

  /// No description provided for @distroManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统管理'**
  String get distroManagementTitle;

  /// No description provided for @installedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已就绪'**
  String get installedStatus;

  /// No description provided for @notInstalledStatus.
  ///
  /// In zh, this message translates to:
  /// **'未安装组件'**
  String get notInstalledStatus;

  /// No description provided for @downloadingStatus.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadingStatus;

  /// No description provided for @downloadAction.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get downloadAction;

  /// No description provided for @installAction.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get installAction;

  /// No description provided for @builtinTag.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get builtinTag;

  /// No description provided for @cancelDownloadAction.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownloadAction;

  /// No description provided for @cancelDownloadConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownloadConfirmTitle;

  /// No description provided for @cancelDownloadConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要取消正在下载的系统资源吗？已下载的部分将被清除。'**
  String get cancelDownloadConfirmMessage;

  /// No description provided for @deletingSystemProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在删除系统并清理数据，请稍候...'**
  String get deletingSystemProgress;

  /// No description provided for @cannotDeleteBuiltinSystem.
  ///
  /// In zh, this message translates to:
  /// **'内置系统受到保护，无法删除'**
  String get cannotDeleteBuiltinSystem;

  /// No description provided for @recommendedTag.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get recommendedTag;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String downloadFailed(String error);

  /// No description provided for @deleteSystemSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除系统 \"{name}\" 及关联会话'**
  String deleteSystemSuccess(String name);

  /// No description provided for @deletePackageConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除安装包'**
  String get deletePackageConfirmTitle;

  /// No description provided for @deletePackageConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 \"{name}\" 的系统安装包吗？删除后可随时重新下载。'**
  String deletePackageConfirmMessage(String name);

  /// No description provided for @deletingPackageProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在删除安装包，请稍候...'**
  String get deletingPackageProgress;

  /// No description provided for @deletePackageSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已删除 \"{name}\" 安装包'**
  String deletePackageSuccess(String name);

  /// No description provided for @deletePackageTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除已下载的系统安装包'**
  String get deletePackageTooltip;

  /// No description provided for @importSystemInstanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建 {name} 系统实例'**
  String importSystemInstanceTitle(String name);

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

  /// No description provided for @resyncModuleTasks.
  ///
  /// In zh, this message translates to:
  /// **'重新同步真实任务'**
  String get resyncModuleTasks;

  /// No description provided for @syncingTasks.
  ///
  /// In zh, this message translates to:
  /// **'正在后台自省任务...'**
  String get syncingTasks;

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
  /// **'执行前清屏'**
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

  /// No description provided for @downloadSection.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get downloadSection;

  /// No description provided for @downloadSource.
  ///
  /// In zh, this message translates to:
  /// **'下载源'**
  String get downloadSource;

  /// No description provided for @selectDownloadSource.
  ///
  /// In zh, this message translates to:
  /// **'选择下载源'**
  String get selectDownloadSource;

  /// No description provided for @mirrorName.
  ///
  /// In zh, this message translates to:
  /// **'{mirror, select, tsinghua{清华大学开源软件镜像站 (推荐)} bfsu{北京外国语大学开源软件镜像站} iscas{中国科学院软件研究所开源镜像站} official{LinuxContainers 官方镜像源} other{{mirror}}}'**
  String mirrorName(String mirror);

  /// No description provided for @unnamedTask.
  ///
  /// In zh, this message translates to:
  /// **'未命名任务'**
  String get unnamedTask;

  /// No description provided for @shellCommandHelperText.
  ///
  /// In zh, this message translates to:
  /// **'支持单行指令（如 make）或多行 Shell 脚本（自动封装执行）'**
  String get shellCommandHelperText;

  /// No description provided for @detectedTaskCmakeBuildRunDesc.
  ///
  /// In zh, this message translates to:
  /// **'配置、编译并尝试启动生成的目标程序'**
  String get detectedTaskCmakeBuildRunDesc;

  /// No description provided for @detectedTaskCmakeBuildDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅执行 cmake 生成与构建'**
  String get detectedTaskCmakeBuildDesc;

  /// No description provided for @detectedTaskCmakeCleanDesc.
  ///
  /// In zh, this message translates to:
  /// **'清理构建缓存目录'**
  String get detectedTaskCmakeCleanDesc;

  /// No description provided for @detectedTaskGradleRunDesc.
  ///
  /// In zh, this message translates to:
  /// **'执行应用程序主入口'**
  String get detectedTaskGradleRunDesc;

  /// No description provided for @detectedTaskGradleAssembleDesc.
  ///
  /// In zh, this message translates to:
  /// **'构建调试输出包'**
  String get detectedTaskGradleAssembleDesc;

  /// No description provided for @detectedTaskGradleBuildDesc.
  ///
  /// In zh, this message translates to:
  /// **'执行完整构建与测试'**
  String get detectedTaskGradleBuildDesc;

  /// No description provided for @detectedTaskMakeDefaultDesc.
  ///
  /// In zh, this message translates to:
  /// **'执行默认 Makefile 构建目标'**
  String get detectedTaskMakeDefaultDesc;

  /// No description provided for @detectedTaskNpmStartDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动 Node 服务或前端开发环境'**
  String get detectedTaskNpmStartDesc;

  /// No description provided for @detectedTaskNpmTestDesc.
  ///
  /// In zh, this message translates to:
  /// **'执行 npm test 测试套件'**
  String get detectedTaskNpmTestDesc;

  /// No description provided for @detectedTaskCargoRunDesc.
  ///
  /// In zh, this message translates to:
  /// **'编译并运行 Rust 项目'**
  String get detectedTaskCargoRunDesc;

  /// No description provided for @detectedTaskCargoBuildDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅编译 Rust 项目'**
  String get detectedTaskCargoBuildDesc;

  /// No description provided for @detectedTaskDartRunDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动 Dart 应用'**
  String get detectedTaskDartRunDesc;

  /// No description provided for @detectedTaskSinglePythonDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Python 脚本'**
  String get detectedTaskSinglePythonDesc;

  /// No description provided for @detectedTaskSingleCDesc.
  ///
  /// In zh, this message translates to:
  /// **'编译并执行当前 C 源文件'**
  String get detectedTaskSingleCDesc;

  /// No description provided for @detectedTaskSingleCppDesc.
  ///
  /// In zh, this message translates to:
  /// **'编译并执行当前 C++ 源文件'**
  String get detectedTaskSingleCppDesc;

  /// No description provided for @detectedTaskSingleShDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Shell 脚本'**
  String get detectedTaskSingleShDesc;

  /// No description provided for @detectedTaskSingleDartDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Dart 文件'**
  String get detectedTaskSingleDartDesc;

  /// No description provided for @detectedTaskSingleGoDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Go 源文件'**
  String get detectedTaskSingleGoDesc;

  /// No description provided for @detectedTaskSingleRustDesc.
  ///
  /// In zh, this message translates to:
  /// **'编译并执行当前 Rust 源文件'**
  String get detectedTaskSingleRustDesc;

  /// No description provided for @detectedTaskSingleJsDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 JS 脚本'**
  String get detectedTaskSingleJsDesc;

  /// No description provided for @missingDistroTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统环境未就绪'**
  String get missingDistroTitle;

  /// No description provided for @noDistroAvailableContent.
  ///
  /// In zh, this message translates to:
  /// **'未检测到可用的 Linux 执行环境。\n\n工程任务需要在 Linux 容器环境中运行。请先安装或下载 Linux 系统（如 Ubuntu 或 Alpine）。'**
  String get noDistroAvailableContent;

  /// No description provided for @distroNotInstalledContent.
  ///
  /// In zh, this message translates to:
  /// **'系统 \"{distro}\" 尚未安装或已被清理。\n\n请在系统管理中安装该系统，或选择其他已就绪的系统。'**
  String distroNotInstalledContent(String distro);

  /// No description provided for @openFromApp.
  ///
  /// In zh, this message translates to:
  /// **'从软件内打开'**
  String get openFromApp;

  /// No description provided for @openFromExternal.
  ///
  /// In zh, this message translates to:
  /// **'从外部打开'**
  String get openFromExternal;

  /// No description provided for @projectsTitle.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get projectsTitle;

  /// No description provided for @newProject.
  ///
  /// In zh, this message translates to:
  /// **'新建项目'**
  String get newProject;

  /// No description provided for @newProjectTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建项目'**
  String get newProjectTitle;

  /// No description provided for @projectNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入项目名称'**
  String get projectNameHint;

  /// No description provided for @renameProject.
  ///
  /// In zh, this message translates to:
  /// **'重命名项目'**
  String get renameProject;

  /// No description provided for @deleteProject.
  ///
  /// In zh, this message translates to:
  /// **'删除项目'**
  String get deleteProject;

  /// No description provided for @deleteProjectConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除项目 \"{name}\" 吗？此操作不可逆。'**
  String deleteProjectConfirmMessage(String name);

  /// No description provided for @projectAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'已存在同名项目'**
  String get projectAlreadyExists;

  /// No description provided for @noProjects.
  ///
  /// In zh, this message translates to:
  /// **'暂无项目，点击右上角新建项目'**
  String get noProjects;

  /// No description provided for @projectCreated.
  ///
  /// In zh, this message translates to:
  /// **'项目创建成功'**
  String get projectCreated;

  /// No description provided for @projectRenamed.
  ///
  /// In zh, this message translates to:
  /// **'项目重命名成功'**
  String get projectRenamed;

  /// No description provided for @projectDeleted.
  ///
  /// In zh, this message translates to:
  /// **'项目已删除'**
  String get projectDeleted;

  /// No description provided for @importFromExternal.
  ///
  /// In zh, this message translates to:
  /// **'从外部导入'**
  String get importFromExternal;

  /// No description provided for @confirmProjectNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认项目名称'**
  String get confirmProjectNameTitle;

  /// No description provided for @importingProject.
  ///
  /// In zh, this message translates to:
  /// **'正在导入项目...'**
  String get importingProject;

  /// No description provided for @projectImported.
  ///
  /// In zh, this message translates to:
  /// **'项目导入成功'**
  String get projectImported;

  /// No description provided for @importProjectFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入项目失败: {error}'**
  String importProjectFailed(String error);

  /// No description provided for @unsupportedProjectArchiveFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持的文件格式，仅支持压缩包格式 (.zip, .tar.gz, .tar.xz, .tar 等)'**
  String get unsupportedProjectArchiveFormat;

  /// No description provided for @unsupportedDistroArchiveFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持的文件格式，仅支持系统镜像包 (.tar.gz, .tar.xz, .tar)'**
  String get unsupportedDistroArchiveFormat;

  /// No description provided for @exportProject.
  ///
  /// In zh, this message translates to:
  /// **'导出项目'**
  String get exportProject;

  /// No description provided for @exportProjectTooltip.
  ///
  /// In zh, this message translates to:
  /// **'导出为 ZIP 压缩包'**
  String get exportProjectTooltip;

  /// No description provided for @exportingProject.
  ///
  /// In zh, this message translates to:
  /// **'正在压缩并导出项目...'**
  String get exportingProject;

  /// No description provided for @projectExported.
  ///
  /// In zh, this message translates to:
  /// **'项目导出成功'**
  String get projectExported;

  /// No description provided for @exportProjectFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出项目失败: {error}'**
  String exportProjectFailed(String error);

  /// No description provided for @selectExportDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择导出目标文件夹'**
  String get selectExportDirectory;

  /// No description provided for @targetFileAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'目标文件 \"{name}\" 已存在，是否覆盖？'**
  String targetFileAlreadyExists(String name);

  /// No description provided for @overwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get overwrite;

  /// No description provided for @batteryOptimizationTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台运行与电池优化'**
  String get batteryOptimizationTitle;

  /// No description provided for @batteryOptimizationMessage.
  ///
  /// In zh, this message translates to:
  /// **'为了保证终端会话在后台不被系统强行终止，建议将本应用的电池优化设置为“无限制”或关闭电池优化。\n\n是否前往系统设置进行配置？'**
  String get batteryOptimizationMessage;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @probeBannerPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备 {module} 探测环境…'**
  String probeBannerPreparing(String module);

  /// No description provided for @probeBannerDetecting.
  ///
  /// In zh, this message translates to:
  /// **'正在探测 {module} 任务…'**
  String probeBannerDetecting(String module);

  /// No description provided for @probeBannerFinalizing.
  ///
  /// In zh, this message translates to:
  /// **'正在整理探测结果…'**
  String get probeBannerFinalizing;

  /// No description provided for @probePhaseQueued.
  ///
  /// In zh, this message translates to:
  /// **'{module} 排队等待中…'**
  String probePhaseQueued(String module);

  /// No description provided for @probePhaseCheckingDependency.
  ///
  /// In zh, this message translates to:
  /// **'正在检查 {module} 依赖…'**
  String probePhaseCheckingDependency(String module);

  /// No description provided for @probePhaseInstallingDependency.
  ///
  /// In zh, this message translates to:
  /// **'正在安装 {module} 依赖…'**
  String probePhaseInstallingDependency(String module);

  /// No description provided for @probeDoneWithCount.
  ///
  /// In zh, this message translates to:
  /// **'{module} 探测完成 · 发现 {count} 个任务'**
  String probeDoneWithCount(String module, int count);

  /// No description provided for @probeFailureDependencyInstallFailed.
  ///
  /// In zh, this message translates to:
  /// **'依赖 {tool} 自动安装失败'**
  String probeFailureDependencyInstallFailed(String tool);

  /// No description provided for @taskTypeSingleFile.
  ///
  /// In zh, this message translates to:
  /// **'当前文件任务'**
  String get taskTypeSingleFile;

  /// No description provided for @taskTypeOther.
  ///
  /// In zh, this message translates to:
  /// **'其他任务'**
  String get taskTypeOther;

  /// No description provided for @probeAlreadyRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在探测中，请稍候…'**
  String get probeAlreadyRunning;

  /// No description provided for @probeBusyEnterTerminalTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务探测进行中'**
  String get probeBusyEnterTerminalTitle;

  /// No description provided for @probeBusyEnterTerminalMessage.
  ///
  /// In zh, this message translates to:
  /// **'项目任务探测正在后台进行（会占用当前容器执行构建工具自省与依赖安装）。\n\n此时进入终端并进行安装软件包、构建等操作，可能与探测互相阻塞或产生异常。\n\n是否仍要进入终端？'**
  String get probeBusyEnterTerminalMessage;

  /// No description provided for @probeEnterTerminalAnyway.
  ///
  /// In zh, this message translates to:
  /// **'继续进入终端'**
  String get probeEnterTerminalAnyway;

  /// No description provided for @probeCancelConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消本次探测？'**
  String get probeCancelConfirmTitle;

  /// No description provided for @probeCancelConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'正在进行的探测会被立即中止：已完成模块的结果会保留，未完成的模块将被跳过。'**
  String get probeCancelConfirmMessage;

  /// No description provided for @probeKeepDetecting.
  ///
  /// In zh, this message translates to:
  /// **'继续探测'**
  String get probeKeepDetecting;

  /// No description provided for @cancelProbe.
  ///
  /// In zh, this message translates to:
  /// **'取消探测'**
  String get cancelProbe;

  /// No description provided for @probeBudgetExceededTitle.
  ///
  /// In zh, this message translates to:
  /// **'探测超时已中止'**
  String get probeBudgetExceededTitle;

  /// No description provided for @probeBudgetExceededMessage.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {completed}/{total} 个模块，剩余模块本次跳过。可稍后重新探测。'**
  String probeBudgetExceededMessage(int completed, int total);

  /// No description provided for @probeBannerClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get probeBannerClose;

  /// No description provided for @probeDone.
  ///
  /// In zh, this message translates to:
  /// **'{module} 任务探测完成'**
  String probeDone(String module);

  /// No description provided for @probeFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'{module} 任务探测失败'**
  String probeFailedTitle(String module);

  /// No description provided for @probeFailureToolchainMissing.
  ///
  /// In zh, this message translates to:
  /// **'当前系统内未找到 {tool}，请先在系统管理中安装'**
  String probeFailureToolchainMissing(String tool);

  /// No description provided for @probeFailureExecutionFailed.
  ///
  /// In zh, this message translates to:
  /// **'构建工具执行失败：{detail}'**
  String probeFailureExecutionFailed(String detail);

  /// No description provided for @probeFailureUnparsable.
  ///
  /// In zh, this message translates to:
  /// **'无法识别构建工具输出（可能版本不兼容）'**
  String get probeFailureUnparsable;

  /// No description provided for @probeFailureTimeout.
  ///
  /// In zh, this message translates to:
  /// **'探测超时，已中止'**
  String get probeFailureTimeout;

  /// No description provided for @noticeQueueMore.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 项进行中'**
  String noticeQueueMore(int count);

  /// No description provided for @importFilesSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 个文件'**
  String importFilesSuccess(int count);

  /// No description provided for @importFilesFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入文件失败: {error}'**
  String importFilesFailed(String error);

  /// No description provided for @codeCompletionManagement.
  ///
  /// In zh, this message translates to:
  /// **'代码补全管理'**
  String get codeCompletionManagement;

  /// No description provided for @codeCompletionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理各编程语言的智能补全与报错工具链'**
  String get codeCompletionSubtitle;

  /// No description provided for @internalEngineTitle.
  ///
  /// In zh, this message translates to:
  /// **'内部代码智能引擎 (Alpine)'**
  String get internalEngineTitle;

  /// No description provided for @internalEngineStatusReady.
  ///
  /// In zh, this message translates to:
  /// **'引擎已就绪'**
  String get internalEngineStatusReady;

  /// No description provided for @internalEngineStatusNotReady.
  ///
  /// In zh, this message translates to:
  /// **'引擎未就绪'**
  String get internalEngineStatusNotReady;

  /// No description provided for @internalEngineExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在准备内置代码智能引擎...'**
  String get internalEngineExtracting;

  /// No description provided for @installComponent.
  ///
  /// In zh, this message translates to:
  /// **'安装组件'**
  String get installComponent;

  /// No description provided for @installingComponent.
  ///
  /// In zh, this message translates to:
  /// **'正在安装 {pkg}...'**
  String installingComponent(String pkg);

  /// No description provided for @installComponentSuccess.
  ///
  /// In zh, this message translates to:
  /// **'{name} 组件安装成功'**
  String installComponentSuccess(String name);

  /// No description provided for @installComponentFailed.
  ///
  /// In zh, this message translates to:
  /// **'组件安装失败: {error}'**
  String installComponentFailed(String error);

  /// No description provided for @editLanguageConfig.
  ///
  /// In zh, this message translates to:
  /// **'编辑语言配置'**
  String get editLanguageConfig;

  /// No description provided for @addLanguageConfig.
  ///
  /// In zh, this message translates to:
  /// **'新增语言配置'**
  String get addLanguageConfig;

  /// No description provided for @deleteLanguageConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除语言配置'**
  String get deleteLanguageConfirmTitle;

  /// No description provided for @deleteLanguageConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {name} 的代码补全配置吗？'**
  String deleteLanguageConfirmMessage(String name);

  /// No description provided for @resetDefaultLanguages.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认配置'**
  String get resetDefaultLanguages;

  /// No description provided for @resetDefaultLanguagesConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定将所有语言配置重置为官方默认预设吗？'**
  String get resetDefaultLanguagesConfirm;

  /// No description provided for @languageDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'语言名称'**
  String get languageDisplayName;

  /// No description provided for @languageDisplayNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: C / C++'**
  String get languageDisplayNameHint;

  /// No description provided for @languageIdField.
  ///
  /// In zh, this message translates to:
  /// **'语言标识 (Language ID)'**
  String get languageIdField;

  /// No description provided for @languageIdFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'用于 LSP 协议识别，如 cpp, rust'**
  String get languageIdFieldHint;

  /// No description provided for @fileExtensionsField.
  ///
  /// In zh, this message translates to:
  /// **'文件后缀'**
  String get fileExtensionsField;

  /// No description provided for @fileExtensionsFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'以逗号分隔，如 .c, .cpp, .h'**
  String get fileExtensionsFieldHint;

  /// No description provided for @serverCommandField.
  ///
  /// In zh, this message translates to:
  /// **'服务启动命令'**
  String get serverCommandField;

  /// No description provided for @serverCommandFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: clangd'**
  String get serverCommandFieldHint;

  /// No description provided for @serverArgsField.
  ///
  /// In zh, this message translates to:
  /// **'启动参数'**
  String get serverArgsField;

  /// No description provided for @serverArgsFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'多个参数以空格或逗号分隔'**
  String get serverArgsFieldHint;

  /// No description provided for @apkPackageField.
  ///
  /// In zh, this message translates to:
  /// **'Alpine 依赖包名'**
  String get apkPackageField;

  /// No description provided for @apkPackageFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'用于一键安装，如 clang-extra-tools'**
  String get apkPackageFieldHint;

  /// No description provided for @lspPackageMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'未安装 {language} 代码智能组件'**
  String lspPackageMissingTitle(String language);

  /// No description provided for @lspPackageMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'安装 {pkg} ({command}) 即可获得精准代码补全与错误检查'**
  String lspPackageMissingMessage(String pkg, String command);

  /// No description provided for @installNow.
  ///
  /// In zh, this message translates to:
  /// **'一键安装'**
  String get installNow;

  /// No description provided for @fieldRequired.
  ///
  /// In zh, this message translates to:
  /// **'此项不能为空'**
  String get fieldRequired;

  /// No description provided for @languageConfigSaved.
  ///
  /// In zh, this message translates to:
  /// **'语言配置已保存'**
  String get languageConfigSaved;
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
