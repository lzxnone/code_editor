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
  /// **'自定义小键盘按键布局与快捷键 (JSON)'**
  String get editVirtualKeyboardConfigSubtitle;

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
