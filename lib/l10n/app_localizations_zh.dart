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

  @override
  String get drawerTabExplorer => '文件';

  @override
  String get drawerTabSearch => '搜索';

  @override
  String get drawerTabGit => '源代码管理';

  @override
  String get searchHint => '搜索';

  @override
  String get replaceHint => '替换';

  @override
  String get matchCase => '区分大小写';

  @override
  String get matchWholeWord => '全字匹配';

  @override
  String get useRegularExpression => '使用正则表达式';

  @override
  String get invalidRegularExpression => '无效的正则表达式';

  @override
  String get projectDirectoryNotFound => '项目目录不存在';

  @override
  String get searchMoreOptions => '更多选项';

  @override
  String get searchModeText => '内容搜索';

  @override
  String get searchModeFileName => '文件名搜索';

  @override
  String get replaceAllInFile => '替换此文件中的所有匹配项';

  @override
  String get replaceAllInProject => '全部替换';

  @override
  String get replaceSingleMatch => '替换';

  @override
  String searchResultStats(int fileCount, int matchCount) {
    return '在 $fileCount 个文件中找到 $matchCount 处匹配';
  }

  @override
  String get noSearchResults => '未找到匹配项';

  @override
  String searchError(String error) {
    return '搜索失败: $error';
  }

  @override
  String replaceSuccess(int count) {
    return '已替换 $count 处匹配';
  }

  @override
  String get expandAll => '全部展开';

  @override
  String get collapseAll => '全部折叠';

  @override
  String searchLoadMoreFiles(int count) {
    return '加载更多文件 (还有 $count 个)';
  }

  @override
  String searchLoadMoreMatches(int count) {
    return '加载更多匹配项 (还有 $count 项)';
  }

  @override
  String get confirmReplaceAllTitle => '全部替换确认';

  @override
  String confirmReplaceAllMessage(
    int matchCount,
    int fileCount,
    String replaceText,
  ) {
    return '确定要在整个项目（共 $fileCount 个文件）中将全部 $matchCount 处匹配替换为 \"$replaceText\" 吗？此操作将直接修改磁盘文件。';
  }

  @override
  String get confirmReplaceFileTitle => '替换文件匹配项确认';

  @override
  String confirmReplaceFileMessage(
    String fileName,
    int matchCount,
    String replaceText,
  ) {
    return '确定要在 \"$fileName\" 中将全部 $matchCount 处匹配替换为 \"$replaceText\" 吗？';
  }

  @override
  String get gitNotInstalled => '未检测到 Git';

  @override
  String get gitNotInstalledDesc =>
      '系统中未检测到 Git 命令行工具。请在系统终端或 Linux 容器中安装 git（如执行 apt update && apt install -y git）。';

  @override
  String get gitNeedInstall => '需要安装 Git';

  @override
  String get gitInstallAction => '安装 Git';

  @override
  String get gitInstallingProgress => '正在安装 Git...';

  @override
  String get gitInstallSuccess => 'Git 安装成功';

  @override
  String gitInstallFailed(String error) {
    return 'Git 安装失败: $error';
  }

  @override
  String get gitNoRepoFound => '当前工程尚未初始化为 Git 仓库';

  @override
  String get gitNoRepoDesc => '初始化本地 Git 仓库后，即可使用版本控制、分支管理及变更追踪功能。';

  @override
  String get gitInitRepo => '初始化 Git 仓库';

  @override
  String get gitInitializing => '正在初始化 Git 仓库...';

  @override
  String get gitInitSuccess => 'Git 仓库初始化成功';

  @override
  String gitInitFailed(String error) {
    return 'Git 仓库初始化失败: $error';
  }

  @override
  String get gitRepository => '仓库';

  @override
  String gitCurrentBranch(String branch) {
    return '当前分支: $branch';
  }

  @override
  String get gitSwitchRepo => '切换仓库';

  @override
  String get gitRefresh => '刷新 Git 状态';

  @override
  String get gitChanges => '更改';

  @override
  String get gitStagedChanges => '暂存的更改';

  @override
  String get gitNoChanges => '暂无任何文件更改';

  @override
  String get gitStatusUntracked => '未跟踪';

  @override
  String get gitStatusModified => '已修改';

  @override
  String get gitStatusAdded => '新增';

  @override
  String get gitStatusDeleted => '已删除';

  @override
  String get gitStatusRenamed => '重命名';

  @override
  String get gitStatusConflict => '冲突';

  @override
  String gitMultipleReposDetected(int count) {
    return '检测到多个 Git 仓库 ($count)';
  }

  @override
  String get gitStageChange => '暂存更改';

  @override
  String get gitUnstageChange => '取消暂存更改';

  @override
  String get gitStageAll => '全部暂存更改';

  @override
  String get gitUnstageAll => '全部取消暂存更改';

  @override
  String get gitStageSuccess => '已暂存';

  @override
  String get gitUnstageSuccess => '已取消暂存';

  @override
  String get gitCommit => '提交';

  @override
  String get gitCommitMessageHint => '提交信息';

  @override
  String get gitCommitSuccess => '提交成功';

  @override
  String gitCommitFailed(String error) {
    return '提交失败: $error';
  }

  @override
  String get gitDiscardChange => '放弃更改';

  @override
  String get gitDiscardConfirm => '放弃更改？';

  @override
  String gitDiscardConfirmDesc(String fileName) {
    return '确定要放弃对 \"$fileName\" 的所有未暂存更改吗？此操作无法撤销。';
  }

  @override
  String get gitNoCommitMessage => '请输入提交信息';

  @override
  String get gitNoStagedChangesToCommit => '暂存区没有已暂存的更改，是否全部暂存并直接提交？';

  @override
  String get gitStageAllAndCommit => '全部暂存并提交';

  @override
  String get gitGraphTitle => '图表';

  @override
  String get gitNoCommits => '暂无提交历史';

  @override
  String get gitCommitDetails => '提交详情';

  @override
  String get gitCommitAuthor => '作者';

  @override
  String get gitCommitDate => '提交日期';

  @override
  String get gitCommitHash => '提交哈希';

  @override
  String get gitCopyHash => '复制哈希';

  @override
  String get gitHashCopied => '已复制提交哈希到剪贴板';

  @override
  String get gitCommitParent => '父提交';

  @override
  String get gitDiscardAll => '全部放弃更改';

  @override
  String get gitDiscardAllChangesTitle => '放弃所有未暂存更改？';

  @override
  String get gitDiscardAllChangesConfirm =>
      '确定要放弃所有未暂存更改吗？所有已修改的文件将恢复，未跟踪的新文件将被清除，此操作无法撤销。';

  @override
  String get gitDiscardAllStagedTitle => '放弃所有已暂存更改？';

  @override
  String get gitDiscardAllStagedConfirm =>
      '确定要放弃所有已暂存的更改吗？所选文件的修改将被彻底恢复，此操作无法撤销。';

  @override
  String get gitBranches => '分支';

  @override
  String get gitCreateBranch => '创建新分支';

  @override
  String get gitBranchNameHint => '输入新分支名称';

  @override
  String gitSwitchBranchSuccess(String branch) {
    return '已切换至分支 $branch';
  }

  @override
  String gitCreateBranchSuccess(String branch) {
    return '已创建并切换至新分支 $branch';
  }

  @override
  String get gitDeleteBranch => '删除分支';

  @override
  String gitDeleteBranchConfirm(String branch) {
    return '确定要删除本地分支 $branch 吗？';
  }

  @override
  String gitDeleteBranchSuccess(String branch) {
    return '已删除分支 $branch';
  }

  @override
  String get gitCannotDeleteCurrentBranch => '无法删除当前所在分支';

  @override
  String get gitUndoLastCommit => '撤销上次提交';

  @override
  String get gitUndoLastCommitConfirm => '确定要撤销上一次提交吗？代码更改将保留在暂存区。';

  @override
  String get gitUndoLastCommitSuccess => '已撤销上一次提交';

  @override
  String get gitStash => '贮藏';

  @override
  String get gitStashChanges => '贮藏当前更改';

  @override
  String get gitStashChangesSuccess => '已将当前更改暂存至贮藏栈';

  @override
  String get gitStashPop => '恢复最近贮藏 (Pop)';

  @override
  String get gitStashPopSuccess => '已恢复最近的贮藏更改';

  @override
  String get gitNoStashFound => '当前没有可恢复的贮藏记录';

  @override
  String get gitAddToGitignore => '添加到 .gitignore';

  @override
  String get gitAddedToGitignore => '已添加至 .gitignore';

  @override
  String get gitMoreActions => '更多操作';

  @override
  String get gitOpenFile => '打开文件';

  @override
  String get gitTags => '标签';

  @override
  String get gitCreateTag => '创建新标签';

  @override
  String get gitTagNameHint => '输入标签名称 (例如 v1.0.0)';

  @override
  String get gitTagMessageHint => '标签附注信息 (可选)';

  @override
  String get gitDeleteTag => '删除标签';

  @override
  String gitDeleteTagConfirm(String tag) {
    return '确定要删除本地标签 $tag 吗？';
  }

  @override
  String gitCreateTagSuccess(String tag) {
    return '已创建标签 $tag';
  }

  @override
  String gitDeleteTagSuccess(String tag) {
    return '已删除标签 $tag';
  }

  @override
  String gitSwitchTagSuccess(String tag) {
    return '已检出至标签 $tag';
  }

  @override
  String get gitNoTags => '暂无标签';

  @override
  String get gitSelectBranchToDelete => '选择要删除的分支';

  @override
  String get gitSelectTagToDelete => '选择要删除的标签';

  @override
  String get gitSearchBranches => '搜索分支...';

  @override
  String get gitSearchTags => '搜索标签...';

  @override
  String get gitNoBranches => '暂无分支';

  @override
  String get gitRemoteBranches => '远端分支';

  @override
  String get gitLocalBranches => '本地分支';

  @override
  String get gitNoRemoteBranches => '暂无远端分支，请先执行抓取';

  @override
  String get gitCheckoutRemoteBranch => '检出为本地分支';

  @override
  String get gitRemoteBranchCheckedOut => '该远端分支已在本地检出';

  @override
  String gitCheckoutRemoteBranchSuccess(String remote, String branch) {
    return '已基于 $remote 创建并切换到本地分支 $branch';
  }

  @override
  String get gitSearchRemoteBranches => '搜索远端分支...';

  @override
  String get gitRepairCheck => '仓库自检';

  @override
  String get gitRepairCheckRunning => '正在自检...';

  @override
  String get gitRepairCheckHealthy => '仓库完整，未发现对象丢失';

  @override
  String get gitRepairCheckHealthyHint => '对象库校验通过，可以正常提交与同步。';

  @override
  String gitRepairCheckObjectLoss(int count) {
    return '检测到对象丢失（$count 处问题）';
  }

  @override
  String get gitRepairCheckObjectLossHint =>
      '这类损坏会导致提交时报错 Error building trees。常见原因是容器被重建导致 .git/objects 丢失。建议先备份项目目录，再按下方提示处理。';

  @override
  String gitRepairCheckDangling(int count) {
    return '另有 $count 个悬空对象（正常现象，无需处理）';
  }

  @override
  String get gitRepairCheckFailed => '自检未能完成';

  @override
  String get gitRepairCheckFailedHint => '可能因为仓库过大或执行超时，可稍后重试。';

  @override
  String get gitRepairCheckRerun => '重新自检';

  @override
  String get gitRepairAdviceTitle => '如何处理';

  @override
  String get gitRepairAdviceRemoveStale =>
      '未提交的损坏条目：执行 git reset 让索引与最后一次提交对齐，然后重新暂存需要的文件。';

  @override
  String get gitRepairAdviceRestore => '已提交的历史损坏：需要从远端重新克隆，或从其他副本恢复。';

  @override
  String get gitClone => '克隆远程仓库';

  @override
  String get gitCloneUrl => '仓库地址';

  @override
  String get gitCloneUrlHint => 'https://github.com/user/repo.git';

  @override
  String get gitCloneDirName => '本地目录名';

  @override
  String get gitCloneDirNameHint => '留空则从地址自动推导';

  @override
  String get gitCloneBranch => '指定分支（可选）';

  @override
  String get gitCloneBranchHint => '留空则使用远端默认分支';

  @override
  String get gitCloneDepth => '浅克隆深度（可选）';

  @override
  String get gitCloneDepthHint => '如 1 表示只克隆最近 1 个提交';

  @override
  String get gitCloneUrlRequired => '请输入仓库地址';

  @override
  String get gitCloneDirRequired => '请输入本地目录名';

  @override
  String get gitCloneDirExists => '目录已存在，请换一个名字';

  @override
  String get gitCloneRunning => '正在克隆...';

  @override
  String gitCloneSuccess(String name) {
    return '克隆完成：$name';
  }

  @override
  String get gitCloneFailed => '克隆失败';

  @override
  String get gitCloneCancel => '取消克隆';

  @override
  String gitPushTargetTooltip(String name, String reason) {
    return '推送目标：$name\n$reason';
  }

  @override
  String get gitPushReasonPushRemote => '由分支配置 branch.*.pushRemote 决定';

  @override
  String get gitPushReasonPushDefault => '由仓库配置 remote.pushDefault 决定';

  @override
  String get gitPushReasonUpstream => '当前分支的上游远程';

  @override
  String get gitPushReasonBranchRemote => '由分支配置 branch.*.remote 决定';

  @override
  String get gitPushReasonFallback => '默认远程（origin 优先）';

  @override
  String get gitPushReasonOverridden => '你已在本次会话中手动切换';

  @override
  String gitFetchTargetTooltip(String name) {
    return '抓取目标：$name';
  }

  @override
  String get gitTogglePushTarget => '选择推送目标';

  @override
  String get gitSyncCloudTooltip => '同步：抓取 / 拉取 / 推送';

  @override
  String gitPushTargetChanged(String name) {
    return '推送目标已切换为 $name';
  }

  @override
  String get gitPushTargetDiffers => '推送目标与上游不同';

  @override
  String gitPushTargetDiffersNotice(String upstream, String push) {
    return '拉取走 $upstream，推送走 $push';
  }

  @override
  String get gitRemoteRoleUpstream => '上游（拉取）';

  @override
  String get gitErrAuthFailed => '认证失败：令牌无效、已过期或用户名不匹配';

  @override
  String get gitErrAuthFailedHint => '请到「Git 账号管理」检查令牌是否有效，并确认账号用户名与平台登录名一致。';

  @override
  String get gitErrWritePermissionDenied => '当前账号对该仓库没有写权限';

  @override
  String get gitErrWritePermissionDeniedHint =>
      '若这是别人的仓库（上游），请先 Fork 到你自己的账号，再把远端地址改为你的 Fork（如 https://github.com/你的用户名/仓库.git）。';

  @override
  String get gitErrRepositoryNotFound => '仓库不存在，或当前账号无权访问';

  @override
  String get gitErrRepositoryNotFoundHint =>
      'GitHub 对「无权限」和「不存在」都返回 404。请确认远端地址拼写正确，且该令牌有权访问该仓库。';

  @override
  String get gitErrProxyAuthRequired => '网络代理需要认证';

  @override
  String get gitErrProxyAuthRequiredHint =>
      '当前网络经过需要认证的代理（HTTP 407）。请检查容器内代理配置与凭据。';

  @override
  String get gitErrRequestRejected => '服务器拒绝了本次请求';

  @override
  String get gitErrRequestRejectedHint =>
      '通常表示推送内容或分支引用不合法（HTTP 422），例如分支名不符合平台规则或提交信息被策略拦截。';

  @override
  String get gitErrRateLimited => '请求过于频繁，已被平台限流';

  @override
  String get gitErrRateLimitedHint => '请稍等几分钟后重试（HTTP 429）。短时间内反复重试会延长限制时间。';

  @override
  String get gitErrHttpError => '服务器返回了错误状态码';

  @override
  String get gitErrHttpErrorHint =>
      '请根据下方状态码排查：401 令牌无效、403 无权限、404 仓库不存在或无权访问、407 需要代理认证、429 被限流。';

  @override
  String get gitErrPasswordAuthDisabled => '该平台已禁用账号密码认证';

  @override
  String get gitErrPasswordAuthDisabledHint =>
      '请在「Git 账号管理」中使用个人访问令牌 (PAT) 重新添加账号。';

  @override
  String get gitErrNetworkUnreachable => '网络无法连接到远端服务器';

  @override
  String get gitErrNetworkUnreachableHint =>
      '请检查网络连接，以及容器内 DNS 配置（/etc/resolv.conf）是否正常。';

  @override
  String get gitErrSshPublicKeyDenied => 'SSH 公钥认证被拒绝';

  @override
  String get gitErrSshPublicKeyDeniedHint =>
      '请确认容器内的公钥已添加到平台的 SSH Keys 中，或改用 HTTPS + 访问令牌。';

  @override
  String get gitErrSshKeyUnusable => 'SSH 私钥无法使用（权限或格式异常）';

  @override
  String get gitErrSshKeyUnusableHint => '私钥权限需为 600。可在「Git 账号管理」中重新生成密钥对。';

  @override
  String get gitErrHostKeyUnverified => '目标服务器的主机指纹尚未确认，连接被中断';

  @override
  String get gitErrHostKeyUnverifiedHint =>
      '首次连接需要确认主机指纹。若刚更换过服务器密钥，请清理容器内 ~/.ssh/known_hosts 后重试。';

  @override
  String get gitErrNonFastForward => '推送被拒绝：远端存在本地尚无的提交';

  @override
  String get gitErrNonFastForwardHint => '请先执行 Pull（rebase 方式）合并远端改动，再重新推送。';

  @override
  String get gitErrStaleForcePush => '强推被拒绝：远端分支已被他人更新';

  @override
  String get gitErrStaleForcePushHint => '请先执行 Fetch 获取最新远端状态，确认差异后再强制推送。';

  @override
  String get gitErrConflictDetected => '合并/rebase 出现冲突，需要手动解决';

  @override
  String get gitErrConflictDetectedHint =>
      '请逐个解决冲突文件，或放弃本次操作（git rebase --abort）。';

  @override
  String get gitErrLocalChanges => '本地未提交的改动会被覆盖，操作已中止';

  @override
  String get gitErrLocalChangesHint => '请先提交改动，或将其贮藏（stash）后再执行。';

  @override
  String get gitErrNoUpstream => '当前分支尚未关联远端分支';

  @override
  String get gitErrNoUpstreamHint => '请使用「发布分支」将本地分支推送到远端并建立追踪关系。';

  @override
  String get gitErrRefLockFailed => 'Git 引用文件被占用（存在残留锁）';

  @override
  String get gitErrRefLockFailedHint =>
      '可能有另一个 Git 进程正在运行。稍后重试，或清理 .git 目录下的 .lock 文件。';

  @override
  String get gitErrOutOfSpace => '设备存储空间不足';

  @override
  String get gitErrOutOfSpaceHint => '请清理容器或设备空间后重试。';

  @override
  String get gitErrTimeout => '操作超时';

  @override
  String get gitErrTimeoutHint => '仓库较大或网络较慢时可能超时。可改用终端观察进度，或在网络较好时重试。';

  @override
  String get gitErrIncomplete => '操作未完成，但没有返回具体错误信息';

  @override
  String get gitErrIncompleteHint =>
      '通常是被超时或网络中断打断。仓库较大时建议改用终端执行 fetch 观察进度，或稍后在网络较好时重试。';

  @override
  String get gitErrUnknown => 'Git 操作失败';

  @override
  String get gitErrUnknownHint => '请展开下方原始输出查看详细信息。';

  @override
  String get gitRawOutput => '原始输出';

  @override
  String gitElapsed(String time) {
    return '已用 $time';
  }

  @override
  String gitElapsedMinutesSeconds(int minutes, String seconds) {
    return '$minutes:$seconds';
  }

  @override
  String get gitFetch => '抓取';

  @override
  String get gitFetchTooltip => '从远端抓取最新提交（不合并到本地）';

  @override
  String get gitPull => '拉取';

  @override
  String get gitPullTooltip => '拉取远端提交并以 rebase 方式合并到当前分支';

  @override
  String get gitPush => '推送';

  @override
  String get gitPushTooltip => '将本地提交推送到远端';

  @override
  String get gitPublishBranch => '发布分支';

  @override
  String get gitPublishBranchTooltip => '将本地分支推送到远端并建立追踪关系';

  @override
  String get gitSync => '同步';

  @override
  String get gitSyncTooltip => '先拉取远端改动，再推送本地提交';

  @override
  String get gitCancelOperation => '取消';

  @override
  String get gitRemoteOperationRunning => '云端操作进行中...';

  @override
  String get gitRemoteOperationCancelled => '操作已取消';

  @override
  String get gitRemoteOperationBusy => '已有云端操作正在进行，请稍候';

  @override
  String get gitFetchSuccess => '抓取完成';

  @override
  String get gitFetchNoChanges => '已是最新状态';

  @override
  String get gitPullSuccess => '拉取完成';

  @override
  String get gitPullAlreadyUpToDate => '已是最新，无需拉取';

  @override
  String get gitPushSuccess => '推送完成';

  @override
  String get gitPushUpToDate => '远端已是最新，无需推送';

  @override
  String get gitNoRemoteConfigured => '尚未配置远程仓库';

  @override
  String get gitNoRemoteDesc => '添加远程仓库地址后，即可抓取、拉取与推送代码。';

  @override
  String get gitAddRemote => '添加远程仓库';

  @override
  String get gitRemoteManagement => '远程仓库管理';

  @override
  String get gitRemoteName => '远程名称';

  @override
  String get gitRemoteNameHint => '例如 origin';

  @override
  String get gitRemoteUrl => '远程地址';

  @override
  String get gitRemoteUrlHint =>
      'https://github.com/user/repo.git 或 git@github.com:user/repo.git';

  @override
  String get gitRemotePushUrl => '推送地址（可选）';

  @override
  String get gitRemotePushUrlHint => '留空则与抓取地址相同';

  @override
  String get gitRemoteNameRequired => '请输入远程名称';

  @override
  String get gitRemoteUrlRequired => '请输入远程地址';

  @override
  String gitRemoteAdded(String name) {
    return '已添加远程仓库 $name';
  }

  @override
  String gitRemoteRemoved(String name) {
    return '已移除远程仓库 $name';
  }

  @override
  String gitRemoteRenamed(String old, String newName) {
    return '已将 $old 重命名为 $newName';
  }

  @override
  String get gitRemoteUrlUpdated => '已更新远程地址';

  @override
  String get gitRemotePruned => '已清理远端已删除的分支';

  @override
  String gitRemoteRemoveConfirm(String name) {
    return '确定要移除远程仓库 $name 吗？本地代码不会被删除。';
  }

  @override
  String get gitRemoteEdit => '编辑远程仓库';

  @override
  String get gitRemoteFetchUrl => '抓取地址';

  @override
  String get gitRemoteSetPushUrl => '设置推送地址';

  @override
  String get gitRemotePrune => '清理失效分支';

  @override
  String get gitCheckConnection => '检测连接';

  @override
  String get gitCheckConnectionSuccess => '连接正常，认证可用';

  @override
  String get gitNoRemotes => '暂无远程仓库';

  @override
  String get gitFetchFailed => '抓取失败';

  @override
  String get gitPullFailed => '拉取失败';

  @override
  String get gitPushFailed => '推送失败';

  @override
  String get gitForcePush => '强制推送';

  @override
  String get gitForcePushTooltip => '覆盖远端分支（使用 --force-with-lease 安全校验）';

  @override
  String get gitForcePushWarning => '强制推送会用本地提交覆盖远端分支，可能导致他人提交丢失。';

  @override
  String get gitForcePushConfirm => '确认强制推送';

  @override
  String gitForcePushConfirmDesc(String branch) {
    return '该操作将改写远端 $branch 分支的历史。仅在确认远端没有他人新提交时使用。';
  }

  @override
  String get gitForcePushUseLease => '使用安全强推（--force-with-lease）';

  @override
  String get gitPullThenPush => '先拉取再推送';

  @override
  String get gitPullThenPushDesc => '远端存在本地没有的提交，先拉取合并后再推送。';

  @override
  String get gitConflictAbort => '放弃本次变基';

  @override
  String get gitConflictAbortConfirm => '确定要放弃本次变基操作并回到操作前的状态吗？';

  @override
  String get gitUncommittedChangesTitle => '存在未提交的改动';

  @override
  String get gitUncommittedChangesDesc => '拉取前需要先处理本地未提交的改动，否则可能被覆盖。';

  @override
  String get gitUncommittedStashAndPull => '贮藏并拉取';

  @override
  String get gitUncommittedCommitFirst => '先去提交';

  @override
  String get gitUncommittedCancel => '取消';

  @override
  String get gitStashAndPullSuccess => '已贮藏本地改动并完成拉取';

  @override
  String get gitViewOperationLog => '查看详情';

  @override
  String get gitHideOperationLog => '收起详情';

  @override
  String gitAheadBehind(int ahead, int behind) {
    return '领先 $ahead / 落后 $behind';
  }

  @override
  String get gitUpstreamGone => '上游分支已不存在';

  @override
  String gitBehindTooltip(int behind) {
    return '本地落后远端 $behind 个提交';
  }

  @override
  String gitAheadTooltip(int ahead) {
    return '本地领先远端 $ahead 个提交';
  }

  @override
  String get gitDiff => '差异对比';

  @override
  String get gitDiffOriginal => '原始版本';

  @override
  String get gitDiffModified => '修改版本';

  @override
  String get gitDiffSplitView => '双屏分栏';

  @override
  String get gitDiffUnifiedView => '单屏内联';

  @override
  String get gitDiffPrevChange => '上一处更改';

  @override
  String get gitDiffNextChange => '下一处更改';

  @override
  String get gitDiffBinaryOrEmpty => '二进制或不支持比较的文件';

  @override
  String get gitDiffNoChanges => '该文件与基准版本完全一致，暂无差异';

  @override
  String get gitDiffStageTooltip => '暂存此文件更改';

  @override
  String get gitDiffUnstageTooltip => '取消暂存此文件';

  @override
  String get gitDiffDiscardTooltip => '放弃此文件更改';

  @override
  String get gitExpandAll => '全部展开';

  @override
  String gitLoadMoreCommits(int count) {
    return '加载更多提交 ($count)';
  }

  @override
  String gitLoadedCommitsCount(int loaded, int total) {
    return '已显示 $loaded / $total 个提交';
  }

  @override
  String gitAllCommitsLoaded(int count) {
    return '已显示全部 $count 个提交';
  }

  @override
  String get gitLoadingMoreCommits => '正在加载更多提交...';

  @override
  String get searchExpandAllMatchesInFile => '展开全部匹配项';

  @override
  String get preserveCase => '保留大小写';

  @override
  String get replaceMoreOptions => '更多替换选项';

  @override
  String get searchRefresh => '刷新';

  @override
  String get searchPreviousMatch => '上一个匹配项';

  @override
  String get searchNextMatch => '下一个匹配项';

  @override
  String get replaceCurrentMatch => '替换';

  @override
  String get gitAccountManagement => 'Git 账号管理';

  @override
  String get gitEdit => '编辑';

  @override
  String get gitHostedAccounts => '托管账号';

  @override
  String get gitSshKeys => 'SSH 密钥';

  @override
  String get gitAddAccount => '添加 Git 账号';

  @override
  String get gitEditAccount => '编辑 Git 账号';

  @override
  String get gitNoAccountsTitle => '暂未绑定 Git 账号';

  @override
  String get gitNoAccountsSubtitle =>
      '绑定 GitHub 或 Gitee 等账号后，推送代码、拉取私有仓库将全程免密认证。';

  @override
  String get gitAddFirstAccount => '添加第一个 Git 账号';

  @override
  String get gitDefaultAccountBadge => '默认';

  @override
  String get gitSetAsDefault => '设为默认账号';

  @override
  String get gitSetAsDefaultSuccess => '已设为默认账号';

  @override
  String get gitTestConnection => '测试连接';

  @override
  String get gitTestingConnection => '正在验证平台连接...';

  @override
  String gitTestConnectionSuccess(String username) {
    return '连接成功！已验证用户: $username';
  }

  @override
  String get gitTestConnectionFailed => '验证失败';

  @override
  String get gitDeleteAccount => '删除账号';

  @override
  String gitDeleteAccountConfirmTitle(String name) {
    return '删除账号 $name？';
  }

  @override
  String get gitDeleteAccountConfirmMessage =>
      '删除后该账号凭据将从本地及容器内移除，相关远程操作将需要重新认证。';

  @override
  String get gitDeleteAccountSuccess => '已删除账号';

  @override
  String get gitAccountSavedSuccess => '账号添加成功';

  @override
  String get gitAccountUpdatedSuccess => '账号已更新';

  @override
  String get gitContainerSshTitle => '容器内置 SSH 密钥对';

  @override
  String get gitContainerSshSubtitle =>
      '用于 SSH 协议免密克隆与推送 (git@github.com:... 或 git@gitee.com:...)。';

  @override
  String get gitCopyPublicKey => '一键复制公钥';

  @override
  String get gitPublicKeyCopied => '公钥已复制到剪贴板';

  @override
  String get gitRegenerateKey => '重新生成';

  @override
  String get gitNoSshKeyNotice =>
      '当前尚未生成 SSH 密钥对。生成后即可一键复制并粘贴至 GitHub/Gitee 的 SSH Keys 设置中。';

  @override
  String get gitGenerateEd25519Key => '生成 Ed25519 SSH 密钥';

  @override
  String get gitGeneratingSshKey => '正在生成 SSH 密钥...';

  @override
  String get gitSshKeyGenerateSuccess => 'SSH 密钥生成成功';

  @override
  String get gitSshKeyGenerateFailed => '生成失败';

  @override
  String get gitRegenerateSshConfirmTitle => '重新生成 SSH 密钥？';

  @override
  String get gitRegenerateSshConfirmMessage =>
      '重新生成将覆盖现有的 SSH 密钥，旧公钥在 GitHub/Gitee 上将失效，需重新粘贴新公钥。';

  @override
  String get gitOverwrite => '确定覆盖';

  @override
  String get gitSshGuideTitle => '如何配置到云端平台？';

  @override
  String get gitSshGuideStep1 => '点击上方【一键复制公钥】；';

  @override
  String get gitSshGuideStep2 =>
      '在浏览器打开 GitHub 或 Gitee 的设置页 (Settings -> SSH Keys)；';

  @override
  String get gitSshGuideStep3 => '点击 \"New SSH Key\"，将公钥粘贴到 Key 输入框中保存即可。';

  @override
  String get gitServerUrl => '服务器地址';

  @override
  String get gitTokenLabel => '访问令牌';

  @override
  String get gitTokenHint => '输入在平台创建的 PAT 令牌';

  @override
  String get gitGetToken => '获取 Token';

  @override
  String get gitTokenCopiedOpeningBrowser => 'Token 创建链接已复制，正在前往浏览器...';

  @override
  String get gitEnterTokenPrompt => '请输入访问令牌';

  @override
  String get gitTokenVerifyFailed => 'Token 校验失败，请核对权限或有效性';

  @override
  String get gitVerifyAndSave => '验证并保存';

  @override
  String get gitAuthTypeToken => '个人访问令牌';

  @override
  String get gitAuthTypeSsh => 'SSH 密钥对';

  @override
  String get gitPlatformGeneric => '通用 / 自建 Git';
}
