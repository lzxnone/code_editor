import 'package:flutter/material.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:re_highlight/styles/vs2015.dart';

/// 代码编辑器专用独立主题模型
///
/// 代码编辑器主题完全独立于 App 全局的 Light/Dark 主题，
/// 明确定义自身的所有背景色、前景色、高亮色、行号色与选区颜色。
class EditorTheme {
  /// 主题唯一标识
  final String id;

  /// 主题展示名称
  final String name;

  /// 是否为暗色系
  final bool isDark;

  /// 编辑区背景色
  final Color backgroundColor;

  /// 编辑区普通文本颜色（未被高亮命中的字符、普通变量名、标点等）
  final Color textColor;

  /// 行号与折叠三角等指示器文字颜色
  final Color gutterTextColor;

  /// 当前光标所在行的行号高亮颜色
  final Color focusedGutterTextColor;

  /// 行号区背景色（若为 null 则与编辑区背景色一致）
  final Color? gutterBackgroundColor;

  /// 光标颜色
  final Color cursorColor;

  /// 当前行背景高亮颜色
  final Color? cursorLineColor;

  /// 文本选区背景高亮颜色
  final Color selectionColor;

  /// 语法高亮映射表 (re_highlight 样式映射)
  final Map<String, TextStyle> highlightTheme;

  const EditorTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.backgroundColor,
    required this.textColor,
    required this.gutterTextColor,
    required this.focusedGutterTextColor,
    this.gutterBackgroundColor,
    required this.cursorColor,
    this.cursorLineColor,
    required this.selectionColor,
    required this.highlightTheme,
  });

  // ==========================================
  // 内置预设主题 (Presets)
  // ==========================================

  /// Atom One Dark (经典暗色，默认主题)
  static const EditorTheme atomOneDark = EditorTheme(
    id: 'atom-one-dark',
    name: 'Atom One Dark',
    isDark: true,
    backgroundColor: Color(0xFF282C34),
    textColor: Color(0xFFABB2BF),
    gutterTextColor: Color(0xFF5C6370),
    focusedGutterTextColor: Color(0xFFABB2BF),
    cursorColor: Color(0xFF528BFF),
    cursorLineColor: Color(0x1FFFFFFF),
    selectionColor: Color(0x40528BFF),
    highlightTheme: atomOneDarkTheme,
  );

  /// Atom One Light (经典明亮浅色)
  static const EditorTheme atomOneLight = EditorTheme(
    id: 'atom-one-light',
    name: 'Atom One Light',
    isDark: false,
    backgroundColor: Color(0xFFFAFAFA),
    textColor: Color(0xFF383A42),
    gutterTextColor: Color(0xFFA0A1A7),
    focusedGutterTextColor: Color(0xFF383A42),
    cursorColor: Color(0xFF526FFF),
    cursorLineColor: Color(0x0F000000),
    selectionColor: Color(0x30526FFF),
    highlightTheme: atomOneLightTheme,
  );

  /// GitHub Dark (GitHub 暗色)
  static const EditorTheme githubDark = EditorTheme(
    id: 'github-dark',
    name: 'GitHub Dark',
    isDark: true,
    backgroundColor: Color(0xFF0D1117),
    textColor: Color(0xFFC9D1D9),
    gutterTextColor: Color(0xFF8B949E),
    focusedGutterTextColor: Color(0xFFC9D1D9),
    cursorColor: Color(0xFF58A6FF),
    cursorLineColor: Color(0x16FFFFFF),
    selectionColor: Color(0x3D58A6FF),
    highlightTheme: githubDarkTheme,
  );

  /// GitHub Light (GitHub 浅色)
  static const EditorTheme githubLight = EditorTheme(
    id: 'github-light',
    name: 'GitHub Light',
    isDark: false,
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF24292E),
    gutterTextColor: Color(0xFF959DA5),
    focusedGutterTextColor: Color(0xFF24292E),
    cursorColor: Color(0xFF0366D6),
    cursorLineColor: Color(0x0A000000),
    selectionColor: Color(0x330366D6),
    highlightTheme: githubTheme,
  );

  /// Monokai Sublime (高对比度深色)
  static const EditorTheme monokaiSublime = EditorTheme(
    id: 'monokai-sublime',
    name: 'Monokai Sublime',
    isDark: true,
    backgroundColor: Color(0xFF23241F),
    textColor: Color(0xFFF8F8F2),
    gutterTextColor: Color(0xFF75715E),
    focusedGutterTextColor: Color(0xFFF8F8F2),
    cursorColor: Color(0xFFF8F8F0),
    cursorLineColor: Color(0x1FFFFFFF),
    selectionColor: Color(0x4049483E),
    highlightTheme: monokaiSublimeTheme,
  );

  /// VS 2015 / Visual Studio Dark
  static const EditorTheme vs2015 = EditorTheme(
    id: 'vs2015',
    name: 'Visual Studio Dark',
    isDark: true,
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFDCDCDC),
    gutterTextColor: Color(0xFF858585),
    focusedGutterTextColor: Color(0xFFDCDCDC),
    cursorColor: Color(0xFFA6A6A6),
    cursorLineColor: Color(0x15FFFFFF),
    selectionColor: Color(0x40264F78),
    highlightTheme: vs2015Theme,
  );

  /// 所有支持的预设主题列表
  static const List<EditorTheme> presets = [
    atomOneDark,
    atomOneLight,
    githubDark,
    githubLight,
    monokaiSublime,
    vs2015,
  ];

  /// 根据 ID 查找主题，若不存在则回退至默认主题
  static EditorTheme fromId(String? id) {
    if(id == null || id.isEmpty) return atomOneDark;
    return presets.firstWhere(
      (theme) => theme.id == id,
      orElse: () => atomOneDark,
    );
  }
}
