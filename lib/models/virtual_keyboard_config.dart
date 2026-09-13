import 'dart:convert';
import 'package:flutter/material.dart';

/// 内置常量图标映射辅助类
class KeyboardIconHelper {
  static const Map<String, IconData> _icons = {
    'undo': Icons.undo,
    'redo': Icons.redo,
    'tab': Icons.keyboard_tab,
    'untab': Icons.format_indent_decrease,
    'outdent': Icons.format_indent_decrease,
    'arrow_left': Icons.arrow_back,
    'arrow_right': Icons.arrow_forward,
    'arrow_up': Icons.arrow_upward,
    'arrow_down': Icons.arrow_downward,
    'home': Icons.vertical_align_top,
    'end': Icons.vertical_align_bottom,
    'first_page': Icons.first_page,
    'last_page': Icons.last_page,
    'page_up': Icons.keyboard_double_arrow_up,
    'page_down': Icons.keyboard_double_arrow_down,
    'enter': Icons.keyboard_return,
    'space': Icons.space_bar,
    'escape': Icons.cancel_outlined,
    'insert': Icons.input,
    'clear': Icons.clear,
    'keyboard': Icons.keyboard_outlined,
    'backspace': Icons.backspace_outlined,
    'delete': Icons.delete_outline,
    'copy': Icons.copy,
    'cut': Icons.content_cut,
    'paste': Icons.content_paste,
    'save': Icons.save_outlined,
    'search': Icons.search,
    'select_all': Icons.select_all,
    'keyboard_hide': Icons.keyboard_hide_outlined,
  };

  /// 根据 icon 字符串获取对应的 IconData，不存在或为空时返回 null
  static IconData? getIcon(String? iconKey) {
    if (iconKey == null || iconKey.trim().isEmpty) return null;
    return _icons[iconKey.trim().toLowerCase()];
  }

  /// 所有支持的图标名称列表（方便用户配置或提示）
  static List<String> get supportedIconKeys => _icons.keys.toList();
}

/// 虚拟小键盘作用域（编辑区或终端）
///
/// 界面展示名称取自 l10n（`editorScope` / `terminalScope`），此处不再自带文案。
enum KeyboardScope {
  editor,
  terminal,
}

/// 按键动作定义项辅助
///
/// 注意：[label] 与 [description] 仅作为代码内的定义说明，界面展示名称一律取自
/// l10n（`keyboardActionName`），避免中英文文案两处维护。
class KeyboardActionOption {
  final String action;
  final String label;
  final String description;

  const KeyboardActionOption({
    required this.action,
    required this.label,
    required this.description,
  });
}

/// 预设值选项辅助
///
/// 注意：[label] 仅作为代码内的定义说明，界面展示名称一律取自 l10n
/// （`keyboardCommandName` / `keyboardModifierName` / `keyboardKeyName`）。
class KeyboardValueOption {
  final String value;
  final String label;

  /// 下拉菜单中展示的内置图标常量名称（可选，取值同 [KeyboardIconHelper]）
  final String? icon;

  const KeyboardValueOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// 按键修饰符组合（Ctrl / Alt / Shift）
///
/// 仅在终端作用域的 `key` 动作上有实际含义：xterm 会把它换算成对应转义序列。
/// 三个都为 false 时视为"无修饰"，JSON 导出时整个 `mods` 字段省略。
class KeyboardKeyMods {
  final bool ctrl;
  final bool alt;
  final bool shift;

  const KeyboardKeyMods({
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });

  /// 无修饰的常量实例
  static const KeyboardKeyMods none = KeyboardKeyMods();

  bool get isEmpty => !ctrl && !alt && !shift;

  bool get isNotEmpty => !isEmpty;

  /// 已勾选的修饰键数量
  int get count => (ctrl ? 1 : 0) + (alt ? 1 : 0) + (shift ? 1 : 0);

  KeyboardKeyMods copyWith({bool? ctrl, bool? alt, bool? shift}) {
    return KeyboardKeyMods(
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
    );
  }

  /// 从 `{"ctrl": true, "alt": false}` 形式的 JSON 解析，非法输入一律视为无修饰
  factory KeyboardKeyMods.fromJson(dynamic json) {
    if (json is! Map) return none;
    return KeyboardKeyMods(
      ctrl: json['ctrl'] == true,
      alt: json['alt'] == true,
      shift: json['shift'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (ctrl) 'ctrl': true,
      if (alt) 'alt': true,
      if (shift) 'shift': true,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardKeyMods &&
        other.ctrl == ctrl &&
        other.alt == alt &&
        other.shift == shift;
  }

  @override
  int get hashCode => Object.hash(ctrl, alt, shift);

  @override
  String toString() {
    if (isEmpty) return 'none';
    return [
      if (ctrl) 'ctrl',
      if (alt) 'alt',
      if (shift) 'shift',
    ].join('+');
  }
}

/// 终端命名键分组（用于弹窗下拉的分组展示）
enum TerminalKeyGroup {
  navigation,
  editing,
  functionKeys,
  letters,
}

/// 终端命名键选项：value 为 xterm `TerminalKey` 的枚举名
class KeyboardNamedKeyOption {
  final String value;
  final TerminalKeyGroup group;

  /// 下拉菜单中展示的内置图标常量名称（可选，取值同 [KeyboardIconHelper]）
  final String? icon;

  const KeyboardNamedKeyOption({
    required this.value,
    required this.group,
    this.icon,
  });
}

/// 作用域对应的动作与预设值定义
class KeyboardScopeHelper {
  /// 编辑区支持的动作类型
  static const List<KeyboardActionOption> editorActions = [
    KeyboardActionOption(action: 'input', label: '普通文本', description: '直接插入指定文本内容'),
    KeyboardActionOption(action: 'pair', label: '成对符号', description: '括号/引号等成对符号，支持选区包裹与光标偏移'),
    KeyboardActionOption(action: 'command', label: '编辑器命令', description: '触发缩进、撤销、光标移动等编辑器功能'),
  ];

  /// 终端支持的动作类型
  static const List<KeyboardActionOption> terminalActions = [
    KeyboardActionOption(action: 'input', label: '指令快捷键', description: '向终端发送一段文本，可附加自动回车'),
    KeyboardActionOption(action: 'modifier', label: '修饰键', description: 'Ctrl / Alt / Shift 修饰状态切换'),
    KeyboardActionOption(action: 'key', label: '特殊键', description: 'Esc、Tab、方向键、功能键及 Ctrl/Alt 组合'),
  ];

  /// 终端动作取值集合（供校验使用）
  static const Set<String> terminalActionValues = {'input', 'modifier', 'key'};

  /// 编辑区动作取值集合（供校验使用）
  static const Set<String> editorActionValues = {'input', 'pair', 'command'};

  /// 编辑区预设命令列表（icon 用于下拉菜单前缀展示）
  static const List<KeyboardValueOption> editorCommands = [
    KeyboardValueOption(value: 'tab', label: '向右缩进', icon: 'tab'),
    KeyboardValueOption(value: 'untab', label: '向左缩进', icon: 'untab'),
    KeyboardValueOption(value: 'undo', label: '撤销', icon: 'undo'),
    KeyboardValueOption(value: 'redo', label: '重做', icon: 'redo'),
    KeyboardValueOption(value: 'cursor_left', label: '光标左移', icon: 'arrow_left'),
    KeyboardValueOption(value: 'cursor_right', label: '光标右移', icon: 'arrow_right'),
    KeyboardValueOption(value: 'cursor_up', label: '光标上移', icon: 'arrow_up'),
    KeyboardValueOption(value: 'cursor_down', label: '光标下移', icon: 'arrow_down'),
    KeyboardValueOption(value: 'line_start', label: '移动至行首', icon: 'home'),
    KeyboardValueOption(value: 'line_end', label: '移动至行尾', icon: 'end'),
    KeyboardValueOption(value: 'page_start', label: '移动至文首', icon: 'first_page'),
    KeyboardValueOption(value: 'page_end', label: '移动至文末', icon: 'last_page'),
    KeyboardValueOption(value: 'copy', label: '复制', icon: 'copy'),
    KeyboardValueOption(value: 'cut', label: '剪切', icon: 'cut'),
    KeyboardValueOption(value: 'paste', label: '粘贴', icon: 'paste'),
    KeyboardValueOption(value: 'delete', label: '删除', icon: 'delete'),
    KeyboardValueOption(value: 'select_all', label: '全选', icon: 'select_all'),
    KeyboardValueOption(value: 'keyboard_hide', label: '收起小键盘', icon: 'keyboard_hide'),
  ];

  // ==========================================
  // 终端命名键表（值为 xterm TerminalKey 的枚举名）
  //
  // 说明：xterm 4.0.0 的默认 keytab 只对下列 31 个命名键定义了转义序列，
  // 其余 HID 键码（digit0-9、numpad0-9、media*、gameButton* 等）在默认
  // keytab 中没有条目，`Terminal.keyInput` 会返回 false 且不产生任何输出，
  // 因此这里作为"终端中真正可用"的键清单，由弹窗下拉与 JSON 校验共用。
  // 组合键由弹窗下方的三个修饰键控件（Ctrl / Alt / Shift）叠加产生。
  // ==========================================

  /// 终端可用命名键（导航键）
  static const List<KeyboardNamedKeyOption> terminalNavigationKeys = [
    KeyboardNamedKeyOption(value: 'arrowUp', group: TerminalKeyGroup.navigation, icon: 'arrow_up'),
    KeyboardNamedKeyOption(value: 'arrowDown', group: TerminalKeyGroup.navigation, icon: 'arrow_down'),
    KeyboardNamedKeyOption(value: 'arrowLeft', group: TerminalKeyGroup.navigation, icon: 'arrow_left'),
    KeyboardNamedKeyOption(value: 'arrowRight', group: TerminalKeyGroup.navigation, icon: 'arrow_right'),
    KeyboardNamedKeyOption(value: 'home', group: TerminalKeyGroup.navigation, icon: 'home'),
    KeyboardNamedKeyOption(value: 'end', group: TerminalKeyGroup.navigation, icon: 'end'),
    KeyboardNamedKeyOption(value: 'pageUp', group: TerminalKeyGroup.navigation, icon: 'page_up'),
    KeyboardNamedKeyOption(value: 'pageDown', group: TerminalKeyGroup.navigation, icon: 'page_down'),
  ];

  /// 终端可用命名键（编辑键）
  static const List<KeyboardNamedKeyOption> terminalEditingKeys = [
    KeyboardNamedKeyOption(value: 'escape', group: TerminalKeyGroup.editing, icon: 'escape'),
    KeyboardNamedKeyOption(value: 'tab', group: TerminalKeyGroup.editing, icon: 'tab'),
    KeyboardNamedKeyOption(value: 'backtab', group: TerminalKeyGroup.editing, icon: 'untab'),
    KeyboardNamedKeyOption(value: 'returnKey', group: TerminalKeyGroup.editing, icon: 'enter'),
    KeyboardNamedKeyOption(value: 'enter', group: TerminalKeyGroup.editing, icon: 'enter'),
    KeyboardNamedKeyOption(value: 'numpadEnter', group: TerminalKeyGroup.editing, icon: 'enter'),
    KeyboardNamedKeyOption(value: 'backspace', group: TerminalKeyGroup.editing, icon: 'backspace'),
    KeyboardNamedKeyOption(value: 'delete', group: TerminalKeyGroup.editing, icon: 'delete'),
    KeyboardNamedKeyOption(value: 'insert', group: TerminalKeyGroup.editing, icon: 'insert'),
    KeyboardNamedKeyOption(value: 'space', group: TerminalKeyGroup.editing, icon: 'space'),
    KeyboardNamedKeyOption(value: 'numpadClear', group: TerminalKeyGroup.editing, icon: 'clear'),
  ];

  /// 终端可用命名键（功能键 F1~F12，统一用键盘图标）
  static const List<KeyboardNamedKeyOption> terminalFunctionKeys = [
    KeyboardNamedKeyOption(value: 'f1', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f2', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f3', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f4', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f5', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f6', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f7', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f8', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f9', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f10', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f11', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
    KeyboardNamedKeyOption(value: 'f12', group: TerminalKeyGroup.functionKeys, icon: 'keyboard'),
  ];

  /// 终端全部可用命名键（31 个，按分组顺序拼接）
  static const List<KeyboardNamedKeyOption> terminalNamedKeys = [
    ...terminalNavigationKeys,
    ...terminalEditingKeys,
    ...terminalFunctionKeys,
  ];

  /// 终端字母键 keyA ~ keyZ（同样用键盘图标；配合下方修饰键控件可组成 Ctrl+C）
  ///
  /// 用 getter 而不是 `static final`：静态字段在热重载后不会重新初始化，
  /// 会让这里的改动（例如给字母键补图标）"看起来没生效"。
  static List<KeyboardNamedKeyOption> get terminalLetterKeys => [
        for (int i = 0; i < 26; i++)
          KeyboardNamedKeyOption(
            value: 'key${String.fromCharCode(0x41 + i)}',
            group: TerminalKeyGroup.letters,
            icon: 'keyboard',
          ),
      ];

  /// 弹窗下拉可选的终端键（31 命名键 + 26 字母键）
  static List<KeyboardNamedKeyOption> get terminalSelectableKeys => [
        ...terminalNamedKeys,
        ...terminalLetterKeys,
      ];

  /// 终端特殊键的紧凑显示名，用于按键标签自动生成（符号/缩写无需 l10n）
  static String terminalKeyShortLabel(String value) {
    switch (value) {
      case 'escape':
        return 'Esc';
      case 'tab':
        return 'Tab';
      case 'backtab':
        return '⇤';
      case 'returnKey':
      case 'enter':
      case 'numpadEnter':
        return '⏎';
      case 'backspace':
        return '⌫';
      case 'delete':
        return 'Del';
      case 'insert':
        return 'Ins';
      case 'space':
        return 'Space';
      case 'numpadClear':
        return 'Clear';
      case 'arrowUp':
        return '↑';
      case 'arrowDown':
        return '↓';
      case 'arrowLeft':
        return '←';
      case 'arrowRight':
        return '→';
      case 'home':
        return 'Home';
      case 'end':
        return 'End';
      case 'pageUp':
        return 'PgUp';
      case 'pageDown':
        return 'PgDn';
      default:
        if (isLetterKeyName(value)) return value.substring(3);
        if (value.length > 1 && value.startsWith('f') && int.tryParse(value.substring(1)) != null) {
          return value.toUpperCase();
        }
        return value;
    }
  }

  /// 终端 action 为 `key` 时的合法 value 集合（31 个命名键 + keyA~keyZ）
  static Set<String> get terminalSupportedKeyNames => {
        for (final key in terminalNamedKeys) key.value,
        for (int i = 0; i < 26; i++) 'key${String.fromCharCode(0x41 + i)}',
      };

  /// 是否为字母键名（keyA ~ keyZ）
  static bool isLetterKeyName(String value) {
    if (value.length != 4 || !value.startsWith('key')) return false;
    final code = value.codeUnitAt(3);
    return code >= 0x41 && code <= 0x5A;
  }

  /// 判断终端 `key` 动作的 value 是否为受支持的键。
  ///
  /// - 31 个命名键：任意修饰组合都可用
  /// - 字母键 keyA~keyZ：**不受修饰符约束**，单独成格时就是该字母本身
  ///   （运行时走 `charInput`：裸字母发字母，Ctrl/Alt 组合发对应控制序列）
  static bool isSupportedTerminalKey(String value) {
    return terminalNamedKeys.any((k) => k.value == value) || isLetterKeyName(value);
  }

  /// 修饰键动作允许的取值
  static const Set<String> terminalModifierValues = {'ctrl', 'alt', 'shift'};
}

/// 小键盘单个按键数据模型
class KeyboardKeyItem {
  /// 显示文本（当 icon 为空或不存在时渲染）
  final String label;

  /// 内置图标常量名称，非空且在内置库存在时优先渲染图标
  final String? icon;

  /// 动作类型：
  /// - 'input': 普通文本输入（默认）。终端作用域下即"指令快捷键"，配合
  ///   [autoEnter] 可实现"输入并执行"
  /// - 'pair': 括号/引号等成对符号，支持选区包裹与光标偏移（仅编辑区）
  /// - 'command': 编辑器动作命令，例如 'cursor_left', 'tab', 'undo' 等（仅编辑区）
  /// - 'modifier': 终端修饰键，取值 'ctrl' / 'alt' / 'shift'（仅终端）
  /// - 'key': 终端特殊键，取值为 xterm `TerminalKey` 枚举名（仅终端）
  final String action;

  /// 动作附带值（输入的文本、命令名称或特殊键名）
  final String value;

  /// 光标插入后的相对偏移（如 pair \"()\" 插入后光标向左移动 1 位，则为 -1）
  final int cursorOffset;

  /// 修饰符组合，仅终端 `key` 动作有效（文本通道不接受修饰符）
  final KeyboardKeyMods mods;

  /// 仅终端 `input` 动作有效：发送文本后补一个回车符 `\r`，实现"输入即执行"
  final bool autoEnter;

  const KeyboardKeyItem({
    required this.label,
    this.icon,
    this.action = 'input',
    required this.value,
    this.cursorOffset = 0,
    this.mods = KeyboardKeyMods.none,
    this.autoEnter = false,
  });

  KeyboardKeyItem copyWith({
    String? label,
    String? icon,
    bool clearIcon = false,
    String? action,
    String? value,
    int? cursorOffset,
    KeyboardKeyMods? mods,
    bool? autoEnter,
  }) {
    return KeyboardKeyItem(
      label: label ?? this.label,
      icon: clearIcon ? null : (icon ?? this.icon),
      action: action ?? this.action,
      value: value ?? this.value,
      cursorOffset: cursorOffset ?? this.cursorOffset,
      mods: mods ?? this.mods,
      autoEnter: autoEnter ?? this.autoEnter,
    );
  }

  /// 从 JSON 数据中解析按键：
  /// - 若为 String：严格转换为 input 动作，label 和 value 为该字符串，绝对不做额外猜测！
  /// - 若为 Map：读取相应字段。
  factory KeyboardKeyItem.fromJson(dynamic json) {
    if (json is String) {
      return KeyboardKeyItem(
        label: json,
        value: json,
        action: 'input',
        cursorOffset: 0,
      );
    }
    if (json is Map<String, dynamic>) {
      final label = json['label']?.toString() ?? json['value']?.toString() ?? '';
      final value = json['value']?.toString() ?? label;
      final action = json['action']?.toString() ?? 'input';
      final icon = json['icon']?.toString();
      final cursorOffset = (json['cursorOffset'] as num?)?.toInt() ?? 0;
      return KeyboardKeyItem(
        label: label,
        icon: icon,
        action: action,
        value: value,
        cursorOffset: cursorOffset,
        mods: KeyboardKeyMods.fromJson(json['mods']),
        autoEnter: json['autoEnter'] == true,
      );
    }
    return const KeyboardKeyItem(label: '', value: '');
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'label': label,
      'value': value,
      'action': action,
    };
    if (icon != null && icon!.isNotEmpty) {
      map['icon'] = icon;
    }
    if (cursorOffset != 0) {
      map['cursorOffset'] = cursorOffset;
    }
    if (mods.isNotEmpty) {
      map['mods'] = mods.toJson();
    }
    if (autoEnter) {
      map['autoEnter'] = true;
    }
    return map;
  }
}

/// 小键盘单页数据模型
class KeyboardPageItem {
  /// 每行格子数（页面宽度等分为 count 份）
  final int count;

  /// 该页的所有行按键，每行是一个按键列表
  final List<List<KeyboardKeyItem>> keys;

  const KeyboardPageItem({
    required this.count,
    required this.keys,
  });

  KeyboardPageItem copyWith({
    int? count,
    List<List<KeyboardKeyItem>>? keys,
  }) {
    return KeyboardPageItem(
      count: count ?? this.count,
      keys: keys ?? this.keys,
    );
  }

  factory KeyboardPageItem.fromJson(Map<String, dynamic> json) {
    final count = (json['count'] as num?)?.toInt() ?? 6;
    final rawKeys = json['keys'] as List<dynamic>? ?? [];
    final List<List<KeyboardKeyItem>> parsedKeys = [];

    for (final row in rawKeys) {
      if (row is List) {
        parsedKeys.add(row.map((k) => KeyboardKeyItem.fromJson(k)).toList());
      }
    }

    return KeyboardPageItem(
      count: count > 0 ? count : 6,
      keys: parsedKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'keys': keys.map((row) => row.map((k) => k.toJson()).toList()).toList(),
    };
  }
}

/// 完整虚拟键盘配置模型
class VirtualKeyboardConfig {
  final List<KeyboardPageItem> pages;

  const VirtualKeyboardConfig({
    required this.pages,
  });

  VirtualKeyboardConfig copyWith({
    List<KeyboardPageItem>? pages,
  }) {
    return VirtualKeyboardConfig(
      pages: pages ?? this.pages,
    );
  }

  factory VirtualKeyboardConfig.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('pages')) {
      return _defaultConfig();
    }
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final List<KeyboardPageItem> parsedPages = [];

    for (final p in rawPages) {
      if (p is Map<String, dynamic>) {
        parsedPages.add(KeyboardPageItem.fromJson(p));
      }
    }

    return VirtualKeyboardConfig(
      pages: parsedPages,
    );
  }

  /// 判断当前配置是否包含至少一个有效按键
  bool get hasKeys {
    for (final page in pages) {
      for (final row in page.keys) {
        for (final key in row) {
          if (key.label.trim().isNotEmpty ||
              (key.icon != null && key.icon!.trim().isNotEmpty) ||
              key.value.trim().isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  /// 校验 JSON 文本合法性，若合法返回 null，若非法返回具体错误描述。
  ///
  /// [scope] 决定按键动作与取值的合法集合：
  /// - 编辑区：`input` / `pair` / `command`
  /// - 终端：`input`（指令快捷键）/ `modifier` / `key`（特殊键）
  static String? validateJson(String jsonStr, [KeyboardScope scope = KeyboardScope.editor]) {
    final trimmed = jsonStr.trim();
    if (trimmed.isEmpty) {
      return '配置内容不能为空';
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException catch (e) {
      String locationStr = '';
      if (e.offset != null && e.offset! >= 0 && e.offset! <= jsonStr.length) {
        int line = 1;
        int column = 1;
        for (int i = 0; i < e.offset!; i++) {
          if (jsonStr[i] == '\n') {
            line++;
            column = 1;
          } else {
            column++;
          }
        }
        locationStr = ' (第 $line 行, 第 $column 列)';
      }
      return 'JSON 语法错误: ${e.message}$locationStr';
    } catch (e) {
      return 'JSON 解析失败: $e';
    }

    if (decoded is! Map<String, dynamic>) {
      return '配置根节点必须是 JSON 对象 (以 {} 包裹)';
    }

    if (!decoded.containsKey('pages')) {
      return '根节点缺少必需的 "pages" 列表字段';
    }

    final pages = decoded['pages'];
    if (pages is! List) {
      return '"pages" 字段必须是一个数组 (List)';
    }

    if (pages.isEmpty) {
      return '"pages" 至少需要包含 1 个页面配置';
    }

    for (int pIdx = 0; pIdx < pages.length; pIdx++) {
      final page = pages[pIdx];
      final pageNum = pIdx + 1;
      if (page is! Map<String, dynamic>) {
        return '第 $pageNum 页必须是一个 JSON 对象';
      }

      if (!page.containsKey('count')) {
        return '第 $pageNum 页缺少必需的 "count" 字段';
      }

      final count = page['count'];
      if (count is! int || count <= 0) {
        return '第 $pageNum 页的 "count" 必须为大于 0 的正整数';
      }

      if (!page.containsKey('keys')) {
        return '第 $pageNum 页缺少必需的 "keys" 字段';
      }

      final keys = page['keys'];
      if (keys is! List) {
        return '第 $pageNum 页的 "keys" 必须是一个数组';
      }

      for (int rIdx = 0; rIdx < keys.length; rIdx++) {
        final row = keys[rIdx];
        final rowNum = rIdx + 1;
        if (row is! List) {
          return '第 $pageNum 页第 $rowNum 行必须是一个按键数组';
        }

        for (int kIdx = 0; kIdx < row.length; kIdx++) {
          final key = row[kIdx];
          final keyNum = kIdx + 1;
          if (key is String) {
            // 纯文本是完全合法的
            continue;
          } else if (key is Map<String, dynamic>) {
            // 对象形式必须至少有 label 或 value
            final hasLabel = key.containsKey('label') && key['label'] != null;
            final hasValue = key.containsKey('value') && key['value'] != null;
            final hasIcon = key.containsKey('icon') && key['icon'] != null;
            if (!hasLabel && !hasValue && !hasIcon) {
              return '第 $pageNum 页第 $rowNum 行第 $keyNum 个按键缺少 label、value 或 icon 属性';
            }
            if (key.containsKey('cursorOffset') && key['cursorOffset'] is! int) {
              return '第 $pageNum 页第 $rowNum 行第 $keyNum 个按键的 "cursorOffset" 必须为整数';
            }
            final actionError = _validateKeyAction(
              key: key,
              scope: scope,
              location: '第 $pageNum 页第 $rowNum 行第 $keyNum 个按键',
            );
            if (actionError != null) return actionError;
          } else {
            return '第 $pageNum 页第 $rowNum 行第 $keyNum 个按键类型错误，只能是文本字符串或对象';
          }
        }
      }
    }

    return null;
  }

  /// 按作用域校验单个按键对象的 action / value / mods / autoEnter 组合。
  ///
  /// 返回 null 表示合法；否则返回可直接展示给用户的错误描述。
  /// 这里的严格程度是刻意为之：宁可保存时报错，也不要在运行时静默无输出
  /// （例如把 digit1 当作终端特殊键，或给文本通道挂修饰符）。
  static String? _validateKeyAction({
    required Map<String, dynamic> key,
    required KeyboardScope scope,
    required String location,
  }) {
    final action = key['action']?.toString() ?? 'input';
    final value = key['value']?.toString() ?? '';
    final mods = KeyboardKeyMods.fromJson(key['mods']);

    if (key.containsKey('mods') && key['mods'] != null && key['mods'] is! Map) {
      return '$location 的 "mods" 必须是对象，例如 {"ctrl": true}';
    }

    if (scope == KeyboardScope.editor) {
      if (!KeyboardScopeHelper.editorActionValues.contains(action)) {
        return '$location 的动作 "$action" 不适用于编辑区，可用动作: '
            '${KeyboardScopeHelper.editorActionValues.join(' / ')}';
      }
      return null;
    }

    // 终端作用域
    if (!KeyboardScopeHelper.terminalActionValues.contains(action)) {
      return '$location 的动作 "$action" 不适用于终端，可用动作: '
          '${KeyboardScopeHelper.terminalActionValues.join(' / ')}';
    }

    switch (action) {
      case 'modifier':
        if (!KeyboardScopeHelper.terminalModifierValues.contains(value)) {
          return '$location 的修饰键取值 "$value" 无效，只能是 '
              '${KeyboardScopeHelper.terminalModifierValues.join(' / ')}';
        }
        if (mods.isNotEmpty) {
          return '$location 是修饰键动作，不应再附带 "mods"';
        }
        return null;

      case 'key':
        if (value.isEmpty) {
          return '$location 缺少特殊键值 ("value")';
        }
        if (!KeyboardScopeHelper.isSupportedTerminalKey(value)) {
          return '$location 的特殊键 "$value" 在终端中不会产生任何输出，'
              '请选择受支持的命名键（如 escape / tab / arrowUp / f1）或字母键 keyA ~ keyZ';
        }
        return null;

      case 'input':
      default:
        if (value.isEmpty) {
          return '$location 缺少文本内容 ("value")';
        }
        if (mods.isNotEmpty) {
          return '$location 是文本指令，附加 "mods" 不会生效'
              '（终端文本通道不接受修饰符，请改用"特殊键"类型）';
        }
        return null;
    }
  }

  /// 默认配置预设（编辑区）
  static VirtualKeyboardConfig defaultConfiguration() => _defaultConfig();

  /// 按作用域返回默认配置预设
  static VirtualKeyboardConfig defaultForScope(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? defaultTerminalConfiguration() : _defaultConfig();

  /// ## 终端小键盘 JSON 结构
  ///
  /// ```json
  /// {
  ///   "pages": [
  ///     { "count": 7, "keys": [ [ <key>, <key>, ... ], ... ] }
  ///   ]
  /// }
  /// ```
  ///
  /// 终端作用域下 `<key>` 有三种动作：
  ///
  /// - **指令快捷键**：`{"label":"cd ..","action":"input","value":"cd ..","autoEnter":true}`
  ///   `autoEnter` 为 true 时，发送文本后再补一个回车符 `\r`（等价于按下回车），
  ///   实现"一格执行命令"；value 已以 `\r`/`\n` 结尾时不会重复补。
  /// - **特殊键**：`{"label":"^C","action":"key","value":"keyC","mods":{"ctrl":true}}`
  ///   - `value` 取 xterm `TerminalKey` 的枚举名，可用集合见
  ///     [KeyboardScopeHelper.terminalNamedKeys]（31 个命名键）与
  ///     [KeyboardScopeHelper.terminalSupportedKeyNames]（再加 keyA~keyZ）
  ///   - `mods` 形如 `{"ctrl":bool,"alt":bool,"shift":bool}`，**仅 `key` 动作有效**；
  ///     字母键必须且只能单独搭配 Ctrl 或 Alt，这是 xterm 输入链路的硬限制
  /// - **修饰键**：`{"label":"Ctrl","action":"modifier","value":"ctrl"}`
  ///   `value` ∈ {ctrl, alt, shift}，只切换运行时状态（单击一次性 / 双击锁定），不产生输出。
  ///
  /// 编辑区作用域继续使用 `input` / `pair` / `command`；`mods` 与 `autoEnter`
  /// 在无值时导出省略，因此既有编辑区配置零迁移。
  ///
  /// 默认终端配置预设：两行特殊键 + 修饰键
  ///
  /// 行1：Esc  Tab  Ctrl  Alt  -  ↑  回车
  /// 行2：Ins  End  Shift  :  ←  ↓  →
  static VirtualKeyboardConfig defaultTerminalConfiguration() {
    return const VirtualKeyboardConfig(
      pages: [
        KeyboardPageItem(
          count: 7,
          keys: [
            [
              KeyboardKeyItem(label: 'Esc', action: 'key', value: 'escape'),
              KeyboardKeyItem(label: 'Tab', icon: 'tab', action: 'key', value: 'tab'),
              KeyboardKeyItem(label: 'Ctrl', action: 'modifier', value: 'ctrl'),
              KeyboardKeyItem(label: 'Alt', action: 'modifier', value: 'alt'),
              KeyboardKeyItem(label: '-', action: 'input', value: '-'),
              KeyboardKeyItem(label: '↑', icon: 'arrow_up', action: 'key', value: 'arrowUp'),
              KeyboardKeyItem(label: '回车', icon: 'enter', action: 'key', value: 'enter'),
            ],
            [
              KeyboardKeyItem(label: 'Ins', action: 'key', value: 'insert'),
              KeyboardKeyItem(label: 'End', action: 'key', value: 'end'),
              KeyboardKeyItem(label: 'Shift', action: 'modifier', value: 'shift'),
              KeyboardKeyItem(label: ':', action: 'input', value: ':'),
              KeyboardKeyItem(label: '←', icon: 'arrow_left', action: 'key', value: 'arrowLeft'),
              KeyboardKeyItem(label: '↓', icon: 'arrow_down', action: 'key', value: 'arrowDown'),
              KeyboardKeyItem(label: '→', icon: 'arrow_right', action: 'key', value: 'arrowRight'),
            ],
          ],
        ),
      ],
    );
  }

  static VirtualKeyboardConfig _defaultConfig() {
    return const VirtualKeyboardConfig(
      pages: [
        // Page 1: 常用控制、括号与高频符号 (每行 7 格)
        KeyboardPageItem(
          count: 7,
          keys: [
            [
              KeyboardKeyItem(label: 'Tab', icon: 'tab', action: 'command', value: 'tab'),
              KeyboardKeyItem(label: 'Untab', icon: 'untab', action: 'command', value: 'untab'),
              KeyboardKeyItem(label: '()', action: 'pair', value: '()', cursorOffset: -1),
              KeyboardKeyItem(label: '[]', action: 'pair', value: '[]', cursorOffset: -1),
              KeyboardKeyItem(label: '{}', action: 'pair', value: '{}', cursorOffset: -1),
              KeyboardKeyItem(label: 'Undo', icon: 'undo', action: 'command', value: 'undo'),
              KeyboardKeyItem(label: 'Redo', icon: 'redo', action: 'command', value: 'redo'),
            ],
            [
              KeyboardKeyItem(label: '<-', icon: 'arrow_left', action: 'command', value: 'cursor_left'),
              KeyboardKeyItem(label: '->', icon: 'arrow_right', action: 'command', value: 'cursor_right'),
              KeyboardKeyItem(label: '""', action: 'pair', value: '""', cursorOffset: -1),
              KeyboardKeyItem(label: "''", action: 'pair', value: "''", cursorOffset: -1),
              KeyboardKeyItem(label: ';', action: 'input', value: ';'),
              KeyboardKeyItem(label: '=', action: 'input', value: '='),
              KeyboardKeyItem(label: ',', action: 'input', value: ','),
            ],
          ],
        ),
        // Page 2: 常用代码符号与运算符 (每行 7 格)
        KeyboardPageItem(
          count: 7,
          keys: [
            [
              KeyboardKeyItem(label: '.', action: 'input', value: '.'),
              KeyboardKeyItem(label: ':', action: 'input', value: ':'),
              KeyboardKeyItem(label: '<', action: 'input', value: '<'),
              KeyboardKeyItem(label: '>', action: 'input', value: '>'),
              KeyboardKeyItem(label: '/', action: 'input', value: '/'),
              KeyboardKeyItem(label: r'\', action: 'input', value: r'\'),
              KeyboardKeyItem(label: '_', action: 'input', value: '_'),
            ],
            [
              KeyboardKeyItem(label: '+', action: 'input', value: '+'),
              KeyboardKeyItem(label: '-', action: 'input', value: '-'),
              KeyboardKeyItem(label: '*', action: 'input', value: '*'),
              KeyboardKeyItem(label: '!', action: 'input', value: '!'),
              KeyboardKeyItem(label: '?', action: 'input', value: '?'),
              KeyboardKeyItem(label: '&', action: 'input', value: '&'),
              KeyboardKeyItem(label: '|', action: 'input', value: '|'),
            ],
          ],
        ),
      ],
    );
  }

  /// 转换为格式化好的默认 JSON 字符串（编辑区）
  static String defaultJsonPretty() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_defaultConfig().toJson());
  }

  /// 转换为格式化好的默认 JSON 字符串（终端）
  static String defaultTerminalJsonPretty() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(defaultTerminalConfiguration().toJson());
  }

  /// 按作用域返回格式化好的默认 JSON 字符串
  static String defaultJsonPrettyFor(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? defaultTerminalJsonPretty() : defaultJsonPretty();
}
