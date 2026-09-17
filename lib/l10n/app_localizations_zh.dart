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
  String get uiFont => '界面字体';

  @override
  String get selectUiFont => '选择界面字体';

  @override
  String get themeColor => '主题颜色';

  @override
  String get selectThemeColor => '选择主题颜色';

  @override
  String get terminalBackgroundColor => '终端背景颜色';

  @override
  String get selectTerminalBackgroundColor => '选择终端背景颜色';

  @override
  String get uiFontPreview => '代码编辑器界面字体预览 Code Editor 123';

  @override
  String get codeFont => '代码字体';

  @override
  String get selectCodeFont => '选择代码字体';

  @override
  String get codeFontPreview => 'const app = \"Code Editor\"; // 代码预览';

  @override
  String get terminalFont => '终端字体';

  @override
  String get selectTerminalFont => '选择终端字体';

  @override
  String get terminalFontPreview => '\$ git status -s # 终端字体预览';

  @override
  String get terminalFontSize => '终端字号';

  @override
  String get terminalFontSizeDialogTitle => '终端字号';

  @override
  String fontName(String font) {
    String _temp0 = intl.Intl.selectLogic(font, {
      'system_default': '系统默认',
      'sans_serif': '无衬线体',
      'serif': '衬线体（宋体）',
      'monospace': '系统等宽',
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
  String get showLineNumbers => '显示行号';

  @override
  String get showLineNumbersSubtitle => '在代码左侧显示行号与折叠标记';

  @override
  String get pinLineNumbers => '固定行号';

  @override
  String get pinLineNumbersSubtitle => '水平滚动代码时行号固定在左侧';

  @override
  String get virtualKeyboard => '辅助小键盘';

  @override
  String get virtualKeyboardSubtitle => '在代码编辑区底部显示辅助符号与快捷键';

  @override
  String get editVirtualKeyboardConfig => '编辑键盘配置';

  @override
  String get editVirtualKeyboardConfigSubtitle => '自定义小键盘按键布局与快捷键';

  @override
  String get terminalVirtualKeyboard => '终端小键盘';

  @override
  String get terminalVirtualKeyboardSubtitle => '在终端下方显示常用特殊键与指令快捷键';

  @override
  String get editTerminalVirtualKeyboardConfig => '编辑终端键盘配置';

  @override
  String get editTerminalVirtualKeyboardConfigSubtitle =>
      '自定义 Esc / Tab / Ctrl 组合等终端专用按键';

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
  String get importFromApp => '从软件中导入';

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
  String get distroManagementTitle => '系统管理';

  @override
  String get installedStatus => '已就绪';

  @override
  String get notInstalledStatus => '未安装组件';

  @override
  String get downloadingStatus => '下载中';

  @override
  String get downloadAction => '下载';

  @override
  String get installAction => '安装';

  @override
  String get builtinTag => '内置';

  @override
  String get cancelDownloadAction => '取消下载';

  @override
  String get cancelDownloadConfirmTitle => '取消下载';

  @override
  String get cancelDownloadConfirmMessage => '确定要取消正在下载的系统资源吗？已下载的部分将被清除。';

  @override
  String get deletingSystemProgress => '正在删除系统并清理数据，请稍候...';

  @override
  String get cannotDeleteBuiltinSystem => '内置系统受到保护，无法删除';

  @override
  String get recommendedTag => '推荐';

  @override
  String downloadFailed(String error) {
    return '下载失败: $error';
  }

  @override
  String deleteSystemSuccess(String name) {
    return '已彻底删除系统 \"$name\" 及关联会话';
  }

  @override
  String get deletePackageConfirmTitle => '确认删除安装包';

  @override
  String deletePackageConfirmMessage(String name) {
    return '确定要删除 \"$name\" 的系统安装包吗？删除后可随时重新下载。';
  }

  @override
  String get deletingPackageProgress => '正在删除安装包，请稍候...';

  @override
  String deletePackageSuccess(String name) {
    return '已删除 \"$name\" 安装包';
  }

  @override
  String get deletePackageTooltip => '删除已下载的系统安装包';

  @override
  String importSystemInstanceTitle(String name) {
    return '创建 $name 系统实例';
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
  String get keyboardLabelFormField => '显示文本';

  @override
  String get keyboardLabelFormFieldHint => '按键上显示的文本，如 Tab、()、A';

  @override
  String get keyboardLabelOrIconRequiredError => '请输入显示文本或选择图标';

  @override
  String get keyboardIconFormField => '图标 (可选)';

  @override
  String keyboardIconName(String icon) {
    String _temp0 = intl.Intl.selectLogic(icon, {
      'undo': '撤销',
      'redo': '重做',
      'tab': '向右缩进',
      'untab': '向左缩进',
      'outdent': '减少缩进',
      'arrow_left': '左箭头',
      'arrow_right': '右箭头',
      'arrow_up': '上箭头',
      'arrow_down': '下箭头',
      'home': '移至行首',
      'end': '移至行尾',
      'first_page': '移至文首',
      'last_page': '移至文末',
      'page_up': '上翻页',
      'page_down': '下翻页',
      'enter': '回车',
      'space': '空格',
      'escape': '退出',
      'insert': '插入',
      'clear': '清除',
      'keyboard': '键盘',
      'backspace': '退格',
      'delete': '删除',
      'copy': '复制',
      'cut': '剪切',
      'paste': '粘贴',
      'save': '保存',
      'search': '搜索',
      'select_all': '全选',
      'keyboard_hide': '收起小键盘',
      'other': '$icon',
    });
    return '$_temp0';
  }

  @override
  String get keyboardNoIconOption => '无图标 (使用文本显示)';

  @override
  String get keyboardActionFormField => '动作类型';

  @override
  String keyboardActionName(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'input': '普通文本',
      'pair': '成对符号',
      'command': '编辑器命令',
      'modifier': '修饰键',
      'key': '特殊键',
      'other': '$action',
    });
    return '$_temp0';
  }

  @override
  String get keyboardActionInputTerminal => '指令快捷键';

  @override
  String get keyboardKeyFormField => '特殊键';

  @override
  String get keyboardKeyGroupNavigation => '导航键';

  @override
  String get keyboardKeyGroupEditing => '编辑键';

  @override
  String get keyboardKeyGroupFunctionKeys => '功能键';

  @override
  String get keyboardKeyGroupLetters => '字母键';

  @override
  String get keyboardAutoEnter => '发送后自动回车';

  @override
  String keyboardKeyName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'escape': '退出',
      'tab': 'Tab',
      'backtab': '反向制表',
      'returnKey': '回车',
      'enter': '回车',
      'numpadEnter': '小键盘回车',
      'backspace': '退格',
      'delete': '删除',
      'insert': '插入',
      'space': '空格',
      'numpadClear': '清除',
      'arrowUp': '上',
      'arrowDown': '下',
      'arrowLeft': '左',
      'arrowRight': '右',
      'home': '行首',
      'end': '行尾',
      'pageUp': '上翻页',
      'pageDown': '下翻页',
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
  String get keyboardKeyInvalidError => '该键在终端中不会产生任何输出，请选择列表中的特殊键';

  @override
  String get keyboardValueFormField => '输入文本内容';

  @override
  String get keyboardValueFormFieldHint => '点击后直接插入的文本，如 ;、=、->';

  @override
  String get keyboardValueRequiredError => '输入文本不能为空';

  @override
  String get keyboardPairValueFormField => '成对符号';

  @override
  String get keyboardPairValueFormFieldHint => '例如 ()、[]、\"\"、<>';

  @override
  String get keyboardPairValueRequiredError => '请输入成对符号';

  @override
  String get keyboardPairValueInvalidError => '请输入至少 2 个字符且左右不同的成对符号，如 ()、[]';

  @override
  String get keyboardCommandPresetFormField => '编辑器命令';

  @override
  String keyboardCommandName(String command) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'tab': '向右缩进',
      'untab': '向左缩进',
      'undo': '撤销',
      'redo': '重做',
      'cursor_left': '光标左移',
      'cursor_right': '光标右移',
      'cursor_up': '光标上移',
      'cursor_down': '光标下移',
      'line_start': '移动至行首',
      'line_end': '移动至行尾',
      'page_start': '移动至文首',
      'page_end': '移动至文末',
      'copy': '复制',
      'cut': '剪切',
      'paste': '粘贴',
      'delete': '删除',
      'select_all': '全选',
      'keyboard_hide': '收起小键盘',
      'other': '$command',
    });
    return '$_temp0';
  }

  @override
  String get keyboardModifierPresetFormField => '终端修饰键';

  @override
  String keyboardModifierName(String modifier) {
    String _temp0 = intl.Intl.selectLogic(modifier, {
      'ctrl': 'Ctrl 键',
      'alt': 'Alt 键',
      'shift': 'Shift 键',
      'other': '$modifier',
    });
    return '$_temp0';
  }

  @override
  String get keyboardCursorOffsetFormField => '光标相对偏移';

  @override
  String get keyboardCursorOffsetRequiredError => '请输入光标偏移（通常为 -1）';

  @override
  String get keyboardCursorOffsetIntegerError => '偏移量必须为整数';

  @override
  String get recommended => '推荐';

  @override
  String get presetColors => '预设颜色';

  @override
  String get hexColor => '十六进制颜色';

  @override
  String get currentColor => '当前';

  @override
  String get newColor => '预览';

  @override
  String get runTasks => '运行任务';

  @override
  String get projectDetect => '项目探测';

  @override
  String get projectDetecting => '正在探测项目...';

  @override
  String get editRunTasks => '运行任务编辑';

  @override
  String get projectSection => '项目';

  @override
  String get showHiddenFiles => '显示隐藏文件';

  @override
  String get showHiddenFilesSubtitle => '在文件树中展示以点 (.) 开头的隐藏文件与文件夹';

  @override
  String get searchTasksHint => '搜索指定任务...';

  @override
  String get noTasksAvailable => '暂无可执行任务';

  @override
  String get noMatchingTasks => '无匹配的任务';

  @override
  String get userCustomTasks => '用户自定义任务';

  @override
  String get systemDetectedTasks => '系统动态探测任务';

  @override
  String get resyncModuleTasks => '重新同步真实任务';

  @override
  String get syncingTasks => '正在后台自省任务...';

  @override
  String get editCustomTasksTooltip => '编辑自定义任务';

  @override
  String get runTasksConfig => '运行任务配置';

  @override
  String get editTask => '编辑任务';

  @override
  String get addTask => '新增任务';

  @override
  String get runTasksConfigSubtitle =>
      '配置将自动保存至项目根目录下的 .code_editor/run_tasks.json';

  @override
  String get noCustomTasksInProject => '当前项目暂无自定义任务';

  @override
  String get createNow => '立即创建';

  @override
  String get saveAndApply => '保存并应用';

  @override
  String get taskNameRequired => '任务名称 *';

  @override
  String get taskNameHint => '如: 编译并运行 Debug';

  @override
  String get taskNameEmptyError => '请输入任务名称';

  @override
  String get shellCommandRequired => 'Shell 执行指令 *';

  @override
  String get shellCommandHint => '如: cmake -B build && cmake --build build';

  @override
  String get shellCommandEmptyError => '请输入执行指令';

  @override
  String get taskDescOptional => '任务描述（选填）';

  @override
  String get taskDescHint => '简要说明此任务的用途';

  @override
  String get clearBeforeRun => '执行前清屏';

  @override
  String get clearBeforeRunSubtitle => '在终端输出任务结果前清理历史屏幕';

  @override
  String get runTasksUpdated => '运行任务配置已更新';

  @override
  String detectCompletedMessage(int count) {
    return '探测完成，发现 $count 个可用任务';
  }

  @override
  String get pleaseOpenProjectFirst => '请先打开一个项目';

  @override
  String deleteTaskConfirmMessage(String name) {
    return '确定要删除任务 \"$name\" 吗？';
  }

  @override
  String deleteSelectedTasksConfirmMessage(int count) {
    return '确定要删除选中的 $count 个任务吗？';
  }

  @override
  String get deleteSelected => '删除选中';

  @override
  String get selectTasksToDelete => '选择要删除的任务';

  @override
  String selectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get unsavedTaskChangesTitle => '未保存的任务更改';

  @override
  String get unsavedTaskChangesMessage => '当前任务内容已被修改，是否放弃未保存的修改并返回？';

  @override
  String get downloadSection => '下载';

  @override
  String get downloadSource => '下载源';

  @override
  String get selectDownloadSource => '选择下载源';

  @override
  String mirrorName(String mirror) {
    String _temp0 = intl.Intl.selectLogic(mirror, {
      'tsinghua': '清华大学开源软件镜像站 (推荐)',
      'bfsu': '北京外国语大学开源软件镜像站',
      'iscas': '中国科学院软件研究所开源镜像站',
      'official': 'LinuxContainers 官方镜像源',
      'other': '$mirror',
    });
    return '$_temp0';
  }

  @override
  String get unnamedTask => '未命名任务';

  @override
  String get shellCommandHelperText => '支持单行指令（如 make）或多行 Shell 脚本（自动封装执行）';

  @override
  String get detectedTaskCmakeBuildRunDesc => '配置、编译并尝试启动生成的目标程序';

  @override
  String get detectedTaskCmakeBuildDesc => '仅执行 cmake 生成与构建';

  @override
  String get detectedTaskCmakeCleanDesc => '清理构建缓存目录';

  @override
  String get detectedTaskGradleRunDesc => '执行应用程序主入口';

  @override
  String get detectedTaskGradleAssembleDesc => '构建调试输出包';

  @override
  String get detectedTaskGradleBuildDesc => '执行完整构建与测试';

  @override
  String get detectedTaskMakeDefaultDesc => '执行默认 Makefile 构建目标';

  @override
  String get detectedTaskNpmStartDesc => '启动 Node 服务或前端开发环境';

  @override
  String get detectedTaskNpmTestDesc => '执行 npm test 测试套件';

  @override
  String get detectedTaskCargoRunDesc => '编译并运行 Rust 项目';

  @override
  String get detectedTaskCargoBuildDesc => '仅编译 Rust 项目';

  @override
  String get detectedTaskDartRunDesc => '启动 Dart 应用';

  @override
  String get detectedTaskSinglePythonDesc => '运行当前 Python 脚本';

  @override
  String get detectedTaskSingleCDesc => '编译并执行当前 C 源文件';

  @override
  String get detectedTaskSingleCppDesc => '编译并执行当前 C++ 源文件';

  @override
  String get detectedTaskSingleShDesc => '运行当前 Shell 脚本';

  @override
  String get detectedTaskSingleDartDesc => '运行当前 Dart 文件';

  @override
  String get detectedTaskSingleGoDesc => '运行当前 Go 源文件';

  @override
  String get detectedTaskSingleRustDesc => '编译并执行当前 Rust 源文件';

  @override
  String get detectedTaskSingleJsDesc => '运行当前 JS 脚本';

  @override
  String get detectedTaskSingleJavaDesc => '直接运行当前 Java 源文件';

  @override
  String get detectedTaskSingleTsDesc => '运行当前 TypeScript 脚本';

  @override
  String get detectedTaskSingleLuaDesc => '运行当前 Lua 脚本';

  @override
  String get detectedTaskSinglePerlDesc => '运行当前 Perl 脚本';

  @override
  String get detectedTaskSinglePhpDesc => '运行当前 PHP 脚本';

  @override
  String get detectedTaskPythonPipInstallDesc => '安装项目 requirements 依赖包';

  @override
  String get detectedTaskPythonRunMainDesc => '执行 Python 项目主程序';

  @override
  String get detectedTaskPythonPytestDesc => '运行 pytest 测试用例';

  @override
  String get detectedTaskMavenPackageDesc => '打包 Maven 项目 (mvn package)';

  @override
  String get detectedTaskMavenCompileDesc => '编译 Maven 项目源码 (mvn compile)';

  @override
  String get detectedTaskMavenTestDesc => '运行 Maven 单元测试 (mvn test)';

  @override
  String get detectedTaskMavenCleanDesc => '清理 Maven 目标输出目录 (mvn clean)';

  @override
  String get missingDistroTitle => '系统环境未就绪';

  @override
  String get noDistroAvailableContent =>
      '未检测到可用的 Linux 执行环境。\n\n工程任务需要在 Linux 容器环境中运行。请先安装或下载 Linux 系统（如 Ubuntu 或 Alpine）。';

  @override
  String distroNotInstalledContent(String distro) {
    return '系统 \"$distro\" 尚未安装或已被清理。\n\n请在系统管理中安装该系统，或选择其他已就绪的系统。';
  }

  @override
  String get openFromApp => '从软件内打开';

  @override
  String get openFromExternal => '从外部打开';

  @override
  String get projectsTitle => '项目';

  @override
  String get newProject => '新建项目';

  @override
  String get newProjectTitle => '新建项目';

  @override
  String get projectNameHint => '请输入项目名称';

  @override
  String get renameProject => '重命名项目';

  @override
  String get deleteProject => '删除项目';

  @override
  String deleteProjectConfirmMessage(String name) {
    return '确定要删除项目 \"$name\" 吗？此操作不可逆。';
  }

  @override
  String get projectAlreadyExists => '已存在同名项目';

  @override
  String get noProjects => '暂无项目，点击右上角新建项目';

  @override
  String get projectCreated => '项目创建成功';

  @override
  String get projectRenamed => '项目重命名成功';

  @override
  String get projectDeleted => '项目已删除';

  @override
  String get importFromExternal => '从外部导入';

  @override
  String get confirmProjectNameTitle => '确认项目名称';

  @override
  String get importingProject => '正在导入项目...';

  @override
  String get projectImported => '项目导入成功';

  @override
  String importProjectFailed(String error) {
    return '导入项目失败: $error';
  }

  @override
  String get unsupportedProjectArchiveFormat =>
      '不支持的文件格式，仅支持压缩包格式 (.zip, .tar.gz, .tar.xz, .tar 等)';

  @override
  String get unsupportedDistroArchiveFormat =>
      '不支持的文件格式，仅支持系统镜像包 (.tar.gz, .tar.xz, .tar)';

  @override
  String get exportProject => '导出项目';

  @override
  String get exportProjectTooltip => '导出为 ZIP 压缩包';

  @override
  String get exportingProject => '正在压缩并导出项目...';

  @override
  String get projectExported => '项目导出成功';

  @override
  String exportProjectFailed(String error) {
    return '导出项目失败: $error';
  }

  @override
  String get selectExportDirectory => '选择导出目标文件夹';

  @override
  String targetFileAlreadyExists(String name) {
    return '目标文件 \"$name\" 已存在，是否覆盖？';
  }

  @override
  String get overwrite => '覆盖';

  @override
  String get batteryOptimizationTitle => '后台运行与电池优化';

  @override
  String get batteryOptimizationMessage =>
      '为了保证终端会话在后台不被系统强行终止，建议将本应用的电池优化设置为“无限制”或关闭电池优化。\n\n是否前往系统设置进行配置？';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String probeBannerPreparing(String module) {
    return '正在准备 $module 探测环境…';
  }

  @override
  String probeBannerDetecting(String module) {
    return '正在探测 $module 任务…';
  }

  @override
  String get probeBannerFinalizing => '正在整理探测结果…';

  @override
  String probePhaseQueued(String module) {
    return '$module 排队等待中…';
  }

  @override
  String probePhaseCheckingDependency(String module) {
    return '正在检查 $module 依赖…';
  }

  @override
  String probePhaseInstallingDependency(String module) {
    return '正在安装 $module 依赖…';
  }

  @override
  String probeDoneWithCount(String module, int count) {
    return '$module 探测完成 · 发现 $count 个任务';
  }

  @override
  String probeFailureDependencyInstallFailed(String tool) {
    return '依赖 $tool 自动安装失败';
  }

  @override
  String get taskTypeSingleFile => '当前文件任务';

  @override
  String get taskTypeOther => '其他任务';

  @override
  String get probeAlreadyRunning => '正在探测中，请稍候…';

  @override
  String get probeBusyEnterTerminalTitle => '任务探测进行中';

  @override
  String get probeBusyEnterTerminalMessage =>
      '项目任务探测正在后台进行（会占用当前容器执行构建工具自省与依赖安装）。\n\n此时进入终端并进行安装软件包、构建等操作，可能与探测互相阻塞或产生异常。\n\n是否仍要进入终端？';

  @override
  String get probeEnterTerminalAnyway => '继续进入终端';

  @override
  String get probeCancelConfirmTitle => '取消本次探测？';

  @override
  String get probeCancelConfirmMessage =>
      '正在进行的探测会被立即中止：已完成模块的结果会保留，未完成的模块将被跳过。';

  @override
  String get probeKeepDetecting => '继续探测';

  @override
  String get cancelProbe => '取消探测';

  @override
  String get probeBudgetExceededTitle => '探测超时已中止';

  @override
  String probeBudgetExceededMessage(int completed, int total) {
    return '已完成 $completed/$total 个模块，剩余模块本次跳过。可稍后重新探测。';
  }

  @override
  String get probeBannerClose => '关闭';

  @override
  String probeDone(String module) {
    return '$module 任务探测完成';
  }

  @override
  String probeFailedTitle(String module) {
    return '$module 任务探测失败';
  }

  @override
  String probeFailureToolchainMissing(String tool) {
    return '当前系统内未找到 $tool，请先在系统管理中安装';
  }

  @override
  String probeFailureExecutionFailed(String detail) {
    return '构建工具执行失败：$detail';
  }

  @override
  String get probeFailureUnparsable => '无法识别构建工具输出（可能版本不兼容）';

  @override
  String get probeFailureTimeout => '探测超时，已中止';

  @override
  String noticeQueueMore(int count) {
    return '还有 $count 项进行中';
  }

  @override
  String importFilesSuccess(int count) {
    return '成功导入 $count 个文件';
  }

  @override
  String importFilesFailed(String error) {
    return '导入文件失败: $error';
  }

  @override
  String get codeCompletionManagement => '代码补全管理';

  @override
  String get codeCompletionSubtitle => '管理各编程语言的智能补全与报错工具链';

  @override
  String get completionSourceSection => '补全数据源与开关';

  @override
  String get localCompletionTitle => '本地基础补全';

  @override
  String get localCompletionSubtitle => '包含语言内置关键字与当前文档词法启发式提取';

  @override
  String get lspCompletionTitle => '后端语言服务补全';

  @override
  String get lspCompletionSubtitle => '向后台编译器守护进程请求真实语义类型与函数参数补全';

  @override
  String get internalEngineTitle => '代码运行与智能补全引擎 (Ubuntu)';

  @override
  String get internalEngineStatusReady => '引擎已就绪';

  @override
  String get internalEngineStatusNotReady => '引擎未启动';

  @override
  String get internalEngineExtracting => '正在准备内置 Ubuntu 开发环境与智能补全引擎...';

  @override
  String get installComponent => '安装组件';

  @override
  String installingComponent(String pkg) {
    return '正在安装 $pkg...';
  }

  @override
  String installComponentSuccess(String name) {
    return '$name 组件安装成功';
  }

  @override
  String installComponentFailed(String error) {
    return '组件安装失败: $error';
  }

  @override
  String uninstallingComponent(String pkg) {
    return '正在卸载 $pkg 并清理配置...';
  }

  @override
  String get editLanguageConfig => '编辑语言配置';

  @override
  String get addLanguageConfig => '新增语言配置';

  @override
  String get deleteLanguageConfirmTitle => '删除语言配置';

  @override
  String deleteLanguageConfirmMessage(String name) {
    return '确定要删除 $name 的代码补全配置吗？';
  }

  @override
  String deleteLanguageWithPackageConfirmMessage(String name) {
    return '确定要删除 $name 的代码补全配置吗？已安装的软件包将一并卸载。';
  }

  @override
  String get resetDefaultLanguages => '恢复默认配置';

  @override
  String get resetDefaultLanguagesConfirm => '确定将所有语言配置重置为官方默认预设吗？';

  @override
  String get languageDisplayName => '语言名称';

  @override
  String get languageDisplayNameHint => '例如: C / C++';

  @override
  String get languageIdField => '语言标识 (Language ID)';

  @override
  String get languageIdFieldHint => '用于 LSP 协议识别，如 cpp, rust';

  @override
  String get fileExtensionsField => '文件后缀';

  @override
  String get fileExtensionsFieldHint => '以逗号分隔，如 .c, .cpp, .h';

  @override
  String get serverCommandField => '服务启动命令';

  @override
  String get serverCommandFieldHint => '例如: clangd';

  @override
  String get serverArgsField => '启动参数';

  @override
  String get serverArgsFieldHint => '多个参数以空格或逗号分隔';

  @override
  String get apkPackageField => 'Ubuntu 依赖包名 (APT)';

  @override
  String get apkPackageFieldHint => '用于一键安装，如 clangd 或 python3-pylsp';

  @override
  String lspPackageMissingTitle(String language) {
    return '未安装 $language 代码智能组件';
  }

  @override
  String get lspPackageMissingMessage => '安装组件即可获得精准代码补全与错误检查';

  @override
  String get installNow => '一键安装';

  @override
  String get fieldRequired => '此项不能为空';

  @override
  String get languageConfigSaved => '语言配置已保存';

  @override
  String get enable => '启用';

  @override
  String get disable => '停用';

  @override
  String get edit => '编辑';

  @override
  String componentQueued(String name) {
    return '$name 排队等待中…';
  }

  @override
  String uninstallComponentSuccess(String name) {
    return '$name 组件卸载成功';
  }

  @override
  String uninstallComponentFailed(String error) {
    return '组件卸载失败: $error';
  }

  @override
  String get installingStatus => '正在安装…';

  @override
  String get uninstallingStatus => '正在卸载…';

  @override
  String get emptyLspLanguagesTitle => '暂无已安装的代码智能组件';

  @override
  String get emptyLspLanguagesSubtitle =>
      '在编辑器中打开代码文件即可按需触发安装，或点击右上角 \"+\" 手动添加';

  @override
  String lspQuickFixTitle(int line) {
    return '代码问题与修复 (第 $line 行)';
  }

  @override
  String get lspNoFixAvailable => '当前报错未提供自动修复动作';

  @override
  String diagnosticLinePrefix(int line, String message) {
    return '行 $line: $message';
  }

  @override
  String get quickFixButton => '修复';

  @override
  String get containerSection => '容器';

  @override
  String get destroyAndRebuildContainer => '销毁并重建容器';

  @override
  String get destroyAndRebuildContainerSubtitle => '清空容器内已安装环境并重新解压纯净容器';

  @override
  String get destroyContainerConfirmTitle => '销毁并重建容器';

  @override
  String get destroyContainerConfirmMessage =>
      '此操作将永久清空当前 Ubuntu 容器内的所有已安装软件包和环境配置（工程文件不受影响），并重新解压纯净容器系统。确定要继续吗？';

  @override
  String get destroyContainerButton => '销毁并重建';

  @override
  String get containerRebuiltSuccess => '容器已成功重建';

  @override
  String containerRebuildFailed(String error) {
    return '容器重建失败: $error';
  }

  @override
  String get containerRuntimeMode => '容器运行模式';

  @override
  String get containerRuntimeModeAuto => '自动';

  @override
  String get containerRuntimeModeProot => 'PRoot';

  @override
  String get containerRuntimeModeChroot => 'Chroot';

  @override
  String get selectContainerRuntimeMode => '选择容器运行模式';

  @override
  String containerRuntimeToast(String mode) {
    return '当前容器运行环境：$mode';
  }

  @override
  String get chrootDisabledNoRoot => '未授予 Root 权限不可用';

  @override
  String get chrootFailedFallbackToProot => 'Chroot 挂载或权限失败，已自动降级为 PRoot 运行模式';
}
