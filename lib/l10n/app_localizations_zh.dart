// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '代码编辑器';

  @override
  String get run => '运行';

  @override
  String get settings => '设置';

  @override
  String get fileDirectory => '项目';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get save => '保存';

  @override
  String get openFileDirectory => '打开项目';

  @override
  String get openProjectPrompt => '请点击上方按钮打开项目';

  @override
  String get viewProjectHistory => '查看项目历史';

  @override
  String get more => '更多';

  @override
  String get noOpenDirectory => '当前未打开项目';

  @override
  String get noOpenFile => '当前未打开文件';

  @override
  String get unnamed => '未命名';

  @override
  String get unknownDirectory => '未知目录';

  @override
  String get projectHistory => '历史项目';

  @override
  String get noHistory => '暂无历史记录';

  @override
  String get deleteThisHistory => '删除此记录';

  @override
  String get deleteHistoryTitle => '删除历史记录';

  @override
  String get deleteHistoryMessage => '确定要从历史记录中移除该项目吗？';

  @override
  String get remove => '移除';

  @override
  String get historyRemoved => '已移除历史记录';

  @override
  String get confirm => '确定';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get close => '关闭';

  @override
  String get closeAllTabs => '关闭所有标签';

  @override
  String get closeProject => '关闭当前项目';

  @override
  String get gotIt => '知道了';

  @override
  String get done => '完成';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get fileNameHint => '文件名 (例如: main.dart)';

  @override
  String get folderNameHint => '文件夹名';

  @override
  String get rename => '重命名';

  @override
  String get newName => '新名称';

  @override
  String get cut => '剪切';

  @override
  String get copy => '复制';

  @override
  String get paste => '粘贴';

  @override
  String get selectAll => '全选';

  @override
  String get copyPath => '复制路径';

  @override
  String get copyRelativePath => '复制相对路径';

  @override
  String get copiedPathToClipboard => '已复制完整路径到剪贴板';

  @override
  String get copiedRelativePathToClipboard => '已复制相对路径到剪贴板';

  @override
  String cutItem(Object name) {
    return '已剪切: $name';
  }

  @override
  String copiedItem(Object name) {
    return '已复制: $name';
  }

  @override
  String get operationSuccess => '操作成功';

  @override
  String operationFailed(Object error) {
    return '操作失败: $error';
  }

  @override
  String createFileFailed(Object error) {
    return '创建文件失败: $error';
  }

  @override
  String createFolderFailed(Object error) {
    return '创建文件夹失败: $error';
  }

  @override
  String renameFailed(Object error) {
    return '重命名失败: $error';
  }

  @override
  String deleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteMessage(Object name) {
    return '确定要删除 \"$name\" 吗？此操作不可恢复。';
  }

  @override
  String get nameCannotBeEmpty => '名称不能为空';

  @override
  String get nameInvalidChars => '名称不能包含非法字符 (\\/:*?\"<>|)';

  @override
  String get appearanceSection => '外观';

  @override
  String get appThemeMode => '应用主题模式';

  @override
  String get followSystem => '跟随系统';

  @override
  String get followSystemSubtitle => '自动与系统深浅色外观保持一致';

  @override
  String get lightMode => '浅色模式';

  @override
  String get lightModeSubtitle => '始终保持明亮外观';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkModeSubtitle => '始终保持暗黑外观';

  @override
  String get selectAppTheme => '选择应用主题';

  @override
  String get editorSection => '编辑区';

  @override
  String get codeHighlightTheme => '代码高亮主题';

  @override
  String get selectCodeHighlightTheme => '选择代码高亮主题';

  @override
  String get darkThemeCategory => '暗色系';

  @override
  String get lightThemeCategory => '浅色系';

  @override
  String get codeFontSize => '代码字号缩放';

  @override
  String get decreaseFontSize => '减小字号';

  @override
  String get increaseFontSize => '增大字号';

  @override
  String get fontSizeDialogTitle => '代码字号';

  @override
  String get wordWrap => '自动换行';

  @override
  String get wordWrapSubtitle => '长代码行超出边界时自动折行';

  @override
  String get virtualKeyboard => '辅助小键盘';

  @override
  String get virtualKeyboardSubtitle => '在代码编辑区底部显示辅助符号与快捷键';

  @override
  String get editVirtualKeyboardConfig => '编辑键盘配置';

  @override
  String get editVirtualKeyboardConfigSubtitle => '自定义小键盘按键布局与快捷键 (JSON)';

  @override
  String get virtualKeyboardDialogTitle => '小键盘配置 (JSON)';

  @override
  String get resetDefault => '恢复默认';

  @override
  String get configFormatError => '配置格式错误';

  @override
  String get configSavedSuccess => '小键盘配置已保存';

  @override
  String get formatJson => '格式化';

  @override
  String get languageSection => '语言';

  @override
  String get appLanguage => '应用语言';

  @override
  String get selectLanguage => '选择应用语言';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get refreshDirectory => '刷新项目';

  @override
  String get back => '返回';

  @override
  String get darkLabel => '暗色';

  @override
  String get lightLabel => '浅色';

  @override
  String get saveSuccess => '保存成功';

  @override
  String saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get saveChangesTitle => '保存更改';

  @override
  String saveChangesMessage(Object name) {
    return '文件 \"$name\" 已被修改，是否保存更改？';
  }

  @override
  String get dontSave => '不保存';

  @override
  String get saveAll => '保存所有';

  @override
  String get saveAllSuccess => '所有文件已保存';

  @override
  String get saveAllPromptTitle => '保存所有更改？';

  @override
  String get saveAllPromptMessage => '当前项目中有未保存的修改，是否保存所有文件？';

  @override
  String get fileConflictTitle => '外部文件已被更改';

  @override
  String fileConflictMessage(Object name) {
    return '文件 \"$name\" 已在外部被更改。您希望如何处理？';
  }

  @override
  String get reloadFromDisk => '用磁盘内容覆盖';

  @override
  String get keepLocal => '保留本地修改';
}
