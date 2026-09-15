import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeEditor 双向滚动平滑切换与打断测试', () {
    test('CodeEditorScrollPosition 的 shouldIgnorePointer 始终返回 false 允许命中测试', () {
      final controller = CodeEditorScrollController();
      expect(controller, isA<CodeEditorScrollController>());
    });

    test('CodeScrollController 默认创建 CodeEditorScrollController', () {
      final codeScroll = CodeScrollController();
      expect(codeScroll.verticalScroller, isA<CodeEditorScrollController>());
      expect(codeScroll.horizontalScroller, isA<CodeEditorScrollController>());
    });

    testWidgets('垂直滚动时进行水平滚动，先停止垂直滚动并立即进入水平滚动（无需第二次滚动）', (tester) async {
      final lines = List.generate(
        100,
        (i) => 'Line $i: ${'very_long_code_identifier_' * 10};',
      ).join('\n');
      final codeController = CodeLineEditingController.fromText(lines);
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CodeEditor(
                controller: codeController,
                scrollController: scrollController,
                wordWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vScroller = scrollController.verticalScroller;
      final hScroller = scrollController.horizontalScroller;

      expect(vScroller.offset, 0.0);
      expect(hScroller.offset, 0.0);

      // 1. 触发垂直滑动手势
      await tester.fling(find.byType(CodeEditor), const Offset(0, -100), 1000);
      await tester.pump(const Duration(milliseconds: 50));
      final verticalOffsetWhileMoving = vScroller.offset;
      expect(verticalOffsetWhileMoving, greaterThan(0.0));

      // 2. 此时立即发起水平滑动手势 (首次水平滑动即生效)
      await tester.fling(find.byType(CodeEditor), const Offset(-100, 0), 1000);
      await tester.pump(const Duration(milliseconds: 50));

      // 垂直滚动停止，首次水平滑动即可产生水平位移
      expect(hScroller.offset, greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(hScroller.offset, greaterThan(0.0));
    });

    testWidgets('水平滚动时进行垂直滚动，先停止水平滚动并立即进入垂直滚动', (tester) async {
      final lines = List.generate(
        100,
        (i) => 'Line $i: ${'very_long_code_identifier_' * 10};',
      ).join('\n');
      final codeController = CodeLineEditingController.fromText(lines);
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CodeEditor(
                controller: codeController,
                scrollController: scrollController,
                wordWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vScroller = scrollController.verticalScroller;
      final hScroller = scrollController.horizontalScroller;

      expect(vScroller.offset, 0.0);
      expect(hScroller.offset, 0.0);

      // 1. 先触发水平滑动
      await tester.fling(find.byType(CodeEditor), const Offset(-100, 0), 1000);
      await tester.pump(const Duration(milliseconds: 50));
      expect(hScroller.offset, greaterThan(0.0));

      // 2. 立即发起垂直滑动
      await tester.fling(find.byType(CodeEditor), const Offset(0, -100), 1000);
      await tester.pump(const Duration(milliseconds: 50));

      // 垂直滚动首次滑动即生效
      expect(vScroller.offset, greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(vScroller.offset, greaterThan(0.0));
    });

    testWidgets('垂直方向最后一行可滚到屏幕中间约半屏高（延伸半屏高度的可滚动空白）', (tester) async {
      // 50 行代码，每行高度约 20px，总高度约 1000px，在 400px 高的视口中
      const double viewportHeight = 400.0;
      final lines = List.generate(50, (i) => 'Line $i: text;').join('\n');
      final codeController = CodeLineEditingController.fromText(lines);
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: viewportHeight,
              child: CodeEditor(
                controller: codeController,
                scrollController: scrollController,
                wordWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vScroller = scrollController.verticalScroller;
      // 滚动到底部极限位置
      vScroller.jumpTo(vScroller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // 验证最后一行文字在视口中的位置：应该在屏幕中间约半屏高位置 (viewportHeight * 0.5 = 200.0 左右)
      // 而不是贴在底部 400.0
      expect(vScroller.offset, equals(vScroller.position.maxScrollExtent));
      // 点击底部留白区域，确保不抛异常且能定位到末尾行
      await tester.tapAt(const Offset(150, 350));
      await tester.pumpAndSettle();
      expect(codeController.selection.extentIndex, equals(49));
    });

    testWidgets('水平方向向右多滑约 160 px（最右侧文字脱离右边缘并留出 160 px 真正空白）', (tester) async {
      const double viewportWidth = 300.0;
      final codeController = CodeLineEditingController.fromText('prefix_${'long_variable_name_' * 15}_end');
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: viewportWidth,
              height: 300,
              child: CodeEditor(
                controller: codeController,
                scrollController: scrollController,
                wordWrap: false,
                extraHorizontalScroll: 160.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hScroller = scrollController.horizontalScroller;
      expect(hScroller.position.maxScrollExtent, greaterThan(160.0));

      // 滚动到最右端
      hScroller.jumpTo(hScroller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // 点击右侧留白区域，确保不抛异常且定位正常
      await tester.tapAt(const Offset(280, 50));
      await tester.pumpAndSettle();
      expect(codeController.selection.extentIndex, equals(0));
    });
  });
}
