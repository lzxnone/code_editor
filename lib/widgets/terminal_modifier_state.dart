import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../models/virtual_keyboard_config.dart';

/// 终端修饰键（小键盘上的 Ctrl / Alt / Shift 格）的运行时状态。
///
/// 语义：
/// - 单击 = 一次性：点亮后由**下一次真实输入**带上并自动熄灭
/// - 双击 = 锁定：持续生效，再点一次解除
///
/// 该状态由键盘组件与终端共用，因此它必须独立于 widget 生命周期存在：
/// 终端据此把修饰符叠加到"硬件键盘按键"和"软键盘打进来的字符"上。
class TerminalModifierState extends ChangeNotifier {
  TerminalModifierState({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  /// 双击判定时钟（测试可注入假时钟以确定性地控制单击/双击）
  DateTime Function() clock;

  /// 双击判定窗口
  static const Duration doubleTapWindow = Duration(milliseconds: 350);

  final Set<String> _oneshot = <String>{};
  final Set<String> _locked = <String>{};
  final Map<String, DateTime> _lastTap = <String, DateTime>{};

  bool isActive(String modifier) =>
      _oneshot.contains(modifier) || _locked.contains(modifier);

  bool get isEmpty => _oneshot.isEmpty && _locked.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// 当前生效的修饰符组合
  KeyboardKeyMods get mods => KeyboardKeyMods(
        ctrl: isActive('ctrl'),
        alt: isActive('alt'),
        shift: isActive('shift'),
      );

  /// 单击一次性点亮 / 双击锁定 / 点击已锁定项解除
  void toggle(String modifier) {
    final now = clock();
    final last = _lastTap[modifier];
    final isDoubleTap = last != null && now.difference(last) < doubleTapWindow;

    if (_locked.contains(modifier)) {
      _locked.remove(modifier);
      _oneshot.remove(modifier);
    } else if (isDoubleTap) {
      _oneshot.remove(modifier);
      _locked.add(modifier);
    } else if (_oneshot.contains(modifier)) {
      _oneshot.remove(modifier);
    } else {
      _oneshot.add(modifier);
    }
    _lastTap[modifier] = now;
    notifyListeners();
  }

  /// 一次性状态被一次真实输入消耗（锁定状态保留）
  void consume() {
    if (_oneshot.isEmpty) return;
    _oneshot.clear();
    notifyListeners();
  }

  /// 清空全部状态
  void clear() {
    if (isEmpty) return;
    _oneshot.clear();
    _locked.clear();
    _lastTap.clear();
    notifyListeners();
  }
}

/// 把"软键盘 / IME 直接打进来的文本"按当前修饰键状态改写。
///
/// 软键盘的字符不会产生 Flutter KeyEvent，xterm 内部走的是
/// `terminal.textInput()`，因此只能在 `Terminal.onOutput` 这一层改写。
/// 规则与 xterm 的 `Terminal.charInput` 保持一致：
/// - Ctrl + a~z → 0x01~0x1a
/// - Ctrl + [ \ ] ^ _ → 0x1b~0x1f
/// - Alt + a~z → ESC + 大写字母
/// - Shift + a~z → 大写字母
///
/// 只处理**单个字符**：多字符（粘贴、指令快捷键）原样放过，避免误伤。
/// 返回 null 表示"无需改写"。
String? applyModifierToTypedText(String data, KeyboardKeyMods mods) {
  if (mods.isEmpty) return null;

  final runes = data.runes.toList();
  if (runes.length != 1) return null;

  final code = runes.first;
  final isLetter = (code >= 0x61 && code <= 0x7a) || (code >= 0x41 && code <= 0x5a);
  final lower = (code >= 0x41 && code <= 0x5a) ? code + 0x20 : code;

  if (mods.ctrl) {
    if (isLetter) return String.fromCharCode(lower - 0x61 + 1);
    if (code >= 0x5b && code <= 0x5f) return String.fromCharCode(code - 0x5b + 27);
    return null;
  }

  if (mods.alt && !mods.shift) {
    if (isLetter) return String.fromCharCodes([0x1b, lower - 0x20]);
    return null;
  }

  if (mods.shift && code >= 0x61 && code <= 0x7a) {
    return String.fromCharCode(code - 0x20);
  }

  return null;
}

/// 代理输入处理器：把运行时修饰键叠加到按键事件上，再交给 xterm 默认链路。
///
/// 覆盖硬件键盘与"小键盘 key 格"的按键事件（它们都走 `Terminal.keyInput`）；
/// 软键盘打进来的字符不产生 KeyEvent，由 [applyModifierToTypedText] 处理。
class ModifierAwareInputHandler implements TerminalInputHandler {
  ModifierAwareInputHandler({required this.state, required this.delegate});

  final TerminalModifierState state;
  final TerminalInputHandler delegate;

  @override
  String? call(TerminalKeyboardEvent event) {
    final mods = state.mods;
    final result = delegate(
      mods.isEmpty
          ? event
          : event.copyWith(
              ctrl: event.ctrl || mods.ctrl,
              alt: event.alt || mods.alt,
              shift: event.shift || mods.shift,
            ),
    );

    // 真的产生了输出才消耗一次性状态，避免"按了没反应还把修饰键吃掉"
    if (result != null && mods.isNotEmpty) {
      state.consume();
    }
    return result;
  }
}
