import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../models/virtual_keyboard_config.dart';

/// 虚拟小键盘的输入汇聚接口。
///
/// 键盘组件只负责"按键语义"（文本 / 成对符号 / 编辑器命令 / 命名特殊键），
/// 由具体实现决定把语义落到编辑器还是终端上，避免键盘组件per-scope 分叉。
///
/// 不同作用域对同一语义的支持程度不同，不支持的实现应安全降级为空操作，
/// 绝不静默插入无关内容。
abstract class VirtualKeyboardSink {
  /// 发送一段文本（编辑区：插入；终端：写入 PTY）
  ///
  /// [appendEnter] 仅终端有意义：发送后补一个回车符，实现"输入即执行"
  void sendText(String text, {bool appendEnter = false});

  /// 成对符号：有选区时包裹选区，无选区时插入并把光标按 [cursorOffset] 偏移
  void sendPair(String pairText, int cursorOffset);

  /// 编辑器命令（缩进、撤销、光标移动等）
  void sendCommand(String command);

  /// 命名特殊键（终端：escape / tab / arrowUp / keyC + Ctrl 组合等）
  void sendNamedKey(String keyName, {KeyboardKeyMods mods = KeyboardKeyMods.none});

  /// 收起软键盘
  void hideKeyboard();
}

/// 编辑区实现：把按键语义落到 [CodeLineEditingController] 上
class EditorKeyboardSink implements VirtualKeyboardSink {
  final CodeLineEditingController controller;
  final FocusNode? focusNode;

  EditorKeyboardSink({required this.controller, this.focusNode});

  @override
  void sendText(String text, {bool appendEnter = false}) {
    if (text.isEmpty) return;
    // 编辑区不存在"回车执行"语义，appendEnter 直接忽略（由校验层禁止该组合）
    controller.replaceSelection(text);
  }

  @override
  void sendPair(String pairText, int cursorOffset) {
    final hasSelection = !controller.selection.isCollapsed &&
        controller.selection.baseOffset != -1 &&
        controller.selection.extentOffset != -1;

    if (hasSelection) {
      final selected = controller.selectedText;
      if (pairText.length >= 2) {
        final left = pairText.substring(0, pairText.length ~/ 2);
        final right = pairText.substring(pairText.length ~/ 2);
        controller.replaceSelection(left + selected + right);
      } else {
        controller.replaceSelection(pairText + selected + pairText);
      }
      return;
    }

    controller.replaceSelection(pairText);
    if (cursorOffset != 0) {
      final curSel = controller.selection;
      final targetOffset = (curSel.extentOffset + cursorOffset).clamp(0, controller.extentLine.length);
      controller.selection = CodeLineSelection.collapsed(
        index: curSel.extentIndex,
        offset: targetOffset,
      );
    }
  }

  @override
  void sendCommand(String command) {
    final cmd = command.toLowerCase().trim();
    switch (cmd) {
      case 'tab':
        controller.applyIndent();
        break;
      case 'untab':
      case 'outdent':
        controller.applyOutdent();
        break;
      case 'cursor_left':
      case 'left':
        controller.moveCursor(AxisDirection.left);
        break;
      case 'cursor_right':
      case 'right':
        controller.moveCursor(AxisDirection.right);
        break;
      case 'cursor_up':
      case 'up':
        controller.moveCursor(AxisDirection.up);
        break;
      case 'cursor_down':
      case 'down':
        controller.moveCursor(AxisDirection.down);
        break;
      case 'line_start':
      case 'home':
        controller.moveCursorToLineStart();
        break;
      case 'line_end':
      case 'end':
        controller.moveCursorToLineEnd();
        break;
      case 'page_start':
        controller.moveCursorToPageStart();
        break;
      case 'page_end':
        controller.moveCursorToPageEnd();
        break;
      case 'undo':
        if (controller.canUndo) {
          controller.undo();
        }
        break;
      case 'redo':
        if (controller.canRedo) {
          controller.redo();
        }
        break;
      case 'copy':
        controller.copy();
        break;
      case 'cut':
        controller.cut();
        break;
      case 'paste':
        controller.paste();
        break;
      case 'backspace':
      case 'delete_backward':
        controller.deleteBackward();
        break;
      case 'delete':
      case 'delete_forward':
        controller.deleteForward();
        break;
      case 'select_all':
        controller.selectAll();
        break;
      case 'keyboard_hide':
      case 'hide_keyboard':
        hideKeyboard();
        break;
      default:
        // 未知命令安全降级为直接输入其命令名称或原文本
        controller.replaceSelection(command);
        break;
    }
  }

  @override
  void sendNamedKey(String keyName, {KeyboardKeyMods mods = KeyboardKeyMods.none}) {
    // 编辑区没有"终端命名键"概念；配置校验已禁止该组合，这里仅作兜底不产生副作用
    if (kDebugMode) {
      debugPrint('[VirtualKeyboard] 编辑区不支持命名特殊键: $keyName${mods.isEmpty ? '' : ' ($mods)'}');
    }
  }

  @override
  void hideKeyboard() {
    focusNode?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}
