import 'package:code_editor/utils/git_conflict_parser.dart';
import 'package:code_editor/widgets/git/conflict_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('冲突行模型（VS Code 内联视图的数据来源）', () {
    const standard = 'line1\n'
        '<<<<<<< HEAD\n'
        'ours-a\n'
        'ours-b\n'
        '=======\n'
        'theirs-a\n'
        '>>>>>>> feature\n'
        'line2';

    test('标准风格：标记行变标题带、内容行归属正确', () {
      final parsed = GitConflictParser.parse(standard);
      final lines = ConflictLineBuilder.build(standard, parsed);

      expect(lines.length, equals(8));
      // 行号必须是文件绝对行号（1-based）——上一版页面正是栽在这里
      expect(lines[0].lineNumber, equals(1));
      expect(lines[0].role, equals(ConflictLineRole.context));
      expect(lines[0].text, equals('line1'));

      expect(lines[1].lineNumber, equals(2));
      expect(lines[1].role, equals(ConflictLineRole.oursHeader));
      expect(lines[1].isHeader, isTrue);
      expect(lines[1].blockIndex, equals(0));

      expect(lines[2].role, equals(ConflictLineRole.oursContent));
      expect(lines[3].role, equals(ConflictLineRole.oursContent));

      expect(lines[4].role, equals(ConflictLineRole.separator));

      expect(lines[5].role, equals(ConflictLineRole.theirsContent));

      expect(lines[6].role, equals(ConflictLineRole.theirsHeader));
      expect(lines[6].blockIndex, equals(0));

      expect(lines[7].role, equals(ConflictLineRole.context));
      expect(lines[7].text, equals('line2'));
    });

    test('标题带行保留 git 原始标记文本', () {
      final parsed = GitConflictParser.parse(standard);
      final lines = ConflictLineBuilder.build(standard, parsed);

      expect(lines[1].text, equals('<<<<<<< HEAD'));
      expect(lines[6].text, equals('>>>>>>> feature'));
    });

    test('diff3 风格：基线段被单独标注，且不参与操作', () {
      const diff3 = 'head\n'
          '<<<<<<< HEAD\n'
          'ours\n'
          '||||||| merged common ancestors\n'
          'base\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> x\n'
          'tail';

      final parsed = GitConflictParser.parse(diff3);
      expect(parsed.blocks.first.hasBaseSegment, isTrue);

      final lines = ConflictLineBuilder.build(diff3, parsed);
      final baseHeader = lines.firstWhere(
        (l) => l.role == ConflictLineRole.baseHeader,
      );
      final baseContent = lines.firstWhere(
        (l) => l.role == ConflictLineRole.baseContent,
      );

      expect(baseHeader.text, contains('|||||||'));
      expect(baseContent.text, equals('base'));
      expect(baseContent.lineNumber, equals(5));

      // 基线段不应被当作可操作侧
      expect(baseContent.role, isNot(equals(ConflictLineRole.oursContent)));
      expect(baseContent.role, isNot(equals(ConflictLineRole.theirsContent)));
    });

    test('多个冲突块各自带正确 blockIndex，互不串位', () {
      const two = 'a\n'
          '<<<<<<< HEAD\n'
          'o1\n'
          '=======\n'
          't1\n'
          '>>>>>>> x\n'
          'b\n'
          '<<<<<<< HEAD\n'
          'o2\n'
          '=======\n'
          't2\n'
          '>>>>>>> x\n'
          'c';

      final parsed = GitConflictParser.parse(two);
      final lines = ConflictLineBuilder.build(two, parsed);

      final headers = lines.where((l) => l.isHeader).toList();
      expect(headers.length, equals(4));
      expect(headers[0].blockIndex, equals(0));
      expect(headers[1].blockIndex, equals(0));
      expect(headers[2].blockIndex, equals(1));
      expect(headers[3].blockIndex, equals(1));

      // 上下文行不属于任何块
      final contexts = lines.where((l) => l.role == ConflictLineRole.context);
      expect(contexts.every((l) => l.blockIndex == null), isTrue);
    });

    test('行号连续覆盖整个文件，不丢行不多行', () {
      final parsed = GitConflictParser.parse(standard);
      final lines = ConflictLineBuilder.build(standard, parsed);

      for (var i = 0; i < lines.length; i++) {
        expect(lines[i].lineNumber, equals(i + 1));
      }
      expect(lines.length, equals(standard.split('\n').length));
    });

    test('空段（一侧无内容）不产生内容行但标题与分隔仍在', () {
      const emptyOurs = '<<<<<<< HEAD\n'
          '=======\n'
          'theirs-only\n'
          '>>>>>>> x';

      final parsed = GitConflictParser.parse(emptyOurs);
      final lines = ConflictLineBuilder.build(emptyOurs, parsed);

      expect(lines.length, equals(4));
      expect(lines[0].role, equals(ConflictLineRole.oursHeader));
      expect(lines[1].role, equals(ConflictLineRole.separator));
      expect(lines[2].role, equals(ConflictLineRole.theirsContent));
      expect(lines[3].role, equals(ConflictLineRole.theirsHeader));
      // 没有 oursContent 行
      expect(
        lines.any((l) => l.role == ConflictLineRole.oursContent),
        isFalse,
      );
    });

    test('无冲突文件全部是上下文行', () {
      const clean = 'a\nb\nc';
      final parsed = GitConflictParser.parse(clean);
      final lines = ConflictLineBuilder.build(clean, parsed);

      expect(lines.length, equals(3));
      expect(
        lines.every((l) => l.role == ConflictLineRole.context),
        isTrue,
      );
      expect(ConflictLineBuilder.isFullyResolved(parsed), isTrue);
    });

    test('结构异常的标记不被当成冲突块，行仍全部输出', () {
      const malformed = '<<<<<<< HEAD\nours\n';
      final parsed = GitConflictParser.parse(malformed);
      expect(parsed.isMalformed, isTrue);

      final lines = ConflictLineBuilder.build(malformed, parsed);
      // 解析失败时不应伪造标题带，全部按上下文渲染（用户会看到原始标记文本）
      expect(lines.every((l) => l.role == ConflictLineRole.context), isTrue);
      expect(lines.length, equals(malformed.split('\n').length));
      expect(lines.length, equals(3));
    });
  });

  group('段落文本提取（按绝对行号切分）', () {
    test('从块范围取当前侧与传入侧文本', () {
      const content = 'line1\n'
          '<<<<<<< HEAD\n'
          'ours-a\n'
          'ours-b\n'
          '=======\n'
          'theirs-a\n'
          '>>>>>>> feature\n'
          'line2';

      final parsed = GitConflictParser.parse(content);
      final lines = content.split('\n');
      final block = parsed.blocks.first;

      String seg(int from, int to) =>
          lines.sublist(from.clamp(0, lines.length), to.clamp(0, lines.length)).join('\n');

      expect(seg(block.ours.startLine, block.ours.endLine), equals('ours-a\nours-b'));
      expect(seg(block.theirs.startLine, block.theirs.endLine), equals('theirs-a'));
    });

    test('段落行号越界时被钳制而不是抛异常', () {
      const content = '<<<<<<< HEAD\nours\n=======\n';
      final parsed = GitConflictParser.parse(content);
      // 该内容结构不完整，应被判定为 malformed（不产生块）
      expect(parsed.isMalformed, isTrue);
      expect(parsed.blocks, isEmpty);
    });
  });
}
