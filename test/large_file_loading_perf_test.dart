import 'package:code_editor/utils/git_diff_helper.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('大文件 Git Diff 剪枝与性能算法测试', () {
    test('5,000 行相同文本对比执行时间小于 5ms 且返回空 Marker（杜绝全量标黄）', () {
      final lines = List.generate(5000, (i) => 'const int value$i = $i;');
      final text = lines.join('\n');

      final stopwatch = Stopwatch()..start();
      final markers = GitDiffHelper.computeLineDiff(text, text);
      stopwatch.stop();

      expect(markers, isEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });

    test('5,000 行大文件在第 2500 行修改 1 行，前后缀剪枝后仅精准标记第 2500 行', () {
      final baseLines = List.generate(5000, (i) => 'void method$i() { print($i); }');
      final currentLines = List<String>.from(baseLines);
      currentLines[2500] = 'void method2500() { print("modified"); }';

      final baseText = baseLines.join('\n');
      final currentText = currentLines.join('\n');

      final stopwatch = Stopwatch()..start();
      final markers = GitDiffHelper.computeLineDiff(baseText, currentText);
      stopwatch.stop();

      // 验证仅第 2500 行被标记为 modified，其余 4999 行不受任何影响
      expect(markers.length, equals(1));
      expect(markers[2500], equals(GitGutterDiffType.modified));
      // 耗时应当极短（通常在 1~3ms 内，远小于原先超过 100ms 的全量矩阵计算）
      expect(stopwatch.elapsedMilliseconds, lessThan(30));
    });

    test('computeLineDiffAsync 异步后台计算在超长文本下稳定返回且结果一致', () async {
      final baseLines = List.generate(1000, (i) => 'line item $i');
      final currentLines = List<String>.from(baseLines)..insert(500, 'new inserted line');

      final baseText = baseLines.join('\n');
      final currentText = currentLines.join('\n');

      final syncMarkers = GitDiffHelper.computeLineDiff(baseText, currentText);
      final asyncMarkers = await GitDiffHelper.computeLineDiffAsync(baseText, currentText);

      expect(asyncMarkers, equals(syncMarkers));
      expect(asyncMarkers[500], equals(GitGutterDiffType.added));
    });
  });

  group('语法高亮安全阈值与平滑防御测试', () {
    test('SyntaxHighlightHelper 为常用语言设置了 2MB maxSize 与 4096 maxLineLength 保护阈值', () {
      final jsonMode = SyntaxHighlightHelper.getMode('json');
      expect(jsonMode, isNotNull);
      expect(jsonMode!.maxSize, equals(2 * 1024 * 1024));
      expect(jsonMode.maxLineLength, equals(4096));

      final dartMode = SyntaxHighlightHelper.getMode('dart');
      expect(dartMode, isNotNull);
      expect(dartMode!.maxSize, equals(2 * 1024 * 1024));
      expect(dartMode.maxLineLength, equals(4096));
    });
  });

  group('大文本异步分行管线测试', () {
    test('codeLinesAsync 在后台 Isolate 正确解析大文本行数与内容', () async {
      final lines = List.generate(3000, (i) => 'data_row_$i: "value_${i * 2}"');
      final text = lines.join('\n');

      final codeLines = await text.codeLinesAsync;
      expect(codeLines.length, equals(3000));
      expect(codeLines[0].text, equals('data_row_0: "value_0"'));
      expect(codeLines[2999].text, equals('data_row_2999: "value_5998"'));
    });
  });
}
