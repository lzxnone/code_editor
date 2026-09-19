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

  /// No description provided for @detectedTaskSingleJavaDesc.
  ///
  /// In zh, this message translates to:
  /// **'直接运行当前 Java 源文件'**
  String get detectedTaskSingleJavaDesc;

  /// No description provided for @detectedTaskSingleTsDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 TypeScript 脚本'**
  String get detectedTaskSingleTsDesc;

  /// No description provided for @detectedTaskSingleLuaDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Lua 脚本'**
  String get detectedTaskSingleLuaDesc;

  /// No description provided for @detectedTaskSinglePerlDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 Perl 脚本'**
  String get detectedTaskSinglePerlDesc;

  /// No description provided for @detectedTaskSinglePhpDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行当前 PHP 脚本'**
  String get detectedTaskSinglePhpDesc;

  /// No description provided for @detectedTaskPythonPipInstallDesc.
  ///
  /// In zh, this message translates to:
  /// **'安装项目 requirements 依赖包'**
  String get detectedTaskPythonPipInstallDesc;

  /// No description provided for @detectedTaskPythonRunMainDesc.
  ///
  /// In zh, this message translates to:
  /// **'执行 Python 项目主程序'**
  String get detectedTaskPythonRunMainDesc;

  /// No description provided for @detectedTaskPythonPytestDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行 pytest 测试用例'**
  String get detectedTaskPythonPytestDesc;

  /// No description provided for @detectedTaskMavenPackageDesc.
  ///
  /// In zh, this message translates to:
  /// **'打包 Maven 项目 (mvn package)'**
  String get detectedTaskMavenPackageDesc;

  /// No description provided for @detectedTaskMavenCompileDesc.
  ///
  /// In zh, this message translates to:
  /// **'编译 Maven 项目源码 (mvn compile)'**
  String get detectedTaskMavenCompileDesc;

  /// No description provided for @detectedTaskMavenTestDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行 Maven 单元测试 (mvn test)'**
  String get detectedTaskMavenTestDesc;

  /// No description provided for @detectedTaskMavenCleanDesc.
  ///
  /// In zh, this message translates to:
  /// **'清理 Maven 目标输出目录 (mvn clean)'**
  String get detectedTaskMavenCleanDesc;

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

  /// No description provided for @completionSourceSection.
  ///
  /// In zh, this message translates to:
  /// **'补全数据源与开关'**
  String get completionSourceSection;

  /// No description provided for @localCompletionTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地基础补全'**
  String get localCompletionTitle;

  /// No description provided for @localCompletionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'包含语言内置关键字与当前文档词法启发式提取'**
  String get localCompletionSubtitle;

  /// No description provided for @lspCompletionTitle.
  ///
  /// In zh, this message translates to:
  /// **'后端语言服务补全'**
  String get lspCompletionTitle;

  /// No description provided for @lspCompletionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'向后台编译器守护进程请求真实语义类型与函数参数补全'**
  String get lspCompletionSubtitle;

  /// No description provided for @internalEngineTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码运行与智能补全引擎 (Ubuntu)'**
  String get internalEngineTitle;

  /// No description provided for @internalEngineStatusReady.
  ///
  /// In zh, this message translates to:
  /// **'引擎已就绪'**
  String get internalEngineStatusReady;

  /// No description provided for @internalEngineStatusNotReady.
  ///
  /// In zh, this message translates to:
  /// **'引擎未启动'**
  String get internalEngineStatusNotReady;

  /// No description provided for @internalEngineExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在准备内置 Ubuntu 开发环境与智能补全引擎...'**
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

  /// No description provided for @uninstallingComponent.
  ///
  /// In zh, this message translates to:
  /// **'正在卸载 {pkg} 并清理配置...'**
  String uninstallingComponent(String pkg);

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

  /// No description provided for @deleteLanguageWithPackageConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {name} 的代码补全配置吗？已安装的软件包将一并卸载。'**
  String deleteLanguageWithPackageConfirmMessage(String name);

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
  /// **'Ubuntu 依赖包名 (APT)'**
  String get apkPackageField;

  /// No description provided for @apkPackageFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'用于一键安装，如 clangd 或 python3-pylsp'**
  String get apkPackageFieldHint;

  /// No description provided for @lspPackageMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'未安装 {language} 代码智能组件'**
  String lspPackageMissingTitle(String language);

  /// No description provided for @lspPackageMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'安装组件即可获得精准代码补全与错误检查'**
  String get lspPackageMissingMessage;

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

  /// No description provided for @enable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get disable;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @componentQueued.
  ///
  /// In zh, this message translates to:
  /// **'{name} 排队等待中…'**
  String componentQueued(String name);

  /// No description provided for @uninstallComponentSuccess.
  ///
  /// In zh, this message translates to:
  /// **'{name} 组件卸载成功'**
  String uninstallComponentSuccess(String name);

  /// No description provided for @uninstallComponentFailed.
  ///
  /// In zh, this message translates to:
  /// **'组件卸载失败: {error}'**
  String uninstallComponentFailed(String error);

  /// No description provided for @installingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在安装…'**
  String get installingStatus;

  /// No description provided for @uninstallingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在卸载…'**
  String get uninstallingStatus;

  /// No description provided for @emptyLspLanguagesTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无已安装的代码智能组件'**
  String get emptyLspLanguagesTitle;

  /// No description provided for @emptyLspLanguagesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在编辑器中打开代码文件即可按需触发安装，或点击右上角 \"+\" 手动添加'**
  String get emptyLspLanguagesSubtitle;

  /// No description provided for @lspQuickFixTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码问题与修复 (第 {line} 行)'**
  String lspQuickFixTitle(int line);

  /// No description provided for @lspNoFixAvailable.
  ///
  /// In zh, this message translates to:
  /// **'当前报错未提供自动修复动作'**
  String get lspNoFixAvailable;

  /// No description provided for @diagnosticLinePrefix.
  ///
  /// In zh, this message translates to:
  /// **'行 {line}: {message}'**
  String diagnosticLinePrefix(int line, String message);

  /// No description provided for @quickFixButton.
  ///
  /// In zh, this message translates to:
  /// **'修复'**
  String get quickFixButton;

  /// No description provided for @containerSection.
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get containerSection;

  /// No description provided for @destroyAndRebuildContainer.
  ///
  /// In zh, this message translates to:
  /// **'销毁并重建容器'**
  String get destroyAndRebuildContainer;

  /// No description provided for @destroyAndRebuildContainerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'清空容器内已安装环境并重新解压纯净容器'**
  String get destroyAndRebuildContainerSubtitle;

  /// No description provided for @destroyContainerConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'销毁并重建容器'**
  String get destroyContainerConfirmTitle;

  /// No description provided for @destroyContainerConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'此操作将永久清空当前 Ubuntu 容器内的所有已安装软件包和环境配置（工程文件不受影响），并重新解压纯净容器系统。确定要继续吗？'**
  String get destroyContainerConfirmMessage;

  /// No description provided for @destroyContainerButton.
  ///
  /// In zh, this message translates to:
  /// **'销毁并重建'**
  String get destroyContainerButton;

  /// No description provided for @containerRebuiltSuccess.
  ///
  /// In zh, this message translates to:
  /// **'容器已成功重建'**
  String get containerRebuiltSuccess;

  /// No description provided for @containerRebuildFailed.
  ///
  /// In zh, this message translates to:
  /// **'容器重建失败: {error}'**
  String containerRebuildFailed(String error);

  /// No description provided for @containerRuntimeMode.
  ///
  /// In zh, this message translates to:
  /// **'容器运行模式'**
  String get containerRuntimeMode;

  /// No description provided for @containerRuntimeModeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get containerRuntimeModeAuto;

  /// No description provided for @containerRuntimeModeProot.
  ///
  /// In zh, this message translates to:
  /// **'PRoot'**
  String get containerRuntimeModeProot;

  /// No description provided for @containerRuntimeModeChroot.
  ///
  /// In zh, this message translates to:
  /// **'Chroot'**
  String get containerRuntimeModeChroot;

  /// No description provided for @selectContainerRuntimeMode.
  ///
  /// In zh, this message translates to:
  /// **'选择容器运行模式'**
  String get selectContainerRuntimeMode;

  /// No description provided for @containerRuntimeToast.
  ///
  /// In zh, this message translates to:
  /// **'当前容器运行环境：{mode}'**
  String containerRuntimeToast(String mode);

  /// No description provided for @chrootDisabledNoRoot.
  ///
  /// In zh, this message translates to:
  /// **'未授予 Root 权限不可用'**
  String get chrootDisabledNoRoot;

  /// No description provided for @chrootFailedFallbackToProot.
  ///
  /// In zh, this message translates to:
  /// **'Chroot 挂载或权限失败，已自动降级为 PRoot 运行模式'**
  String get chrootFailedFallbackToProot;

  /// No description provided for @drawerTabExplorer.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get drawerTabExplorer;

  /// No description provided for @drawerTabSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get drawerTabSearch;

  /// No description provided for @drawerTabGit.
  ///
  /// In zh, this message translates to:
  /// **'源代码管理'**
  String get drawerTabGit;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchHint;

  /// No description provided for @replaceHint.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replaceHint;

  /// No description provided for @matchCase.
  ///
  /// In zh, this message translates to:
  /// **'区分大小写'**
  String get matchCase;

  /// No description provided for @matchWholeWord.
  ///
  /// In zh, this message translates to:
  /// **'全字匹配'**
  String get matchWholeWord;

  /// No description provided for @useRegularExpression.
  ///
  /// In zh, this message translates to:
  /// **'使用正则表达式'**
  String get useRegularExpression;

  /// No description provided for @invalidRegularExpression.
  ///
  /// In zh, this message translates to:
  /// **'无效的正则表达式'**
  String get invalidRegularExpression;

  /// No description provided for @projectDirectoryNotFound.
  ///
  /// In zh, this message translates to:
  /// **'项目目录不存在'**
  String get projectDirectoryNotFound;

  /// No description provided for @searchMoreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多选项'**
  String get searchMoreOptions;

  /// No description provided for @searchModeText.
  ///
  /// In zh, this message translates to:
  /// **'内容搜索'**
  String get searchModeText;

  /// No description provided for @searchModeFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名搜索'**
  String get searchModeFileName;

  /// No description provided for @replaceAllInFile.
  ///
  /// In zh, this message translates to:
  /// **'替换此文件中的所有匹配项'**
  String get replaceAllInFile;

  /// No description provided for @replaceAllInProject.
  ///
  /// In zh, this message translates to:
  /// **'全部替换'**
  String get replaceAllInProject;

  /// No description provided for @replaceSingleMatch.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replaceSingleMatch;

  /// No description provided for @searchResultStats.
  ///
  /// In zh, this message translates to:
  /// **'在 {fileCount} 个文件中找到 {matchCount} 处匹配'**
  String searchResultStats(int fileCount, int matchCount);

  /// No description provided for @noSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配项'**
  String get noSearchResults;

  /// No description provided for @searchError.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchError(String error);

  /// No description provided for @replaceSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已替换 {count} 处匹配'**
  String replaceSuccess(int count);

  /// No description provided for @expandAll.
  ///
  /// In zh, this message translates to:
  /// **'全部展开'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In zh, this message translates to:
  /// **'全部折叠'**
  String get collapseAll;

  /// No description provided for @searchLoadMoreFiles.
  ///
  /// In zh, this message translates to:
  /// **'加载更多文件 (还有 {count} 个)'**
  String searchLoadMoreFiles(int count);

  /// No description provided for @searchLoadMoreMatches.
  ///
  /// In zh, this message translates to:
  /// **'加载更多匹配项 (还有 {count} 项)'**
  String searchLoadMoreMatches(int count);

  /// No description provided for @confirmReplaceAllTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部替换确认'**
  String get confirmReplaceAllTitle;

  /// No description provided for @confirmReplaceAllMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要在整个项目（共 {fileCount} 个文件）中将全部 {matchCount} 处匹配替换为 \"{replaceText}\" 吗？此操作将直接修改磁盘文件。'**
  String confirmReplaceAllMessage(
    int matchCount,
    int fileCount,
    String replaceText,
  );

  /// No description provided for @confirmReplaceFileTitle.
  ///
  /// In zh, this message translates to:
  /// **'替换文件匹配项确认'**
  String get confirmReplaceFileTitle;

  /// No description provided for @confirmReplaceFileMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要在 \"{fileName}\" 中将全部 {matchCount} 处匹配替换为 \"{replaceText}\" 吗？'**
  String confirmReplaceFileMessage(
    String fileName,
    int matchCount,
    String replaceText,
  );

  /// No description provided for @gitNotInstalled.
  ///
  /// In zh, this message translates to:
  /// **'未检测到 Git'**
  String get gitNotInstalled;

  /// No description provided for @gitNotInstalledDesc.
  ///
  /// In zh, this message translates to:
  /// **'系统中未检测到 Git 命令行工具。请在系统终端或 Linux 容器中安装 git（如执行 apt update && apt install -y git）。'**
  String get gitNotInstalledDesc;

  /// No description provided for @gitNeedInstall.
  ///
  /// In zh, this message translates to:
  /// **'需要安装 Git'**
  String get gitNeedInstall;

  /// No description provided for @gitInstallAction.
  ///
  /// In zh, this message translates to:
  /// **'安装 Git'**
  String get gitInstallAction;

  /// No description provided for @gitInstallingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在安装 Git...'**
  String get gitInstallingProgress;

  /// No description provided for @gitInstallSuccess.
  ///
  /// In zh, this message translates to:
  /// **'Git 安装成功'**
  String get gitInstallSuccess;

  /// No description provided for @gitInstallFailed.
  ///
  /// In zh, this message translates to:
  /// **'Git 安装失败: {error}'**
  String gitInstallFailed(String error);

  /// No description provided for @gitNoRepoFound.
  ///
  /// In zh, this message translates to:
  /// **'当前工程尚未初始化为 Git 仓库'**
  String get gitNoRepoFound;

  /// No description provided for @gitNoRepoDesc.
  ///
  /// In zh, this message translates to:
  /// **'初始化本地 Git 仓库后，即可使用版本控制、分支管理及变更追踪功能。'**
  String get gitNoRepoDesc;

  /// No description provided for @gitInitRepo.
  ///
  /// In zh, this message translates to:
  /// **'初始化 Git 仓库'**
  String get gitInitRepo;

  /// No description provided for @gitInitializing.
  ///
  /// In zh, this message translates to:
  /// **'正在初始化 Git 仓库...'**
  String get gitInitializing;

  /// No description provided for @gitInitSuccess.
  ///
  /// In zh, this message translates to:
  /// **'Git 仓库初始化成功'**
  String get gitInitSuccess;

  /// No description provided for @gitInitFailed.
  ///
  /// In zh, this message translates to:
  /// **'Git 仓库初始化失败: {error}'**
  String gitInitFailed(String error);

  /// No description provided for @gitRepository.
  ///
  /// In zh, this message translates to:
  /// **'仓库'**
  String get gitRepository;

  /// No description provided for @gitCurrentBranch.
  ///
  /// In zh, this message translates to:
  /// **'当前分支: {branch}'**
  String gitCurrentBranch(String branch);

  /// No description provided for @gitSwitchRepo.
  ///
  /// In zh, this message translates to:
  /// **'切换仓库'**
  String get gitSwitchRepo;

  /// No description provided for @gitRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新 Git 状态'**
  String get gitRefresh;

  /// No description provided for @gitChanges.
  ///
  /// In zh, this message translates to:
  /// **'更改'**
  String get gitChanges;

  /// No description provided for @gitStagedChanges.
  ///
  /// In zh, this message translates to:
  /// **'暂存的更改'**
  String get gitStagedChanges;

  /// No description provided for @gitNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'暂无任何文件更改'**
  String get gitNoChanges;

  /// No description provided for @gitStatusUntracked.
  ///
  /// In zh, this message translates to:
  /// **'未跟踪'**
  String get gitStatusUntracked;

  /// No description provided for @gitStatusModified.
  ///
  /// In zh, this message translates to:
  /// **'已修改'**
  String get gitStatusModified;

  /// No description provided for @gitStatusAdded.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get gitStatusAdded;

  /// No description provided for @gitStatusDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get gitStatusDeleted;

  /// No description provided for @gitStatusRenamed.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get gitStatusRenamed;

  /// No description provided for @gitStatusConflict.
  ///
  /// In zh, this message translates to:
  /// **'冲突'**
  String get gitStatusConflict;

  /// No description provided for @gitMultipleReposDetected.
  ///
  /// In zh, this message translates to:
  /// **'检测到多个 Git 仓库 ({count})'**
  String gitMultipleReposDetected(int count);

  /// No description provided for @gitStageChange.
  ///
  /// In zh, this message translates to:
  /// **'暂存更改'**
  String get gitStageChange;

  /// No description provided for @gitUnstageChange.
  ///
  /// In zh, this message translates to:
  /// **'取消暂存更改'**
  String get gitUnstageChange;

  /// No description provided for @gitStageAll.
  ///
  /// In zh, this message translates to:
  /// **'全部暂存更改'**
  String get gitStageAll;

  /// No description provided for @gitUnstageAll.
  ///
  /// In zh, this message translates to:
  /// **'全部取消暂存更改'**
  String get gitUnstageAll;

  /// No description provided for @gitStageSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已暂存'**
  String get gitStageSuccess;

  /// No description provided for @gitUnstageSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已取消暂存'**
  String get gitUnstageSuccess;

  /// No description provided for @gitCommit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get gitCommit;

  /// No description provided for @gitCommitMessageHint.
  ///
  /// In zh, this message translates to:
  /// **'提交信息'**
  String get gitCommitMessageHint;

  /// No description provided for @gitCommitSuccess.
  ///
  /// In zh, this message translates to:
  /// **'提交成功'**
  String get gitCommitSuccess;

  /// No description provided for @gitCommitFailed.
  ///
  /// In zh, this message translates to:
  /// **'提交失败: {error}'**
  String gitCommitFailed(String error);

  /// No description provided for @gitDiscardChange.
  ///
  /// In zh, this message translates to:
  /// **'放弃更改'**
  String get gitDiscardChange;

  /// No description provided for @gitDiscardConfirm.
  ///
  /// In zh, this message translates to:
  /// **'放弃更改？'**
  String get gitDiscardConfirm;

  /// No description provided for @gitDiscardConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定要放弃对 \"{fileName}\" 的所有未暂存更改吗？此操作无法撤销。'**
  String gitDiscardConfirmDesc(String fileName);

  /// No description provided for @gitNoCommitMessage.
  ///
  /// In zh, this message translates to:
  /// **'请输入提交信息'**
  String get gitNoCommitMessage;

  /// No description provided for @gitNoStagedChangesToCommit.
  ///
  /// In zh, this message translates to:
  /// **'暂存区没有已暂存的更改，是否全部暂存并直接提交？'**
  String get gitNoStagedChangesToCommit;

  /// No description provided for @gitStageAllAndCommit.
  ///
  /// In zh, this message translates to:
  /// **'全部暂存并提交'**
  String get gitStageAllAndCommit;

  /// No description provided for @gitGraphTitle.
  ///
  /// In zh, this message translates to:
  /// **'图表'**
  String get gitGraphTitle;

  /// No description provided for @gitNoCommits.
  ///
  /// In zh, this message translates to:
  /// **'暂无提交历史'**
  String get gitNoCommits;

  /// No description provided for @gitCommitDetails.
  ///
  /// In zh, this message translates to:
  /// **'提交详情'**
  String get gitCommitDetails;

  /// No description provided for @gitCommitAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get gitCommitAuthor;

  /// No description provided for @gitCommitDate.
  ///
  /// In zh, this message translates to:
  /// **'提交日期'**
  String get gitCommitDate;

  /// No description provided for @gitCommitHash.
  ///
  /// In zh, this message translates to:
  /// **'提交哈希'**
  String get gitCommitHash;

  /// No description provided for @gitCopyHash.
  ///
  /// In zh, this message translates to:
  /// **'复制哈希'**
  String get gitCopyHash;

  /// No description provided for @gitHashCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制提交哈希到剪贴板'**
  String get gitHashCopied;

  /// No description provided for @gitCommitParent.
  ///
  /// In zh, this message translates to:
  /// **'父提交'**
  String get gitCommitParent;

  /// No description provided for @gitDiscardAll.
  ///
  /// In zh, this message translates to:
  /// **'全部放弃更改'**
  String get gitDiscardAll;

  /// No description provided for @gitDiscardAllChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃所有未暂存更改？'**
  String get gitDiscardAllChangesTitle;

  /// No description provided for @gitDiscardAllChangesConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要放弃所有未暂存更改吗？所有已修改的文件将恢复，未跟踪的新文件将被清除，此操作无法撤销。'**
  String get gitDiscardAllChangesConfirm;

  /// No description provided for @gitDiscardAllStagedTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃所有已暂存更改？'**
  String get gitDiscardAllStagedTitle;

  /// No description provided for @gitDiscardAllStagedConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要放弃所有已暂存的更改吗？所选文件的修改将被彻底恢复，此操作无法撤销。'**
  String get gitDiscardAllStagedConfirm;

  /// No description provided for @gitBranches.
  ///
  /// In zh, this message translates to:
  /// **'分支'**
  String get gitBranches;

  /// No description provided for @gitCreateBranch.
  ///
  /// In zh, this message translates to:
  /// **'创建新分支'**
  String get gitCreateBranch;

  /// No description provided for @gitBranchNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新分支名称'**
  String get gitBranchNameHint;

  /// No description provided for @gitSwitchBranchSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已切换至分支 {branch}'**
  String gitSwitchBranchSuccess(String branch);

  /// No description provided for @gitCreateBranchSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已创建并切换至新分支 {branch}'**
  String gitCreateBranchSuccess(String branch);

  /// No description provided for @gitDeleteBranch.
  ///
  /// In zh, this message translates to:
  /// **'删除分支'**
  String get gitDeleteBranch;

  /// No description provided for @gitDeleteBranchConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本地分支 {branch} 吗？'**
  String gitDeleteBranchConfirm(String branch);

  /// No description provided for @gitDeleteBranchSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已删除分支 {branch}'**
  String gitDeleteBranchSuccess(String branch);

  /// No description provided for @gitCannotDeleteCurrentBranch.
  ///
  /// In zh, this message translates to:
  /// **'无法删除当前所在分支'**
  String get gitCannotDeleteCurrentBranch;

  /// No description provided for @gitUndoLastCommit.
  ///
  /// In zh, this message translates to:
  /// **'撤销上次提交'**
  String get gitUndoLastCommit;

  /// No description provided for @gitUndoLastCommitConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要撤销上一次提交吗？代码更改将保留在暂存区。'**
  String get gitUndoLastCommitConfirm;

  /// No description provided for @gitUndoLastCommitSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已撤销上一次提交'**
  String get gitUndoLastCommitSuccess;

  /// No description provided for @gitStash.
  ///
  /// In zh, this message translates to:
  /// **'贮藏'**
  String get gitStash;

  /// No description provided for @gitStashChanges.
  ///
  /// In zh, this message translates to:
  /// **'贮藏当前更改'**
  String get gitStashChanges;

  /// No description provided for @gitStashChangesSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已将当前更改暂存至贮藏栈'**
  String get gitStashChangesSuccess;

  /// No description provided for @gitStashPop.
  ///
  /// In zh, this message translates to:
  /// **'恢复最近贮藏 (Pop)'**
  String get gitStashPop;

  /// No description provided for @gitStashPopSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已恢复最近的贮藏更改'**
  String get gitStashPopSuccess;

  /// No description provided for @gitNoStashFound.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可恢复的贮藏记录'**
  String get gitNoStashFound;

  /// No description provided for @gitAddToGitignore.
  ///
  /// In zh, this message translates to:
  /// **'添加到 .gitignore'**
  String get gitAddToGitignore;

  /// No description provided for @gitAddedToGitignore.
  ///
  /// In zh, this message translates to:
  /// **'已添加至 .gitignore'**
  String get gitAddedToGitignore;

  /// No description provided for @gitMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get gitMoreActions;

  /// No description provided for @gitOpenFile.
  ///
  /// In zh, this message translates to:
  /// **'打开文件'**
  String get gitOpenFile;

  /// No description provided for @gitTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get gitTags;

  /// No description provided for @gitCreateTag.
  ///
  /// In zh, this message translates to:
  /// **'创建新标签'**
  String get gitCreateTag;

  /// No description provided for @gitTagNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入标签名称 (例如 v1.0.0)'**
  String get gitTagNameHint;

  /// No description provided for @gitTagMessageHint.
  ///
  /// In zh, this message translates to:
  /// **'标签附注信息 (可选)'**
  String get gitTagMessageHint;

  /// No description provided for @gitDeleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get gitDeleteTag;

  /// No description provided for @gitDeleteTagConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本地标签 {tag} 吗？'**
  String gitDeleteTagConfirm(String tag);

  /// No description provided for @gitCreateTagSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已创建标签 {tag}'**
  String gitCreateTagSuccess(String tag);

  /// No description provided for @gitDeleteTagSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已删除标签 {tag}'**
  String gitDeleteTagSuccess(String tag);

  /// No description provided for @gitSwitchTagSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已检出至标签 {tag}'**
  String gitSwitchTagSuccess(String tag);

  /// No description provided for @gitNoTags.
  ///
  /// In zh, this message translates to:
  /// **'暂无标签'**
  String get gitNoTags;

  /// No description provided for @gitSelectBranchToDelete.
  ///
  /// In zh, this message translates to:
  /// **'选择要删除的分支'**
  String get gitSelectBranchToDelete;

  /// No description provided for @gitSelectTagToDelete.
  ///
  /// In zh, this message translates to:
  /// **'选择要删除的标签'**
  String get gitSelectTagToDelete;

  /// No description provided for @gitSearchBranches.
  ///
  /// In zh, this message translates to:
  /// **'搜索分支...'**
  String get gitSearchBranches;

  /// No description provided for @gitSearchTags.
  ///
  /// In zh, this message translates to:
  /// **'搜索标签...'**
  String get gitSearchTags;

  /// No description provided for @gitNoBranches.
  ///
  /// In zh, this message translates to:
  /// **'暂无分支'**
  String get gitNoBranches;

  /// No description provided for @gitRemoteBranches.
  ///
  /// In zh, this message translates to:
  /// **'远端分支'**
  String get gitRemoteBranches;

  /// No description provided for @gitLocalBranches.
  ///
  /// In zh, this message translates to:
  /// **'本地分支'**
  String get gitLocalBranches;

  /// No description provided for @gitNoRemoteBranches.
  ///
  /// In zh, this message translates to:
  /// **'暂无远端分支，请先执行抓取'**
  String get gitNoRemoteBranches;

  /// No description provided for @gitCheckoutRemoteBranch.
  ///
  /// In zh, this message translates to:
  /// **'检出为本地分支'**
  String get gitCheckoutRemoteBranch;

  /// No description provided for @gitRemoteBranchCheckedOut.
  ///
  /// In zh, this message translates to:
  /// **'该远端分支已在本地检出'**
  String get gitRemoteBranchCheckedOut;

  /// No description provided for @gitCheckoutRemoteBranchSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已基于 {remote} 创建并切换到本地分支 {branch}'**
  String gitCheckoutRemoteBranchSuccess(String remote, String branch);

  /// No description provided for @gitSearchRemoteBranches.
  ///
  /// In zh, this message translates to:
  /// **'搜索远端分支...'**
  String get gitSearchRemoteBranches;

  /// No description provided for @gitRepairCheck.
  ///
  /// In zh, this message translates to:
  /// **'仓库自检'**
  String get gitRepairCheck;

  /// No description provided for @gitRepairCheckRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在自检...'**
  String get gitRepairCheckRunning;

  /// No description provided for @gitRepairCheckHealthy.
  ///
  /// In zh, this message translates to:
  /// **'仓库完整，未发现对象丢失'**
  String get gitRepairCheckHealthy;

  /// No description provided for @gitRepairCheckHealthyHint.
  ///
  /// In zh, this message translates to:
  /// **'对象库校验通过，可以正常提交与同步。'**
  String get gitRepairCheckHealthyHint;

  /// No description provided for @gitRepairCheckObjectLoss.
  ///
  /// In zh, this message translates to:
  /// **'检测到对象丢失（{count} 处问题）'**
  String gitRepairCheckObjectLoss(int count);

  /// No description provided for @gitRepairCheckObjectLossHint.
  ///
  /// In zh, this message translates to:
  /// **'这类损坏会导致提交时报错 Error building trees。常见原因是容器被重建导致 .git/objects 丢失。建议先备份项目目录，再按下方提示处理。'**
  String get gitRepairCheckObjectLossHint;

  /// No description provided for @gitRepairCheckDangling.
  ///
  /// In zh, this message translates to:
  /// **'另有 {count} 个悬空对象（正常现象，无需处理）'**
  String gitRepairCheckDangling(int count);

  /// No description provided for @gitRepairCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'自检未能完成'**
  String get gitRepairCheckFailed;

  /// No description provided for @gitRepairCheckFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'可能因为仓库过大或执行超时，可稍后重试。'**
  String get gitRepairCheckFailedHint;

  /// No description provided for @gitRepairCheckRerun.
  ///
  /// In zh, this message translates to:
  /// **'重新自检'**
  String get gitRepairCheckRerun;

  /// No description provided for @gitRepairAdviceTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何处理'**
  String get gitRepairAdviceTitle;

  /// No description provided for @gitRepairAdviceRemoveStale.
  ///
  /// In zh, this message translates to:
  /// **'未提交的损坏条目：执行 git reset 让索引与最后一次提交对齐，然后重新暂存需要的文件。'**
  String get gitRepairAdviceRemoveStale;

  /// No description provided for @gitRepairAdviceRestore.
  ///
  /// In zh, this message translates to:
  /// **'已提交的历史损坏：需要从远端重新克隆，或从其他副本恢复。'**
  String get gitRepairAdviceRestore;

  /// No description provided for @gitClone.
  ///
  /// In zh, this message translates to:
  /// **'克隆远程仓库'**
  String get gitClone;

  /// No description provided for @gitCloneUrl.
  ///
  /// In zh, this message translates to:
  /// **'仓库地址'**
  String get gitCloneUrl;

  /// No description provided for @gitCloneUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://github.com/user/repo.git'**
  String get gitCloneUrlHint;

  /// No description provided for @gitCloneDirName.
  ///
  /// In zh, this message translates to:
  /// **'本地目录名'**
  String get gitCloneDirName;

  /// No description provided for @gitCloneDirNameHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则从地址自动推导'**
  String get gitCloneDirNameHint;

  /// No description provided for @gitCloneBranch.
  ///
  /// In zh, this message translates to:
  /// **'指定分支（可选）'**
  String get gitCloneBranch;

  /// No description provided for @gitCloneBranchHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用远端默认分支'**
  String get gitCloneBranchHint;

  /// No description provided for @gitCloneDepth.
  ///
  /// In zh, this message translates to:
  /// **'浅克隆深度（可选）'**
  String get gitCloneDepth;

  /// No description provided for @gitCloneDepthHint.
  ///
  /// In zh, this message translates to:
  /// **'如 1 表示只克隆最近 1 个提交'**
  String get gitCloneDepthHint;

  /// No description provided for @gitCloneUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入仓库地址'**
  String get gitCloneUrlRequired;

  /// No description provided for @gitCloneDirRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入本地目录名'**
  String get gitCloneDirRequired;

  /// No description provided for @gitCloneDirExists.
  ///
  /// In zh, this message translates to:
  /// **'目录已存在，请换一个名字'**
  String get gitCloneDirExists;

  /// No description provided for @gitCloneRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在克隆...'**
  String get gitCloneRunning;

  /// No description provided for @gitCloneSuccess.
  ///
  /// In zh, this message translates to:
  /// **'克隆完成：{name}'**
  String gitCloneSuccess(String name);

  /// No description provided for @gitCloneFailed.
  ///
  /// In zh, this message translates to:
  /// **'克隆失败'**
  String get gitCloneFailed;

  /// No description provided for @gitCloneCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消克隆'**
  String get gitCloneCancel;

  /// No description provided for @gitPushTargetTooltip.
  ///
  /// In zh, this message translates to:
  /// **'推送目标：{name}\n{reason}'**
  String gitPushTargetTooltip(String name, String reason);

  /// No description provided for @gitPushReasonPushRemote.
  ///
  /// In zh, this message translates to:
  /// **'由分支配置 branch.*.pushRemote 决定'**
  String get gitPushReasonPushRemote;

  /// No description provided for @gitPushReasonPushDefault.
  ///
  /// In zh, this message translates to:
  /// **'由仓库配置 remote.pushDefault 决定'**
  String get gitPushReasonPushDefault;

  /// No description provided for @gitPushReasonUpstream.
  ///
  /// In zh, this message translates to:
  /// **'当前分支的上游远程'**
  String get gitPushReasonUpstream;

  /// No description provided for @gitPushReasonBranchRemote.
  ///
  /// In zh, this message translates to:
  /// **'由分支配置 branch.*.remote 决定'**
  String get gitPushReasonBranchRemote;

  /// No description provided for @gitPushReasonFallback.
  ///
  /// In zh, this message translates to:
  /// **'默认远程（origin 优先）'**
  String get gitPushReasonFallback;

  /// No description provided for @gitPushReasonOverridden.
  ///
  /// In zh, this message translates to:
  /// **'你已在本次会话中手动切换'**
  String get gitPushReasonOverridden;

  /// No description provided for @gitFetchTargetTooltip.
  ///
  /// In zh, this message translates to:
  /// **'抓取目标：{name}'**
  String gitFetchTargetTooltip(String name);

  /// No description provided for @gitTogglePushTarget.
  ///
  /// In zh, this message translates to:
  /// **'选择推送目标'**
  String get gitTogglePushTarget;

  /// No description provided for @gitSyncCloudTooltip.
  ///
  /// In zh, this message translates to:
  /// **'同步：抓取 / 拉取 / 推送'**
  String get gitSyncCloudTooltip;

  /// No description provided for @gitPushTargetChanged.
  ///
  /// In zh, this message translates to:
  /// **'推送目标已切换为 {name}'**
  String gitPushTargetChanged(String name);

  /// No description provided for @gitPushTargetDiffers.
  ///
  /// In zh, this message translates to:
  /// **'推送目标与上游不同'**
  String get gitPushTargetDiffers;

  /// No description provided for @gitPushTargetDiffersNotice.
  ///
  /// In zh, this message translates to:
  /// **'拉取走 {upstream}，推送走 {push}'**
  String gitPushTargetDiffersNotice(String upstream, String push);

  /// No description provided for @gitRemoteRoleUpstream.
  ///
  /// In zh, this message translates to:
  /// **'上游（拉取）'**
  String get gitRemoteRoleUpstream;

  /// No description provided for @gitErrAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'认证失败：令牌无效、已过期或用户名不匹配'**
  String get gitErrAuthFailed;

  /// No description provided for @gitErrAuthFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'请到「Git 账号管理」检查令牌是否有效，并确认账号用户名与平台登录名一致。'**
  String get gitErrAuthFailedHint;

  /// No description provided for @gitErrWritePermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'当前账号对该仓库没有写权限'**
  String get gitErrWritePermissionDenied;

  /// No description provided for @gitErrWritePermissionDeniedHint.
  ///
  /// In zh, this message translates to:
  /// **'若这是别人的仓库（上游），请先 Fork 到你自己的账号，再把远端地址改为你的 Fork（如 https://github.com/你的用户名/仓库.git）。'**
  String get gitErrWritePermissionDeniedHint;

  /// No description provided for @gitErrRepositoryNotFound.
  ///
  /// In zh, this message translates to:
  /// **'仓库不存在，或当前账号无权访问'**
  String get gitErrRepositoryNotFound;

  /// No description provided for @gitErrRepositoryNotFoundHint.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 对「无权限」和「不存在」都返回 404。请确认远端地址拼写正确，且该令牌有权访问该仓库。'**
  String get gitErrRepositoryNotFoundHint;

  /// No description provided for @gitErrProxyAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'网络代理需要认证'**
  String get gitErrProxyAuthRequired;

  /// No description provided for @gitErrProxyAuthRequiredHint.
  ///
  /// In zh, this message translates to:
  /// **'当前网络经过需要认证的代理（HTTP 407）。请检查容器内代理配置与凭据。'**
  String get gitErrProxyAuthRequiredHint;

  /// No description provided for @gitErrRequestRejected.
  ///
  /// In zh, this message translates to:
  /// **'服务器拒绝了本次请求'**
  String get gitErrRequestRejected;

  /// No description provided for @gitErrRequestRejectedHint.
  ///
  /// In zh, this message translates to:
  /// **'通常表示推送内容或分支引用不合法（HTTP 422），例如分支名不符合平台规则或提交信息被策略拦截。'**
  String get gitErrRequestRejectedHint;

  /// No description provided for @gitErrRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，已被平台限流'**
  String get gitErrRateLimited;

  /// No description provided for @gitErrRateLimitedHint.
  ///
  /// In zh, this message translates to:
  /// **'请稍等几分钟后重试（HTTP 429）。短时间内反复重试会延长限制时间。'**
  String get gitErrRateLimitedHint;

  /// No description provided for @gitErrHttpError.
  ///
  /// In zh, this message translates to:
  /// **'服务器返回了错误状态码'**
  String get gitErrHttpError;

  /// No description provided for @gitErrHttpErrorHint.
  ///
  /// In zh, this message translates to:
  /// **'请根据下方状态码排查：401 令牌无效、403 无权限、404 仓库不存在或无权访问、407 需要代理认证、429 被限流。'**
  String get gitErrHttpErrorHint;

  /// No description provided for @gitErrPasswordAuthDisabled.
  ///
  /// In zh, this message translates to:
  /// **'该平台已禁用账号密码认证'**
  String get gitErrPasswordAuthDisabled;

  /// No description provided for @gitErrPasswordAuthDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'请在「Git 账号管理」中使用个人访问令牌 (PAT) 重新添加账号。'**
  String get gitErrPasswordAuthDisabledHint;

  /// No description provided for @gitErrNetworkUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'网络无法连接到远端服务器'**
  String get gitErrNetworkUnreachable;

  /// No description provided for @gitErrNetworkUnreachableHint.
  ///
  /// In zh, this message translates to:
  /// **'请检查网络连接，以及容器内 DNS 配置（/etc/resolv.conf）是否正常。'**
  String get gitErrNetworkUnreachableHint;

  /// No description provided for @gitErrSshPublicKeyDenied.
  ///
  /// In zh, this message translates to:
  /// **'SSH 公钥认证被拒绝'**
  String get gitErrSshPublicKeyDenied;

  /// No description provided for @gitErrSshPublicKeyDeniedHint.
  ///
  /// In zh, this message translates to:
  /// **'请确认容器内的公钥已添加到平台的 SSH Keys 中，或改用 HTTPS + 访问令牌。'**
  String get gitErrSshPublicKeyDeniedHint;

  /// No description provided for @gitErrSshKeyUnusable.
  ///
  /// In zh, this message translates to:
  /// **'SSH 私钥无法使用（权限或格式异常）'**
  String get gitErrSshKeyUnusable;

  /// No description provided for @gitErrSshKeyUnusableHint.
  ///
  /// In zh, this message translates to:
  /// **'私钥权限需为 600。可在「Git 账号管理」中重新生成密钥对。'**
  String get gitErrSshKeyUnusableHint;

  /// No description provided for @gitErrHostKeyUnverified.
  ///
  /// In zh, this message translates to:
  /// **'目标服务器的主机指纹尚未确认，连接被中断'**
  String get gitErrHostKeyUnverified;

  /// No description provided for @gitErrHostKeyUnverifiedHint.
  ///
  /// In zh, this message translates to:
  /// **'首次连接需要确认主机指纹。若刚更换过服务器密钥，请清理容器内 ~/.ssh/known_hosts 后重试。'**
  String get gitErrHostKeyUnverifiedHint;

  /// No description provided for @gitErrNonFastForward.
  ///
  /// In zh, this message translates to:
  /// **'推送被拒绝：远端存在本地尚无的提交'**
  String get gitErrNonFastForward;

  /// No description provided for @gitErrNonFastForwardHint.
  ///
  /// In zh, this message translates to:
  /// **'请先执行 Pull（rebase 方式）合并远端改动，再重新推送。'**
  String get gitErrNonFastForwardHint;

  /// No description provided for @gitErrStaleForcePush.
  ///
  /// In zh, this message translates to:
  /// **'强推被拒绝：远端分支已被他人更新'**
  String get gitErrStaleForcePush;

  /// No description provided for @gitErrStaleForcePushHint.
  ///
  /// In zh, this message translates to:
  /// **'请先执行 Fetch 获取最新远端状态，确认差异后再强制推送。'**
  String get gitErrStaleForcePushHint;

  /// No description provided for @gitErrConflictDetected.
  ///
  /// In zh, this message translates to:
  /// **'合并/rebase 出现冲突，需要手动解决'**
  String get gitErrConflictDetected;

  /// No description provided for @gitErrConflictDetectedHint.
  ///
  /// In zh, this message translates to:
  /// **'请逐个解决冲突文件，或放弃本次操作（git rebase --abort）。'**
  String get gitErrConflictDetectedHint;

  /// No description provided for @gitErrLocalChanges.
  ///
  /// In zh, this message translates to:
  /// **'本地未提交的改动会被覆盖，操作已中止'**
  String get gitErrLocalChanges;

  /// No description provided for @gitErrLocalChangesHint.
  ///
  /// In zh, this message translates to:
  /// **'请先提交改动，或将其贮藏（stash）后再执行。'**
  String get gitErrLocalChangesHint;

  /// No description provided for @gitErrNoUpstream.
  ///
  /// In zh, this message translates to:
  /// **'当前分支尚未关联远端分支'**
  String get gitErrNoUpstream;

  /// No description provided for @gitErrNoUpstreamHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用「发布分支」将本地分支推送到远端并建立追踪关系。'**
  String get gitErrNoUpstreamHint;

  /// No description provided for @gitErrRefLockFailed.
  ///
  /// In zh, this message translates to:
  /// **'Git 引用文件被占用（存在残留锁）'**
  String get gitErrRefLockFailed;

  /// No description provided for @gitErrRefLockFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'可能有另一个 Git 进程正在运行。稍后重试，或清理 .git 目录下的 .lock 文件。'**
  String get gitErrRefLockFailedHint;

  /// No description provided for @gitErrOutOfSpace.
  ///
  /// In zh, this message translates to:
  /// **'设备存储空间不足'**
  String get gitErrOutOfSpace;

  /// No description provided for @gitErrOutOfSpaceHint.
  ///
  /// In zh, this message translates to:
  /// **'请清理容器或设备空间后重试。'**
  String get gitErrOutOfSpaceHint;

  /// No description provided for @gitErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'操作超时'**
  String get gitErrTimeout;

  /// No description provided for @gitErrTimeoutHint.
  ///
  /// In zh, this message translates to:
  /// **'仓库较大或网络较慢时可能超时。可改用终端观察进度，或在网络较好时重试。'**
  String get gitErrTimeoutHint;

  /// No description provided for @gitErrIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成，但没有返回具体错误信息'**
  String get gitErrIncomplete;

  /// No description provided for @gitErrIncompleteHint.
  ///
  /// In zh, this message translates to:
  /// **'通常是被超时或网络中断打断。仓库较大时建议改用终端执行 fetch 观察进度，或稍后在网络较好时重试。'**
  String get gitErrIncompleteHint;

  /// No description provided for @gitErrUnknown.
  ///
  /// In zh, this message translates to:
  /// **'Git 操作失败'**
  String get gitErrUnknown;

  /// No description provided for @gitErrUnknownHint.
  ///
  /// In zh, this message translates to:
  /// **'请展开下方原始输出查看详细信息。'**
  String get gitErrUnknownHint;

  /// No description provided for @gitRawOutput.
  ///
  /// In zh, this message translates to:
  /// **'原始输出'**
  String get gitRawOutput;

  /// No description provided for @gitElapsed.
  ///
  /// In zh, this message translates to:
  /// **'已用 {time}'**
  String gitElapsed(String time);

  /// No description provided for @gitElapsedMinutesSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{minutes}:{seconds}'**
  String gitElapsedMinutesSeconds(int minutes, String seconds);

  /// No description provided for @gitFetch.
  ///
  /// In zh, this message translates to:
  /// **'抓取'**
  String get gitFetch;

  /// No description provided for @gitFetchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'从远端抓取最新提交（不合并到本地）'**
  String get gitFetchTooltip;

  /// No description provided for @gitPull.
  ///
  /// In zh, this message translates to:
  /// **'拉取'**
  String get gitPull;

  /// No description provided for @gitPullTooltip.
  ///
  /// In zh, this message translates to:
  /// **'拉取远端提交并以 rebase 方式合并到当前分支'**
  String get gitPullTooltip;

  /// No description provided for @gitPush.
  ///
  /// In zh, this message translates to:
  /// **'推送'**
  String get gitPush;

  /// No description provided for @gitPushTooltip.
  ///
  /// In zh, this message translates to:
  /// **'将本地提交推送到远端'**
  String get gitPushTooltip;

  /// No description provided for @gitPublishBranch.
  ///
  /// In zh, this message translates to:
  /// **'发布分支'**
  String get gitPublishBranch;

  /// No description provided for @gitPublishBranchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'将本地分支推送到远端并建立追踪关系'**
  String get gitPublishBranchTooltip;

  /// No description provided for @gitSync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get gitSync;

  /// No description provided for @gitSyncTooltip.
  ///
  /// In zh, this message translates to:
  /// **'先拉取远端改动，再推送本地提交'**
  String get gitSyncTooltip;

  /// No description provided for @gitCancelOperation.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get gitCancelOperation;

  /// No description provided for @gitRemoteOperationRunning.
  ///
  /// In zh, this message translates to:
  /// **'云端操作进行中...'**
  String get gitRemoteOperationRunning;

  /// No description provided for @gitRemoteOperationCancelled.
  ///
  /// In zh, this message translates to:
  /// **'操作已取消'**
  String get gitRemoteOperationCancelled;

  /// No description provided for @gitRemoteOperationBusy.
  ///
  /// In zh, this message translates to:
  /// **'已有云端操作正在进行，请稍候'**
  String get gitRemoteOperationBusy;

  /// No description provided for @gitFetchSuccess.
  ///
  /// In zh, this message translates to:
  /// **'抓取完成'**
  String get gitFetchSuccess;

  /// No description provided for @gitFetchNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'已是最新状态'**
  String get gitFetchNoChanges;

  /// No description provided for @gitPullSuccess.
  ///
  /// In zh, this message translates to:
  /// **'拉取完成'**
  String get gitPullSuccess;

  /// No description provided for @gitPullAlreadyUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新，无需拉取'**
  String get gitPullAlreadyUpToDate;

  /// No description provided for @gitPushSuccess.
  ///
  /// In zh, this message translates to:
  /// **'推送完成'**
  String get gitPushSuccess;

  /// No description provided for @gitPushUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'远端已是最新，无需推送'**
  String get gitPushUpToDate;

  /// No description provided for @gitNoRemoteConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置远程仓库'**
  String get gitNoRemoteConfigured;

  /// No description provided for @gitNoRemoteDesc.
  ///
  /// In zh, this message translates to:
  /// **'添加远程仓库地址后，即可抓取、拉取与推送代码。'**
  String get gitNoRemoteDesc;

  /// No description provided for @gitAddRemote.
  ///
  /// In zh, this message translates to:
  /// **'添加远程仓库'**
  String get gitAddRemote;

  /// No description provided for @gitRemoteManagement.
  ///
  /// In zh, this message translates to:
  /// **'远程仓库管理'**
  String get gitRemoteManagement;

  /// No description provided for @gitRemoteName.
  ///
  /// In zh, this message translates to:
  /// **'远程名称'**
  String get gitRemoteName;

  /// No description provided for @gitRemoteNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 origin'**
  String get gitRemoteNameHint;

  /// No description provided for @gitRemoteUrl.
  ///
  /// In zh, this message translates to:
  /// **'远程地址'**
  String get gitRemoteUrl;

  /// No description provided for @gitRemoteUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://github.com/user/repo.git 或 git@github.com:user/repo.git'**
  String get gitRemoteUrlHint;

  /// No description provided for @gitRemotePushUrl.
  ///
  /// In zh, this message translates to:
  /// **'推送地址（可选）'**
  String get gitRemotePushUrl;

  /// No description provided for @gitRemotePushUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则与抓取地址相同'**
  String get gitRemotePushUrlHint;

  /// No description provided for @gitRemoteNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入远程名称'**
  String get gitRemoteNameRequired;

  /// No description provided for @gitRemoteUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入远程地址'**
  String get gitRemoteUrlRequired;

  /// No description provided for @gitRemoteAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加远程仓库 {name}'**
  String gitRemoteAdded(String name);

  /// No description provided for @gitRemoteRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已移除远程仓库 {name}'**
  String gitRemoteRemoved(String name);

  /// No description provided for @gitRemoteRenamed.
  ///
  /// In zh, this message translates to:
  /// **'已将 {old} 重命名为 {newName}'**
  String gitRemoteRenamed(String old, String newName);

  /// No description provided for @gitRemoteUrlUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新远程地址'**
  String get gitRemoteUrlUpdated;

  /// No description provided for @gitRemotePruned.
  ///
  /// In zh, this message translates to:
  /// **'已清理远端已删除的分支'**
  String get gitRemotePruned;

  /// No description provided for @gitRemoteRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要移除远程仓库 {name} 吗？本地代码不会被删除。'**
  String gitRemoteRemoveConfirm(String name);

  /// No description provided for @gitRemoteEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑远程仓库'**
  String get gitRemoteEdit;

  /// No description provided for @gitRemoteFetchUrl.
  ///
  /// In zh, this message translates to:
  /// **'抓取地址'**
  String get gitRemoteFetchUrl;

  /// No description provided for @gitRemoteSetPushUrl.
  ///
  /// In zh, this message translates to:
  /// **'设置推送地址'**
  String get gitRemoteSetPushUrl;

  /// No description provided for @gitRemotePrune.
  ///
  /// In zh, this message translates to:
  /// **'清理失效分支'**
  String get gitRemotePrune;

  /// No description provided for @gitCheckConnection.
  ///
  /// In zh, this message translates to:
  /// **'检测连接'**
  String get gitCheckConnection;

  /// No description provided for @gitCheckConnectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接正常，认证可用'**
  String get gitCheckConnectionSuccess;

  /// No description provided for @gitNoRemotes.
  ///
  /// In zh, this message translates to:
  /// **'暂无远程仓库'**
  String get gitNoRemotes;

  /// No description provided for @gitFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'抓取失败'**
  String get gitFetchFailed;

  /// No description provided for @gitPullFailed.
  ///
  /// In zh, this message translates to:
  /// **'拉取失败'**
  String get gitPullFailed;

  /// No description provided for @gitPushFailed.
  ///
  /// In zh, this message translates to:
  /// **'推送失败'**
  String get gitPushFailed;

  /// No description provided for @gitForcePush.
  ///
  /// In zh, this message translates to:
  /// **'强制推送'**
  String get gitForcePush;

  /// No description provided for @gitForcePushTooltip.
  ///
  /// In zh, this message translates to:
  /// **'覆盖远端分支（使用 --force-with-lease 安全校验）'**
  String get gitForcePushTooltip;

  /// No description provided for @gitForcePushWarning.
  ///
  /// In zh, this message translates to:
  /// **'强制推送会用本地提交覆盖远端分支，可能导致他人提交丢失。'**
  String get gitForcePushWarning;

  /// No description provided for @gitForcePushConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认强制推送'**
  String get gitForcePushConfirm;

  /// No description provided for @gitForcePushConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'该操作将改写远端 {branch} 分支的历史。仅在确认远端没有他人新提交时使用。'**
  String gitForcePushConfirmDesc(String branch);

  /// No description provided for @gitForcePushUseLease.
  ///
  /// In zh, this message translates to:
  /// **'使用安全强推（--force-with-lease）'**
  String get gitForcePushUseLease;

  /// No description provided for @gitPullThenPush.
  ///
  /// In zh, this message translates to:
  /// **'先拉取再推送'**
  String get gitPullThenPush;

  /// No description provided for @gitPullThenPushDesc.
  ///
  /// In zh, this message translates to:
  /// **'远端存在本地没有的提交，先拉取合并后再推送。'**
  String get gitPullThenPushDesc;

  /// No description provided for @gitConflictAbort.
  ///
  /// In zh, this message translates to:
  /// **'放弃本次变基'**
  String get gitConflictAbort;

  /// No description provided for @gitConflictAbortConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要放弃本次变基操作并回到操作前的状态吗？'**
  String get gitConflictAbortConfirm;

  /// No description provided for @gitUncommittedChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'存在未提交的改动'**
  String get gitUncommittedChangesTitle;

  /// No description provided for @gitUncommittedChangesDesc.
  ///
  /// In zh, this message translates to:
  /// **'拉取前需要先处理本地未提交的改动，否则可能被覆盖。'**
  String get gitUncommittedChangesDesc;

  /// No description provided for @gitUncommittedStashAndPull.
  ///
  /// In zh, this message translates to:
  /// **'贮藏并拉取'**
  String get gitUncommittedStashAndPull;

  /// No description provided for @gitUncommittedCommitFirst.
  ///
  /// In zh, this message translates to:
  /// **'先去提交'**
  String get gitUncommittedCommitFirst;

  /// No description provided for @gitUncommittedCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get gitUncommittedCancel;

  /// No description provided for @gitStashAndPullSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已贮藏本地改动并完成拉取'**
  String get gitStashAndPullSuccess;

  /// No description provided for @gitViewOperationLog.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get gitViewOperationLog;

  /// No description provided for @gitHideOperationLog.
  ///
  /// In zh, this message translates to:
  /// **'收起详情'**
  String get gitHideOperationLog;

  /// No description provided for @gitAheadBehind.
  ///
  /// In zh, this message translates to:
  /// **'领先 {ahead} / 落后 {behind}'**
  String gitAheadBehind(int ahead, int behind);

  /// No description provided for @gitUpstreamGone.
  ///
  /// In zh, this message translates to:
  /// **'上游分支已不存在'**
  String get gitUpstreamGone;

  /// No description provided for @gitBehindTooltip.
  ///
  /// In zh, this message translates to:
  /// **'本地落后远端 {behind} 个提交'**
  String gitBehindTooltip(int behind);

  /// No description provided for @gitAheadTooltip.
  ///
  /// In zh, this message translates to:
  /// **'本地领先远端 {ahead} 个提交'**
  String gitAheadTooltip(int ahead);

  /// No description provided for @gitDiff.
  ///
  /// In zh, this message translates to:
  /// **'差异对比'**
  String get gitDiff;

  /// No description provided for @gitDiffOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始版本'**
  String get gitDiffOriginal;

  /// No description provided for @gitDiffModified.
  ///
  /// In zh, this message translates to:
  /// **'修改版本'**
  String get gitDiffModified;

  /// No description provided for @gitDiffSplitView.
  ///
  /// In zh, this message translates to:
  /// **'双屏分栏'**
  String get gitDiffSplitView;

  /// No description provided for @gitDiffUnifiedView.
  ///
  /// In zh, this message translates to:
  /// **'单屏内联'**
  String get gitDiffUnifiedView;

  /// No description provided for @gitDiffPrevChange.
  ///
  /// In zh, this message translates to:
  /// **'上一处更改'**
  String get gitDiffPrevChange;

  /// No description provided for @gitDiffNextChange.
  ///
  /// In zh, this message translates to:
  /// **'下一处更改'**
  String get gitDiffNextChange;

  /// No description provided for @gitDiffBinaryOrEmpty.
  ///
  /// In zh, this message translates to:
  /// **'二进制或不支持比较的文件'**
  String get gitDiffBinaryOrEmpty;

  /// No description provided for @gitDiffNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'该文件与基准版本完全一致，暂无差异'**
  String get gitDiffNoChanges;

  /// No description provided for @gitDiffStageTooltip.
  ///
  /// In zh, this message translates to:
  /// **'暂存此文件更改'**
  String get gitDiffStageTooltip;

  /// No description provided for @gitDiffUnstageTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消暂存此文件'**
  String get gitDiffUnstageTooltip;

  /// No description provided for @gitDiffDiscardTooltip.
  ///
  /// In zh, this message translates to:
  /// **'放弃此文件更改'**
  String get gitDiffDiscardTooltip;

  /// No description provided for @gitExpandAll.
  ///
  /// In zh, this message translates to:
  /// **'全部展开'**
  String get gitExpandAll;

  /// No description provided for @gitLoadMoreCommits.
  ///
  /// In zh, this message translates to:
  /// **'加载更多提交 ({count})'**
  String gitLoadMoreCommits(int count);

  /// No description provided for @gitLoadedCommitsCount.
  ///
  /// In zh, this message translates to:
  /// **'已显示 {loaded} / {total} 个提交'**
  String gitLoadedCommitsCount(int loaded, int total);

  /// No description provided for @gitAllCommitsLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已显示全部 {count} 个提交'**
  String gitAllCommitsLoaded(int count);

  /// No description provided for @gitLoadingMoreCommits.
  ///
  /// In zh, this message translates to:
  /// **'正在加载更多提交...'**
  String get gitLoadingMoreCommits;

  /// No description provided for @searchExpandAllMatchesInFile.
  ///
  /// In zh, this message translates to:
  /// **'展开全部匹配项'**
  String get searchExpandAllMatchesInFile;

  /// No description provided for @preserveCase.
  ///
  /// In zh, this message translates to:
  /// **'保留大小写'**
  String get preserveCase;

  /// No description provided for @replaceMoreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多替换选项'**
  String get replaceMoreOptions;

  /// No description provided for @searchRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get searchRefresh;

  /// No description provided for @searchPreviousMatch.
  ///
  /// In zh, this message translates to:
  /// **'上一个匹配项'**
  String get searchPreviousMatch;

  /// No description provided for @searchNextMatch.
  ///
  /// In zh, this message translates to:
  /// **'下一个匹配项'**
  String get searchNextMatch;

  /// No description provided for @replaceCurrentMatch.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replaceCurrentMatch;

  /// No description provided for @gitAccountManagement.
  ///
  /// In zh, this message translates to:
  /// **'Git 账号管理'**
  String get gitAccountManagement;

  /// No description provided for @gitEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get gitEdit;

  /// No description provided for @gitHostedAccounts.
  ///
  /// In zh, this message translates to:
  /// **'托管账号'**
  String get gitHostedAccounts;

  /// No description provided for @gitSshKeys.
  ///
  /// In zh, this message translates to:
  /// **'SSH 密钥'**
  String get gitSshKeys;

  /// No description provided for @gitAddAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加 Git 账号'**
  String get gitAddAccount;

  /// No description provided for @gitEditAccount.
  ///
  /// In zh, this message translates to:
  /// **'编辑 Git 账号'**
  String get gitEditAccount;

  /// No description provided for @gitNoAccountsTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂未绑定 Git 账号'**
  String get gitNoAccountsTitle;

  /// No description provided for @gitNoAccountsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'绑定 GitHub 或 Gitee 等账号后，推送代码、拉取私有仓库将全程免密认证。'**
  String get gitNoAccountsSubtitle;

  /// No description provided for @gitAddFirstAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加第一个 Git 账号'**
  String get gitAddFirstAccount;

  /// No description provided for @gitDefaultAccountBadge.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get gitDefaultAccountBadge;

  /// No description provided for @gitSetAsDefault.
  ///
  /// In zh, this message translates to:
  /// **'设为默认账号'**
  String get gitSetAsDefault;

  /// No description provided for @gitSetAsDefaultSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已设为默认账号'**
  String get gitSetAsDefaultSuccess;

  /// No description provided for @gitTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get gitTestConnection;

  /// No description provided for @gitTestingConnection.
  ///
  /// In zh, this message translates to:
  /// **'正在验证平台连接...'**
  String get gitTestingConnection;

  /// No description provided for @gitTestConnectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功！已验证用户: {username}'**
  String gitTestConnectionSuccess(String username);

  /// No description provided for @gitTestConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证失败'**
  String get gitTestConnectionFailed;

  /// No description provided for @gitDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get gitDeleteAccount;

  /// No description provided for @gitDeleteAccountConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除账号 {name}？'**
  String gitDeleteAccountConfirmTitle(String name);

  /// No description provided for @gitDeleteAccountConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除后该账号凭据将从本地及容器内移除，相关远程操作将需要重新认证。'**
  String get gitDeleteAccountConfirmMessage;

  /// No description provided for @gitDeleteAccountSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已删除账号'**
  String get gitDeleteAccountSuccess;

  /// No description provided for @gitAccountSavedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'账号添加成功'**
  String get gitAccountSavedSuccess;

  /// No description provided for @gitAccountUpdatedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'账号已更新'**
  String get gitAccountUpdatedSuccess;

  /// No description provided for @gitContainerSshTitle.
  ///
  /// In zh, this message translates to:
  /// **'容器内置 SSH 密钥对'**
  String get gitContainerSshTitle;

  /// No description provided for @gitContainerSshSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用于 SSH 协议免密克隆与推送 (git@github.com:... 或 git@gitee.com:...)。'**
  String get gitContainerSshSubtitle;

  /// No description provided for @gitCopyPublicKey.
  ///
  /// In zh, this message translates to:
  /// **'一键复制公钥'**
  String get gitCopyPublicKey;

  /// No description provided for @gitPublicKeyCopied.
  ///
  /// In zh, this message translates to:
  /// **'公钥已复制到剪贴板'**
  String get gitPublicKeyCopied;

  /// No description provided for @gitRegenerateKey.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get gitRegenerateKey;

  /// No description provided for @gitNoSshKeyNotice.
  ///
  /// In zh, this message translates to:
  /// **'当前尚未生成 SSH 密钥对。生成后即可一键复制并粘贴至 GitHub/Gitee 的 SSH Keys 设置中。'**
  String get gitNoSshKeyNotice;

  /// No description provided for @gitGenerateEd25519Key.
  ///
  /// In zh, this message translates to:
  /// **'生成 Ed25519 SSH 密钥'**
  String get gitGenerateEd25519Key;

  /// No description provided for @gitGeneratingSshKey.
  ///
  /// In zh, this message translates to:
  /// **'正在生成 SSH 密钥...'**
  String get gitGeneratingSshKey;

  /// No description provided for @gitSshKeyGenerateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'SSH 密钥生成成功'**
  String get gitSshKeyGenerateSuccess;

  /// No description provided for @gitSshKeyGenerateFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get gitSshKeyGenerateFailed;

  /// No description provided for @gitRegenerateSshConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新生成 SSH 密钥？'**
  String get gitRegenerateSshConfirmTitle;

  /// No description provided for @gitRegenerateSshConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'重新生成将覆盖现有的 SSH 密钥，旧公钥在 GitHub/Gitee 上将失效，需重新粘贴新公钥。'**
  String get gitRegenerateSshConfirmMessage;

  /// No description provided for @gitOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'确定覆盖'**
  String get gitOverwrite;

  /// No description provided for @gitSshGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何配置到云端平台？'**
  String get gitSshGuideTitle;

  /// No description provided for @gitSshGuideStep1.
  ///
  /// In zh, this message translates to:
  /// **'点击上方【一键复制公钥】；'**
  String get gitSshGuideStep1;

  /// No description provided for @gitSshGuideStep2.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器打开 GitHub 或 Gitee 的设置页 (Settings -> SSH Keys)；'**
  String get gitSshGuideStep2;

  /// No description provided for @gitSshGuideStep3.
  ///
  /// In zh, this message translates to:
  /// **'点击 \"New SSH Key\"，将公钥粘贴到 Key 输入框中保存即可。'**
  String get gitSshGuideStep3;

  /// No description provided for @gitServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get gitServerUrl;

  /// No description provided for @gitTokenLabel.
  ///
  /// In zh, this message translates to:
  /// **'访问令牌'**
  String get gitTokenLabel;

  /// No description provided for @gitTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'输入在平台创建的 PAT 令牌'**
  String get gitTokenHint;

  /// No description provided for @gitGetToken.
  ///
  /// In zh, this message translates to:
  /// **'获取 Token'**
  String get gitGetToken;

  /// No description provided for @gitTokenCopiedOpeningBrowser.
  ///
  /// In zh, this message translates to:
  /// **'Token 创建链接已复制，正在前往浏览器...'**
  String get gitTokenCopiedOpeningBrowser;

  /// No description provided for @gitEnterTokenPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入访问令牌'**
  String get gitEnterTokenPrompt;

  /// No description provided for @gitTokenVerifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'Token 校验失败，请核对权限或有效性'**
  String get gitTokenVerifyFailed;

  /// No description provided for @gitVerifyAndSave.
  ///
  /// In zh, this message translates to:
  /// **'验证并保存'**
  String get gitVerifyAndSave;

  /// No description provided for @gitAuthTypeToken.
  ///
  /// In zh, this message translates to:
  /// **'个人访问令牌'**
  String get gitAuthTypeToken;

  /// No description provided for @gitAuthTypeSsh.
  ///
  /// In zh, this message translates to:
  /// **'SSH 密钥对'**
  String get gitAuthTypeSsh;

  /// No description provided for @gitPlatformGeneric.
  ///
  /// In zh, this message translates to:
  /// **'通用 / 自建 Git'**
  String get gitPlatformGeneric;
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
