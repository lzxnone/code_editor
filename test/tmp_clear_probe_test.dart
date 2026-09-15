// 临时探针测试：验证执行 clear（含 ESC[3J 清空回滚缓冲）之后
// 终端 BufferLine.index / CellAnchor.offset 是否与真实行号错位。
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  test('probe: ESC[3J clearScrollback 之后行索引与锚点是否错位', () {
    final terminal = xterm.Terminal(maxLines: 100);
    for (int i = 0; i < 60; i++) {
      terminal.write('Line $i\r\n');
    }

    final beforeHeight = terminal.buffer.height;
    final viewHeight = terminal.viewHeight;
    // ignore: avoid_print
    print('BEFORE height=$beforeHeight viewHeight=$viewHeight '
        'line0.index=${terminal.buffer.lines[0].index} '
        'lineLast.index=${terminal.buffer.lines[beforeHeight - 1].index}');

    // 真实 clear 命令（xterm-256color, E3）输出序列
    terminal.write('\x1b[H\x1b[2J\x1b[3J');

    final afterHeight = terminal.buffer.height;
    // ignore: avoid_print
    print('AFTER  height=$afterHeight viewHeight=${terminal.viewHeight} '
        'line0.index=${terminal.buffer.lines[0].index} '
        'lineLast.index=${terminal.buffer.lines[afterHeight - 1].index}');

    // 模拟用户在可见区域第一行选中一个词
    final anchor = terminal.buffer.createAnchorFromOffset(const xterm.CellOffset(0, 0));
    final anchor2 = terminal.buffer.createAnchorFromOffset(const xterm.CellOffset(4, 0));
    // ignore: avoid_print
    print('visible row0 anchor y=${anchor.offset.y} (期望 0)  row0 anchor2 y=${anchor2.offset.y}');

    final range = xterm.BufferRangeLine(anchor.offset, anchor2.offset).normalized;
    // ignore: avoid_print
    print('selection range begin=${range.begin} end=${range.end}');
    // ignore: avoid_print
    print('paint guard: lines.length=$afterHeight  segment lines='
        '${range.toSegments().map((s) => s.line).toList()}');
    // ignore: avoid_print
    print('getText(selection)="${terminal.buffer.getText(range)}"');

    terminal.dispose();
  });
}
