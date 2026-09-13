import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../models/virtual_keyboard_config.dart';
import 'virtual_keyboard_sink.dart';

/// 解析 xterm 的 [TerminalKey] 枚举名，失败返回 null。
///
/// 模型层只保存字符串名（不依赖 xterm），由这里完成到枚举的映射，
/// 名称的合法性在保存配置时已由 [KeyboardScopeHelper.isSupportedTerminalKey] 校验。
TerminalKey? resolveTerminalKey(String name) {
  for (final key in TerminalKey.values) {
    if (key.name == name) return key;
  }
  return null;
}

/// 终端实现：把按键语义写入 xterm 终端。
///
/// 所有输入都经 `Terminal.onOutput`，在 `TerminalSession` 中该回调被接到
/// PTY，因此这里等价于用户真按了键盘。
/// 注意不要用 `TerminalSession.write()`——那是往屏幕缓冲区写显示内容。
class TerminalKeyboardSink implements VirtualKeyboardSink {
  final Terminal terminal;
  final FocusNode? focusNode;

  TerminalKeyboardSink({required this.terminal, this.focusNode});

  @override
  void sendText(String text, {bool appendEnter = false}) {
    if (text.isEmpty && !appendEnter) return;

    var payload = text;
    // 避免用户已在 value 里写了换行时再补一个，造成双回车
    if (appendEnter && !payload.endsWith('\r') && !payload.endsWith('\n')) {
      payload = '$payload\r';
    }
    if (payload.isEmpty) return;

    // 多字符或含换行时走 paste：会遵循 bracketed paste mode，更安全
    if (payload.length > 1 || payload.contains('\n') || payload.contains('\r')) {
      terminal.paste(payload);
    } else {
      terminal.textInput(payload);
    }
  }

  @override
  void sendPair(String pairText, int cursorOffset) {
    // 终端没有"包裹选区 + 光标偏移"的语义，降级为直接发送文本
    sendText(pairText);
  }

  @override
  void sendCommand(String command) {
    switch (command.toLowerCase().trim()) {
      case 'keyboard_hide':
      case 'hide_keyboard':
        hideKeyboard();
        break;
      default:
        // 编辑区命令在终端无意义；配置校验已禁止，这里仅作兜底
        if (kDebugMode) {
          debugPrint('[VirtualKeyboard] 终端不支持编辑器命令: $command');
        }
    }
  }

  @override
  void sendNamedKey(String keyName, {KeyboardKeyMods mods = KeyboardKeyMods.none}) {
    // 字母键走 charInput：无修饰时就是该字母本身，Ctrl/Alt 组合由 xterm 换算
    if (KeyboardScopeHelper.isLetterKeyName(keyName)) {
      final lowerCode = keyName.codeUnitAt(3) + 0x20; // keyC -> 'c'
      final handled = terminal.charInput(lowerCode, ctrl: mods.ctrl, alt: mods.alt);
      if (handled) return;

      // charInput 不支持的组合（无修饰 / 仅 Shift / Ctrl+非字母）按普通文本发送，
      // 与 xterm 自身 `_onInsert` 的"先按键、后退化为文本"策略一致
      final letter = String.fromCharCode(lowerCode);
      terminal.textInput(mods.shift ? letter.toUpperCase() : letter);
      return;
    }

    final key = resolveTerminalKey(keyName);
    if (key == null) {
      if (kDebugMode) {
        debugPrint('[VirtualKeyboard] 未知的终端特殊键: $keyName');
      }
      return;
    }

    final handled = terminal.keyInput(
      key,
      ctrl: mods.ctrl,
      alt: mods.alt,
      shift: mods.shift,
    );
    if (!handled && kDebugMode) {
      // 例如 keytab 中不存在的组合：不会产生任何输出
      debugPrint('[VirtualKeyboard] 该按键组合在终端不会产生输出: $keyName'
          '${mods.isEmpty ? '' : ' ($mods)'}');
    }
  }

  @override
  void hideKeyboard() {
    focusNode?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}
