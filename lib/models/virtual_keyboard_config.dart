import 'dart:convert';
import 'package:flutter/material.dart';

/// 内置常量图标映射辅助类
class KeyboardIconHelper {
  static const Map<String, IconData> _icons = {
    'undo': Icons.undo,
    'redo': Icons.redo,
    'tab': Icons.keyboard_tab,
    'arrow_left': Icons.arrow_back,
    'arrow_right': Icons.arrow_forward,
    'arrow_up': Icons.arrow_upward,
    'arrow_down': Icons.arrow_downward,
    'home': Icons.vertical_align_top,
    'end': Icons.vertical_align_bottom,
    'backspace': Icons.backspace_outlined,
    'delete': Icons.delete_outline,
    'copy': Icons.copy,
    'cut': Icons.content_cut,
    'paste': Icons.content_paste,
    'save': Icons.save_outlined,
    'search': Icons.search,
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

/// 小键盘单个按键数据模型
class KeyboardKeyItem {
  /// 显示文本（当 icon 为空或不存在时渲染）
  final String label;

  /// 内置图标常量名称，非空且在内置库存在时优先渲染图标
  final String? icon;

  /// 动作类型：
  /// - 'input': 普通文本输入（默认）
  /// - 'pair': 括号/引号等成对符号，支持选区包裹与光标偏移
  /// - 'command': 编辑器动作命令，例如 'cursor_left', 'tab', 'undo' 等
  final String action;

  /// 动作附带值（输入的文本或命令名称）
  final String value;

  /// 光标插入后的相对偏移（如 pair \"()\" 插入后光标向左移动 1 位，则为 -1）
  final int cursorOffset;

  const KeyboardKeyItem({
    required this.label,
    this.icon,
    this.action = 'input',
    required this.value,
    this.cursorOffset = 0,
  });

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

  factory VirtualKeyboardConfig.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final List<KeyboardPageItem> parsedPages = [];

    for (final p in rawPages) {
      if (p is Map<String, dynamic>) {
        parsedPages.add(KeyboardPageItem.fromJson(p));
      }
    }

    return VirtualKeyboardConfig(
      pages: parsedPages.isNotEmpty ? parsedPages : _defaultConfig().pages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  /// 校验 JSON 文本合法性，若合法返回 null，若非法返回具体错误描述
  static String? validateJson(String jsonStr) {
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
          } else {
            return '第 $pageNum 页第 $rowNum 行第 $keyNum 个按键类型错误，只能是文本字符串或对象';
          }
        }
      }
    }

    return null;
  }

  /// 默认配置预设
  static VirtualKeyboardConfig defaultConfiguration() => _defaultConfig();

  static VirtualKeyboardConfig _defaultConfig() {
    return const VirtualKeyboardConfig(
      pages: [
        // Page 1: 常用标点与成对符号 (每行 6 格)
        KeyboardPageItem(
          count: 6,
          keys: [
            [
              KeyboardKeyItem(label: 'Tab', icon: 'tab', action: 'command', value: 'tab'),
              KeyboardKeyItem(label: '(', action: 'pair', value: '()', cursorOffset: -1),
              KeyboardKeyItem(label: ')', action: 'input', value: ')'),
              KeyboardKeyItem(label: '{', action: 'pair', value: '{}', cursorOffset: -1),
              KeyboardKeyItem(label: '}', action: 'input', value: '}'),
              KeyboardKeyItem(label: ';', action: 'input', value: ';'),
            ],
            [
              KeyboardKeyItem(label: '<-', icon: 'arrow_left', action: 'command', value: 'cursor_left'),
              KeyboardKeyItem(label: '->', icon: 'arrow_right', action: 'command', value: 'cursor_right'),
              KeyboardKeyItem(label: '[', action: 'pair', value: '[]', cursorOffset: -1),
              KeyboardKeyItem(label: ']', action: 'input', value: ']'),
              KeyboardKeyItem(label: '"', action: 'pair', value: '""', cursorOffset: -1),
              KeyboardKeyItem(label: "'", action: 'pair', value: "''", cursorOffset: -1),
            ],
          ],
        ),
        // Page 2: 常用操作与运算符 (每行 6 格)
        KeyboardPageItem(
          count: 6,
          keys: [
            [
              KeyboardKeyItem(label: '撤销', icon: 'undo', action: 'command', value: 'undo'),
              KeyboardKeyItem(label: '重做', icon: 'redo', action: 'command', value: 'redo'),
              KeyboardKeyItem(label: '=', action: 'input', value: '='),
              KeyboardKeyItem(label: '+', action: 'input', value: '+'),
              KeyboardKeyItem(label: '-', action: 'input', value: '-'),
              KeyboardKeyItem(label: '*', action: 'input', value: '*'),
            ],
            [
              KeyboardKeyItem(label: '/', action: 'input', value: '/'),
              KeyboardKeyItem(label: ':', action: 'input', value: ':'),
              KeyboardKeyItem(label: ',', action: 'input', value: ','),
              KeyboardKeyItem(label: '.', action: 'input', value: '.'),
              KeyboardKeyItem(label: '!', action: 'input', value: '!'),
              KeyboardKeyItem(label: '?', action: 'input', value: '?'),
            ],
          ],
        ),
      ],
    );
  }

  /// 转换为格式化好的默认 JSON 字符串
  static String defaultJsonPretty() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_defaultConfig().toJson());
  }
}
