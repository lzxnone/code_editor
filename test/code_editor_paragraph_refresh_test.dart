// 回归测试：非折行模式（wordWrap == false）下，文本改动必须立即重排“显示段落”。
//
// 背景：为缓解“双指缩放/横向滚动抖动”，`_CodeFieldRender._updateDisplayRenderParagraphs()`
// 里曾为非折行模式加过一个 startIndex 复用缓存分支：仅当 startIndex 变化或视口跑出已建段落
// 范围时才 clear()+重建。于是“按键已生效（控制器内容变了、脏标记也正确）但屏幕仍绘制旧段落”，
// 表现为小键盘按键像失灵、文字不动却变脏。
// 抖动真因（行高 StrutStyle forceStrutHeight 约束缺失）修复后，该缓存分支已删除，本文件守住行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

/// 从渲染树中取出真正用于绘制的显示段落（`_CodeFieldRender` 为库内私有类型，按类型名匹配）
List<CodeLineRenderParagraph> displayParagraphs(WidgetTester tester) {
  final render = tester.allRenderObjects.firstWhere(
    (object) => object.runtimeType.toString() == '_CodeFieldRender',
    orElse: () => throw StateError('渲染树中找不到 _CodeFieldRender'),
  );
  final dynamic field = render;
  return (field.displayParagraphs as List).cast<CodeLineRenderParagraph>();
}

/// 取指定行号对应的显示段落
CodeLineRenderParagraph paragraphOfLine(WidgetTester tester, int lineIndex) {
  return displayParagraphs(tester).firstWhere(
    (paragraph) => paragraph.index == lineIndex,
    orElse: () => throw StateError('显示段落中找不到第 $lineIndex 行'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('非折行模式下文本改动立即重排显示段落', () {
    const firstLineText = 'Line 0: const value = 0;';

    Future<CodeLineEditingController> pumpEditor(WidgetTester tester) async {
      // 文档行数足够填满视口：已建段落覆盖整个可视区，正是“复用缓存”生效的前提
      final text = List.generate(60, (i) => 'Line $i: const value = $i;').join('\n');
      final controller = CodeLineEditingController.fromText(text);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CodeEditor(
                controller: controller,
                wordWrap: false,
                // paddingTop 必须为 0（应用侧同样是 fromLTRB(6,0,0,0)）：
                // paddingTop > 0 时 `target < _displayParagraphs.first.top` 恒成立，
                // 会让缓存分支每次都重建，从而掩盖本缺陷。
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 光标固定到首行行首，确保改动落在可见行上
      controller.selection = CodeLineSelection.collapsed(index: 0, offset: 0);
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('小键盘输入单个字符 ";" 后显示段落立即刷新（不依赖滚动）', (tester) async {
      final controller = await pumpEditor(tester);

      expect(paragraphOfLine(tester, 0).length, firstLineText.length);

      // 等价于小键盘 / 硬件键盘按键：只改控制器内容，屏幕不滚动
      controller.replaceSelection(';');
      await tester.pumpAndSettle();

      final expectedLength = controller.text.split('\n').first.length;
      expect(expectedLength, firstLineText.length + 1, reason: '按键必须真正写入控制器');
      expect(
        paragraphOfLine(tester, 0).length,
        expectedLength,
        reason: '屏幕显示段落必须与控制器同步刷新',
      );
    });

    testWidgets('小键盘输入组合字符 "()" 后显示段落立即刷新', (tester) async {
      final controller = await pumpEditor(tester);

      controller.replaceSelection('()');
      await tester.pumpAndSettle();

      final expectedLength = controller.text.split('\n').first.length;
      expect(expectedLength, firstLineText.length + 2);
      expect(paragraphOfLine(tester, 0).length, expectedLength);
    });

    testWidgets('插入换行后显示段落立即拆分，后续行整体下移', (tester) async {
      final controller = await pumpEditor(tester);

      expect(paragraphOfLine(tester, 0).length, firstLineText.length);
      expect(paragraphOfLine(tester, 1).length, 'Line 1: const value = 1;'.length);

      controller.replaceSelection('\n');
      await tester.pumpAndSettle();

      expect(controller.text.split('\n').length, 61);
      // 原首行被拆成“空行 + 原内容”，屏幕段落必须同步反映
      expect(paragraphOfLine(tester, 0).length, 0, reason: '首段应变为空行');
      expect(
        paragraphOfLine(tester, 1).length,
        firstLineText.length,
        reason: '原来的首行内容必须出现在第 2 段（屏幕未重排时会残留旧文本）',
      );
    });
  });
}
