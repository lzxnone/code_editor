import 'package:code_editor/utils/git_conflict_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取出某个冲突块在正文中的原始文本，便于断言替换范围是否正确
String _blockText(List<String> lines, GitConflictBlock block) {
  return lines.sublist(block.startLine, block.endLine + 1).join('\n');
}

void main() {
  group('标准风格冲突标记', () {
    test('解析单个冲突块的位置与两侧来源', () {
      const content = 'line1\n'
          '<<<<<<< HEAD\n'
          'ours-a\n'
          'ours-b\n'
          '=======\n'
          'theirs-a\n'
          '>>>>>>> feature\n'
          'line2';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isFalse);
      expect(result.hasConflicts, isTrue);
      expect(result.blocks.length, equals(1));

      final block = result.blocks.first;
      expect(block.startLine, equals(1));
      expect(block.endLine, equals(6));
      expect(block.oursLabel, equals('HEAD'));
      expect(block.theirsLabel, equals('feature'));
      expect(block.hasBaseSegment, isFalse);

      final lines = content.split('\n');
      // ours 段覆盖第 2~3 行（两个内容行）
      expect(block.ours.startLine, equals(2));
      expect(block.ours.endLine, equals(4));
      expect(
        lines.sublist(block.ours.startLine, block.ours.endLine).join('\n'),
        equals('ours-a\nours-b'),
      );
      // theirs 段覆盖第 5 行
      expect(
        lines.sublist(block.theirs.startLine, block.theirs.endLine).join('\n'),
        equals('theirs-a'),
      );
    });

    test('解析多个冲突块且顺序不乱', () {
      const content = 'a\n'
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

      final result = GitConflictParser.parse(content);
      expect(result.blocks.length, equals(2));
      expect(result.blocks[0].startLine, equals(1));
      expect(result.blocks[1].startLine, equals(7));
      expect(
        _blockText(content.split('\n'), result.blocks[1]),
        contains('o2'),
      );
    });

    test('空段可以正确解析（一侧没有内容）', () {
      const content = '<<<<<<< HEAD\n'
          '=======\n'
          'theirs-only\n'
          '>>>>>>> x';

      final result = GitConflictParser.parse(content);
      expect(result.blocks.length, equals(1));
      expect(result.blocks.first.ours.lineCount, equals(0));
      expect(result.blocks.first.theirs.lineCount, equals(1));
    });
  });

  group('diff3 风格冲突标记', () {
    test('解析出共同祖先段', () {
      const content = 'start\n'
          '<<<<<<< HEAD\n'
          'ours-line\n'
          '||||||| merged common ancestors\n'
          'base-line\n'
          '=======\n'
          'theirs-line\n'
          '>>>>>>> feature\n'
          'end';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isFalse);
      expect(result.blocks.length, equals(1));

      final block = result.blocks.first;
      expect(block.hasBaseSegment, isTrue);
      expect(block.startLine, equals(1));
      expect(block.endLine, equals(7));

      final lines = content.split('\n');
      expect(
        lines.sublist(block.ours.startLine, block.ours.endLine).join('\n'),
        equals('ours-line'),
      );
      expect(
        lines.sublist(block.base!.startLine, block.base!.endLine).join('\n'),
        equals('base-line'),
      );
      expect(
        lines.sublist(block.theirs.startLine, block.theirs.endLine).join('\n'),
        equals('theirs-line'),
      );
    });

    test('diff3 下基线段为空也能解析', () {
      const content = '<<<<<<< HEAD\n'
          'ours\n'
          '||||||| base\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> x';

      final result = GitConflictParser.parse(content);
      expect(result.blocks.length, equals(1));
      expect(result.blocks.first.hasBaseSegment, isTrue);
      expect(result.blocks.first.base!.lineCount, equals(0));
    });
  });

  group('结构异常时必须放弃自动解析', () {
    // 关键安全要求：宁可不解析，也不能按错误位置改写用户代码

    test('标记未闭合 → malformed 且不返回任何块', () {
      const content = '<<<<<<< HEAD\n'
          'ours\n'
          '=======\n'
          'theirs\n';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isTrue);
      expect(result.blocks, isEmpty);
      expect(result.malformedReason, contains('未闭合'));
    });

    test('缺少分隔线 → malformed', () {
      const content = '<<<<<<< HEAD\n'
          'ours\n'
          '>>>>>>> x\n';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isTrue);
      expect(result.malformedReason, contains('分隔线'));
    });

    test('嵌套起始标记 → malformed', () {
      const content = '<<<<<<< HEAD\n'
          'ours\n'
          '<<<<<<< HEAD\n'
          'nested\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> x\n';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isTrue);
      expect(result.malformedReason, contains('嵌套'));
    });

    test('同一块内多个分隔线 → malformed', () {
      const content = '<<<<<<< HEAD\n'
          'ours\n'
          '=======\n'
          'middle\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> x\n';

      final result = GitConflictParser.parse(content);
      expect(result.isMalformed, isTrue);
      expect(result.blocks, isEmpty);
    });
  });

  group('边界情况', () {
    test('无冲突标记时返回空结果且不算异常', () {
      final result = GitConflictParser.parse('just\nnormal\ncode\n');
      expect(result.hasConflicts, isFalse);
      expect(result.isMalformed, isFalse);
      expect(result.blocks, isEmpty);
    });

    test('空文件与空字符串安全', () {
      expect(GitConflictParser.parse('').blocks, isEmpty);
      expect(GitConflictParser.parse('').isMalformed, isFalse);
    });

    test('冲突块位于文件开头与结尾都能解析', () {
      const content = '<<<<<<< HEAD\n'
          'o\n'
          '=======\n'
          't\n'
          '>>>>>>> x';
      final result = GitConflictParser.parse(content);
      expect(result.blocks.length, equals(1));
      expect(result.blocks.first.startLine, equals(0));
      expect(result.blocks.first.endLine, equals(4));
    });

    test('正文里单独的 ======= 不会被误判为冲突', () {
      // 只有 <<<<<<< 与 >>>>>>> 同时出现才算冲突
      const content = 'title\n'
          '=======\n'
          'subtitle\n';
      final result = GitConflictParser.parse(content);
      expect(result.hasConflicts, isFalse);
      expect(result.isMalformed, isFalse);
    });

    test('containsMarkers 只在两者都存在时为真', () {
      expect(GitConflictParser.containsMarkers('<<<<<<< a\n>>>>>>> b'), isTrue);
      expect(GitConflictParser.containsMarkers('<<<<<<< a'), isFalse);
      expect(GitConflictParser.containsMarkers('>>>>>>> b'), isFalse);
      expect(GitConflictParser.containsMarkers('normal'), isFalse);
    });

    test('rebase 场景下 ours 标签是远端、theirs 标签是自己的提交', () {
      // 这正是 UI 不能写"我的/对方的"的原因
      const content = '<<<<<<< HEAD\n'
          'remote-version\n'
          '=======\n'
          'my-version\n'
          '>>>>>>> 1a2b3c4 (my commit)';
      final result = GitConflictParser.parse(content);
      final block = result.blocks.first;
      expect(block.oursLabel, equals('HEAD'));
      expect(block.theirsLabel, contains('1a2b3c4'));
    });
  });

  group('逐块替换（解决冲突的核心算法）', () {
    const twoBlocks = 'header\n'
        '<<<<<<< HEAD\n'
        'ours-1\n'
        '=======\n'
        'theirs-1\n'
        '>>>>>>> x\n'
        'middle\n'
        '<<<<<<< HEAD\n'
        'ours-2\n'
        '=======\n'
        'theirs-2\n'
        '>>>>>>> x\n'
        'footer';

    test('替换第一个块只影响该块范围，其余原样保留', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      expect(parsed.blocks.length, equals(2));

      final result = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'RESOLVED-1',
      );

      expect(result, isNotNull);
      expect(result!, contains('header'));
      expect(result, contains('RESOLVED-1'));
      expect(result, contains('middle'));
      expect(result, contains('footer'));
      // 第一个块的标记没了
      expect(result, isNot(contains('ours-1')));
      expect(result, isNot(contains('theirs-1')));
      // 第二个块完好无损
      expect(result, contains('ours-2'));
      expect(result, contains('theirs-2'));
    });

    test('替换第二个块时第一个块不受影响', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      final result = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 1,
        replacement: 'RESOLVED-2',
      );

      expect(result, isNotNull);
      expect(result!, contains('ours-1'));
      expect(result, contains('theirs-1'));
      expect(result, contains('RESOLVED-2'));
      expect(result, isNot(contains('ours-2')));
    });

    test('替换为空字符串即删除该块内容', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      final result = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: '',
      );

      expect(result, isNotNull);
      // 块内容被整段移除，剩下 header/middle/第二个块/footer
      expect(result!.split('\n')[0], equals('header'));
      expect(result.split('\n')[1], equals('middle'));
      expect(result, isNot(contains('ours-1')));
    });

    test('多行替换内容保留全部行', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      final result = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'line-a\nline-b\nline-c',
      );

      expect(result, isNotNull);
      expect(result!, contains('line-a\nline-b\nline-c'));
    });

    test('末尾空串不会多插空行', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      final result = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'only\n',
      );
      // 'only\n' 应等价于 'only'
      final result2 = GitConflictParser.replaceBlock(
        content: twoBlocks,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'only',
      );
      expect(result, equals(result2));
    });

    test('越界索引返回 null 而不是破坏内容', () {
      final parsed = GitConflictParser.parse(twoBlocks);
      expect(
        GitConflictParser.replaceBlock(
          content: twoBlocks,
          blocks: parsed.blocks,
          blockIndex: 5,
          replacement: 'x',
        ),
        isNull,
      );
      expect(
        GitConflictParser.replaceBlock(
          content: twoBlocks,
          blocks: parsed.blocks,
          blockIndex: -1,
          replacement: 'x',
        ),
        isNull,
      );
    });

    test('逐个替换两块后不再有标记', () {
      // 模拟用户逐块点选：每替换一次都重新解析（行号会移动）
      var content = twoBlocks;
      var parsed = GitConflictParser.parse(content);
      expect(parsed.blocks.length, equals(2));

      content = GitConflictParser.replaceBlock(
        content: content,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'R1',
      )!;
      parsed = GitConflictParser.parse(content);
      expect(parsed.blocks.length, equals(1), reason: '重解析后应只剩一块');

      content = GitConflictParser.replaceBlock(
        content: content,
        blocks: parsed.blocks,
        blockIndex: 0,
        replacement: 'R2',
      )!;
      parsed = GitConflictParser.parse(content);

      expect(parsed.blocks, isEmpty);
      expect(content, contains('R1'));
      expect(content, contains('R2'));
      // 全部标记清除
      expect(content, isNot(contains('<<<<<<<')));
      expect(content, isNot(contains('>>>>>>>')));
    });

    test('countMarkers 快速统计残留块数', () {
      expect(GitConflictParser.countMarkers(twoBlocks), equals(2));
      expect(GitConflictParser.countMarkers('clean file\n'), equals(0));
    });
  });
}
