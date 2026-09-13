import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

/// 以指定背景色重建终端主题。
///
/// xterm 的 `TerminalTheme` 没有 copyWith 且全部字段必填，所以这里基于
/// `TerminalThemes.defaultTheme` 复制一份，只替换背景；当背景偏亮时同步把
/// 前景、光标切换为深色，避免浅色背景下文字看不清。
xterm.TerminalTheme terminalThemeWithBackground(Color background) {
  final base = xterm.TerminalThemes.defaultTheme;
  final isLight = background.computeLuminance() > 0.5;

  return xterm.TerminalTheme(
    cursor: isLight ? const Color(0xFF1F1F1F) : base.cursor,
    selection: base.selection,
    foreground: isLight ? const Color(0xFF1F1F1F) : base.foreground,
    background: background,
    black: base.black,
    white: base.white,
    red: base.red,
    green: base.green,
    yellow: base.yellow,
    blue: base.blue,
    magenta: base.magenta,
    cyan: base.cyan,
    brightBlack: base.brightBlack,
    brightRed: base.brightRed,
    brightGreen: base.brightGreen,
    brightYellow: base.brightYellow,
    brightBlue: base.brightBlue,
    brightMagenta: base.brightMagenta,
    brightCyan: base.brightCyan,
    brightWhite: base.brightWhite,
    searchHitBackground: base.searchHitBackground,
    searchHitBackgroundCurrent: base.searchHitBackgroundCurrent,
    searchHitForeground: base.searchHitForeground,
  );
}
