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
  String get indentSize => '缩进大小';

  @override
  String get selectIndentSize => '选择缩进空格数';

  @override
  String spacesCount(int count) {
    return '$count 个空格';
  }

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
  String get editVirtualKeyboardConfigSubtitle => '自定义小键盘按键布局与快捷键';

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

  @override
  String get storagePermissionRequiredTitle => '需要存储访问权限';

  @override
  String get storagePermissionRequiredMessage =>
      '代码编辑器需要“管理所有文件”权限，以便在您的设备上读取、新建和保存项目文件。\n\n请在接下来的系统设置页面中开启该权限。';

  @override
  String get goToSettings => '去设置';

  @override
  String get terminal => '终端';

  @override
  String terminalWithSystem(String system) {
    return '终端 · $system';
  }

  @override
  String get sessionDefaultName => '会话';

  @override
  String get systemManagement => '系统管理';

  @override
  String get systemManagementTooltip => '系统管理与选择';

  @override
  String get sessionListTooltip => '会话列表';

  @override
  String get noActiveSessions => '暂无活跃会话';

  @override
  String get terminalInputHint => '输入命令...';

  @override
  String get sendCommandTooltip => '发送命令';

  @override
  String get importNewSystem => '导入新系统';

  @override
  String get importBuiltinAlpine => '从软件中导入 (Alpine)';

  @override
  String get importExternalTarGz => '从外部导入 (.tar.gz)';

  @override
  String get selectSystemDefaultPrompt => '选择系统将设为默认系统，新建终端时从该系统中启动：';

  @override
  String get noSystemsPrompt => '暂无系统，请点击右上角 \"+\" 导入';

  @override
  String get importBuiltinAlpineTitle => '从软件导入 Alpine 系统';

  @override
  String systemNameHintWithDefault(String name) {
    return '系统名称（如 $name）';
  }

  @override
  String systemImportSuccess(String name) {
    return '系统 \"$name\" 导入并就绪';
  }

  @override
  String get importExternalSystemTitle => '导入外部系统';

  @override
  String get systemNameHint => '系统名称';

  @override
  String externalSystemImportSuccess(String name) {
    return '外部系统 \"$name\" 导入并就绪';
  }

  @override
  String get deleteSystemConfirmTitle => '高危操作：确认删除系统';

  @override
  String deleteSystemConfirmMessage(String name) {
    return '确定要彻底删除系统 \"$name\" 吗？\n\n⚠️ 该操作将物理级清除该系统及其所有内部数据与已安装软件包，此操作不可逆！\n\n该系统关联的所有终端会话也将被同步关闭。';
  }

  @override
  String get permanentDelete => '彻底删除';

  @override
  String deleteSystemSuccess(String name) {
    return '已彻底删除系统 \"$name\" 及关联会话';
  }

  @override
  String get deleteSystemTooltip => '彻底删除该系统 (高危)';

  @override
  String get preparingInitialization => '准备初始化...';

  @override
  String get cancellingAndCleaning => '正在取消并清理残余目录...';

  @override
  String cancelledImportSystem(String name) {
    return '已取消导入系统 \"$name\"';
  }

  @override
  String importFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String importingSystemTitle(String name) {
    return '正在导入: $name';
  }

  @override
  String get cancelImport => '取消导入';

  @override
  String get interrupting => '正在中断...';

  @override
  String get sessionDrawerTitle => '会话';

  @override
  String get addTerminalTooltip => '添加终端';

  @override
  String get noSystemSelectedWarning => '当前未选择任何系统，请先导入或选择系统';

  @override
  String get noSessionsInDrawerPrompt => '暂无会话，请点击右上角添加';

  @override
  String confirmDeleteTerminalSession(int index, String name) {
    return '确定要删除终端 \"($index) $name\" 吗？';
  }

  @override
  String deleteSystemFailed(String error) {
    return '删除系统失败: $error';
  }

  @override
  String get addSession => '新增会话';

  @override
  String get editorScope => '编辑区';

  @override
  String get terminalScope => '终端';

  @override
  String get virtualKeyboardConfigTitle => '小键盘配置';

  @override
  String virtualKeyboardPageSubtitle(String scope, int page) {
    return '$scope:(第 $page 页)';
  }

  @override
  String get keyboardRestoreDefaultTooltip => '恢复默认预设';

  @override
  String get keyboardPageManagementTooltip => '页面管理';

  @override
  String get keyboardDrawerTitle => '页面';

  @override
  String get keyboardNewPage => '新建页面';

  @override
  String keyboardPageItemTitle(int page) {
    return '第 $page 页';
  }

  @override
  String keyboardPageItemSubtitle(int count) {
    return '$count 行';
  }

  @override
  String get keyboardDeletePageTooltip => '删除页面';

  @override
  String get keyboardPageConfigSectionTitle => '页面配置';

  @override
  String get keyboardRowButtons => '行按钮数';

  @override
  String keyboardRowGridDescription(int count) {
    return '页面宽度等分为 $count 格';
  }

  @override
  String get keyboardDecreaseRowButtonsTooltip => '减少每行按键数';

  @override
  String get keyboardIncreaseRowButtonsTooltip => '增加每行按键数';

  @override
  String get keyboardPageKeysSectionTitle => '页面按键';

  @override
  String get keyboardAddNewRow => '添加新行';

  @override
  String get keyboardEmptyPageKeysHint => '当前页面暂无按键行';

  @override
  String get keyboardEmptyRowKeysHint => '行内暂无按键，点击上方“+”添加';

  @override
  String keyboardRowKeyCount(int count) {
    return '$count 个按键';
  }

  @override
  String get keyboardAddKeyTooltip => '添加按键';

  @override
  String get keyboardDeleteRowTooltip => '删除整行';

  @override
  String get keyboardEditKeyTooltip => '编辑按键';

  @override
  String get keyboardDeleteKeyTooltip => '删除按键';

  @override
  String get keyboardNoLabel => '(无标签)';

  @override
  String get keyboardResetDefaultTitle => '恢复默认配置';

  @override
  String get keyboardResetDefaultContent => '确定要将小键盘恢复为初始默认预设吗？当前自定义修改将被覆盖。';

  @override
  String get keyboardResetDefaultSuccess => '已恢复默认预设';

  @override
  String get keyboardDeletePageTitle => '删除页面';

  @override
  String keyboardDeletePageContent(int page) {
    return '确定要删除“第 $page 页”吗？';
  }

  @override
  String get keyboardDeleteRowTitle => '删除按键行';

  @override
  String keyboardDeleteRowContent(int row) {
    return '确定要删除“第 $row 行”及其包含的所有按键吗？';
  }

  @override
  String get keyboardDeleteKeyTitle => '删除按键';

  @override
  String keyboardDeleteKeyContent(String key) {
    return '确定要删除按键“$key”吗？';
  }

  @override
  String get keyboardKeepAtLeastOnePageWarning => '至少需要保留一个页面';

  @override
  String keyboardRowMaxKeysWarning(int count) {
    return '当前存在包含 $count 个按键的行，行按钮数不能小于 $count';
  }

  @override
  String keyboardRowReachedMaxWarning(int count) {
    return '当前行按键数已达到上限（最多 $count 个按键）';
  }

  @override
  String get keyboardAddKeyTitle => '添加按键';

  @override
  String get keyboardEditKeyTitle => '编辑按键';

  @override
  String get keyboardLabelFormField => '显示文本 (Label)';

  @override
  String get keyboardLabelFormFieldHint => '按键上显示的文本，如 Tab、()、A';

  @override
  String get keyboardLabelOrIconRequiredError => '请输入显示文本或选择图标';

  @override
  String get keyboardIconFormField => '图标 (Icon, 可选)';

  @override
  String get keyboardNoIconOption => '无图标 (使用文本显示)';

  @override
  String get keyboardActionFormField => '动作类型 (Action)';

  @override
  String get keyboardValueFormField => '输入文本内容 (Value)';

  @override
  String get keyboardValueFormFieldHint => '点击后直接插入的文本，如 ;、=、->';

  @override
  String get keyboardValueRequiredError => '输入文本不能为空';

  @override
  String get keyboardPairPresetFormField => '成对符号预设 (Value)';

  @override
  String get keyboardCommandPresetFormField => '预设编辑器命令 (Value)';

  @override
  String get keyboardModifierPresetFormField => '终端修饰键 (Value)';

  @override
  String get keyboardTerminalKeyPresetFormField => '终端按键 (Value)';

  @override
  String get keyboardCursorOffsetFormField => '光标相对偏移 (cursorOffset)';

  @override
  String get keyboardCursorOffsetHelper => '例如 () 插入后光标居中需向左偏移 1 位，填写 -1';

  @override
  String get keyboardCursorOffsetRequiredError => '请输入光标偏移（通常为 -1）';

  @override
  String get keyboardCursorOffsetIntegerError => '偏移量必须为整数';
}
