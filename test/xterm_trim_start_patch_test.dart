// 守护测试：验证内置（vendored）xterm 的 IndexAwareCircularBuffer.trimStart() 补丁。
//
// 上游 4.0.0 的 trimStart() 只调整 _startIndex/_length，导致：
//   ① 存活行 index 偏移“被裁掉的行数” → CellAnchor.offset 错位、选区画不出、复制为空；
//   ② 被裁掉的行从不 _detach → 僵尸锚点（attached 仍为 true，静默指向别的行）。
// 触发链：shell 的 clear / Ctrl+L → ESC[3J → Buffer.clearScrollback() → trimStart()。
//
// 若将来升级 xterm 后本文件失败，说明补丁丢失（或上游改动了实现），
// 处理方式见 packages/xterm/PATCHES.md。
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

/// 核心不变量：列表中第 i 行的 `index` 必须等于 i（`CellAnchor.y` 依赖它当行号用）。
void expectIndexInvariant(xterm.Terminal terminal) {
  final buffer = terminal.buffer;
  for (var i = 0; i < buffer.height; i++) {
    expect(
      buffer.lines[i].index,
      i,
      reason: '第 $i 行的 index 与行号不一致 —— trimStart 补丁失效',
    );
  }
}

/// 当前可见视口（不含回滚缓冲）的文本快照。
String visibleText(xterm.Terminal terminal) {
  final buffer = terminal.buffer;
  final scrollBack = buffer.scrollBack;
  final builder = StringBuffer();
  for (var i = 0; i < buffer.viewHeight; i++) {
    builder.writeln(buffer.lines[scrollBack + i].getText().trimRight());
  }
  return builder.toString();
}

xterm.Terminal buildFilledTerminal() {
  final terminal = xterm.Terminal(maxLines: 30);
  terminal.resize(80, 10);
  for (var i = 0; i < 40; i++) {
    terminal.write('L$i\r\n');
  }
  return terminal;
}

void main() {
  group('vendored xterm trimStart 补丁守护测试', () {
    test('push 溢出裁剪（maxLines 上限）保持行索引不变式', () {
      final terminal = buildFilledTerminal();

      // 溢出裁剪由 push 完成，本身维持不变式，作为对照组
      expect(terminal.buffer.height, 30);
      expect(terminal.buffer.scrollBack, greaterThan(0));
      expectIndexInvariant(terminal);
    });

    test('ESC[3J 清空回滚缓冲后行索引归一、可见画面保留', () {
      final terminal = buildFilledTerminal();
      final heightBefore = terminal.buffer.height;
      final visibleBefore = visibleText(terminal);

      terminal.write('\x1b[3J');

      expect(terminal.buffer.height, lessThan(heightBefore));
      expect(terminal.buffer.height, terminal.buffer.viewHeight);
      expect(terminal.buffer.scrollBack, 0);
      // 补丁前：lines[0].index == 20（被裁掉的行数）
      expectIndexInvariant(terminal);
      expect(visibleText(terminal), visibleBefore, reason: '清除回滚不得改动可见画面');
    });

    test('被裁掉行上的锚点被正确失效，存活行上的锚点重新对齐', () {
      final terminal = buildFilledTerminal();
      final buffer = terminal.buffer;

      final droppedAnchor = buffer.createAnchorFromOffset(const xterm.CellOffset(0, 0));
      final survivingAnchor =
          buffer.createAnchorFromOffset(xterm.CellOffset(0, buffer.height - 1));
      expect(droppedAnchor.attached, isTrue);
      expect(survivingAnchor.attached, isTrue);

      terminal.write('\x1b[3J');

      // ① 被裁掉的行走 _dropChild -> detach，旧锚点不再“僵尸”存活
      expect(droppedAnchor.attached, isFalse, reason: '被裁掉的行必须被 detach');
      // ② 存活下来的行索引重新对齐到新行号
      expect(survivingAnchor.attached, isTrue);
      expect(survivingAnchor.offset.y, buffer.height - 1);
      expect(survivingAnchor.line, same(buffer.lines[buffer.height - 1]));
    });

    test('清空回滚缓冲后新建选区落在可见行范围内且能读出文本', () {
      final terminal = buildFilledTerminal();

      // 真实 clear 命令序列（xterm-256color 带 E3 能力）
      terminal.write('\x1b[H\x1b[2J\x1b[3J');
      terminal.write('\x1b[31mERROR\x1b[0m hello world\r\nsecond line\r\n');

      expectIndexInvariant(terminal);

      final begin = terminal.buffer.createAnchorFromOffset(const xterm.CellOffset(0, 0));
      final end = terminal.buffer.createAnchorFromOffset(const xterm.CellOffset(5, 0));
      expect(begin.offset.y, 0);
      expect(end.offset.y, 0);
      expect(begin.offset.y, lessThan(terminal.buffer.height));

      final range = xterm.BufferRangeLine(begin.offset, end.offset).normalized;
      expect(terminal.buffer.getText(range), 'ERROR');
    });
  });
}
