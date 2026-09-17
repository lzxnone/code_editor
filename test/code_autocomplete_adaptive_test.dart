import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/widgets/code_autocomplete_view.dart';
import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('CodeAutocomplete Adaptive Height and Scrolling Tests', () {
    test('CodeAutocompleteView preferredSize dynamically adapts to prompt count', () {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        const CodeAutocompleteEditingValue(
          input: '',
          prompts: [
            CodeKeywordPrompt(word: 'first'),
          ],
          index: 0,
        ),
      );

      final view1 = CodeAutocompleteView(
        notifier: notifier,
        onSelected: (_) {},
      );

      // 1 item: 1 * 36.0 + 8.0 + 2.0 = 46.0
      expect(view1.preferredSize.height, equals(46.0));

      // 2 items: 2 * 36.0 + 10.0 = 82.0
      notifier.value = const CodeAutocompleteEditingValue(
        input: '',
        prompts: [
          CodeKeywordPrompt(word: 'first'),
          CodeKeywordPrompt(word: 'second'),
        ],
        index: 0,
      );
      final view2 = CodeAutocompleteView(
        notifier: notifier,
        onSelected: (_) {},
      );
      expect(view2.preferredSize.height, equals(82.0));

      // 3 items: 3 * 36.0 + 10.0 = 118.0
      notifier.value = const CodeAutocompleteEditingValue(
        input: '',
        prompts: [
          CodeKeywordPrompt(word: 'first'),
          CodeKeywordPrompt(word: 'second'),
          CodeKeywordPrompt(word: 'third'),
        ],
        index: 0,
      );
      final view3 = CodeAutocompleteView(
        notifier: notifier,
        onSelected: (_) {},
      );
      expect(view3.preferredSize.height, equals(118.0));

      // 10 items capped at default max height 196.0
      notifier.value = CodeAutocompleteEditingValue(
        input: '',
        prompts: List.generate(10, (i) => CodeKeywordPrompt(word: 'item_$i')),
        index: 0,
      );
      final view10 = CodeAutocompleteView(
        notifier: notifier,
        onSelected: (_) {},
      );
      expect(view10.preferredSize.height, equals(196.0));

      notifier.dispose();
    });

    testWidgets('CodeAutocompleteView scrolls smoothly when constrained in limited height', (tester) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        const CodeAutocompleteEditingValue(
          input: '',
          prompts: [
            CodeKeywordPrompt(word: 'option_1'),
            CodeKeywordPrompt(word: 'option_2'),
            CodeKeywordPrompt(word: 'option_3'),
          ],
          index: 0,
        ),
      );

      String? selectedWord;

      // 空间不足：强制限制高度为 80.0（只能完整显示约 2 项，第 3 项需要滑动）
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 270.0,
                height: 80.0,
                child: CodeAutocompleteView(
                  notifier: notifier,
                  onSelected: (result) {
                    selectedWord = (result as dynamic).word as String?;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('option_1'), findsOneWidget);
      expect(find.text('option_2'), findsOneWidget);

      // 模拟选择第 3 个项目，触发自动滚动
      notifier.value = notifier.value.copyWith(index: 2);
      await tester.pumpAndSettle();

      // 滑动或选择后，第 3 项可见且可点击
      expect(find.text('option_3'), findsOneWidget);
      await tester.tap(find.text('option_3'));
      await tester.pump();

      expect(selectedWord, equals('option_3'));

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    });

    testWidgets('Autocomplete does not dismiss on scrolling or operating virtual keyboard, only on tapping editor outside menu', (tester) async {
      final controller = CodeLineEditingController.fromText('foo\nbar\nbaz');
      final promptsBuilder = DefaultCodeAutocompletePromptsBuilder(
        directPrompts: [
          const CodeKeywordPrompt(word: 'foo_item1'),
          const CodeKeywordPrompt(word: 'foo_item2'),
        ],
      );

      bool virtualKeyPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: CodeAutocomplete(
                    viewBuilder: (context, notifier, onSelected) {
                      return CodeAutocompleteView(
                        notifier: notifier,
                        onSelected: onSelected,
                      );
                    },
                    promptsBuilder: promptsBuilder,
                    child: CodeEditor(
                      controller: controller,
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('mock_virtual_keyboard'),
                  onTap: () {
                    virtualKeyPressed = true;
                  },
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    color: Colors.grey,
                    child: const Text('Virtual Keyboard Key'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 输入触发补全
      controller.text = 'fo';
      controller.selection = const CodeLineSelection.collapsed(index: 0, offset: 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CodeAutocompleteView), findsOneWidget);

      // 1. 操作小键盘控件：不应关闭菜单
      await tester.tap(find.byKey(const ValueKey('mock_virtual_keyboard')));
      await tester.pump();
      expect(virtualKeyPressed, isTrue);
      expect(find.byType(CodeAutocompleteView), findsOneWidget);

      // 2. 滑动编辑区：上下滑动拖动代码，不应关闭菜单
      final editorFinder = find.byType(CodeEditor);
      await tester.drag(editorFinder, const Offset(0, -60));
      await tester.pump();
      expect(find.byType(CodeAutocompleteView), findsOneWidget);

      // 3. 只有点击到菜单区域外的编辑区，才关闭菜单
      final editorTopLeft = tester.getTopLeft(editorFinder);
      await tester.tapAt(editorTopLeft + const Offset(50, 150));
      await tester.pump();
      expect(find.byType(CodeAutocompleteView), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      controller.dispose();
    });

    testWidgets('CodeAutocompleteView supports bidirectional scrolling without horizontal truncation', (tester) async {
      const longWord = 'extremelyLongMethodNameWithManyArgumentsAndParameters(int foo, String bar, double baz, List<Map<String, dynamic>> nestedOptions)';
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: '',
          prompts: [
            const CodeKeywordPrompt(word: 'short_item'),
            const CodeKeywordPrompt(word: longWord),
            for (int i = 0; i < 8; i++) CodeKeywordPrompt(word: 'vertical_item_$i'),
          ],
          index: 0,
        ),
      );

      String? selectedWord;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 270.0,
                height: 150.0,
                child: CodeAutocompleteView(
                  notifier: notifier,
                  onSelected: (result) {
                    selectedWord = (result as dynamic).word as String?;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify both horizontal and vertical SingleChildScrollViews are present
      final scrollViews = find.byType(SingleChildScrollView);
      expect(scrollViews, findsNWidgets(2));

      // Drag horizontally to test horizontal scrolling
      final horizontalFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontalFinder, findsOneWidget);

      await tester.drag(horizontalFinder, const Offset(-120.0, 0.0));
      await tester.pumpAndSettle();

      final SingleChildScrollView hView = tester.widget(horizontalFinder);
      expect(hView.controller!.offset, greaterThan(0.0));

      // Drag vertically at visible center to test vertical scrolling
      final verticalFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      );
      expect(verticalFinder, findsOneWidget);

      await tester.drag(find.byType(CodeAutocompleteView), const Offset(0.0, -100.0));
      await tester.pumpAndSettle();

      final SingleChildScrollView vView = tester.widget(verticalFinder);
      expect(vView.controller!.offset, greaterThan(0.0));

      // Tap on a visible item after scrolling
      expect(find.text('vertical_item_3'), findsOneWidget);
      await tester.tap(find.text('vertical_item_3'));
      await tester.pump();

      expect(selectedWord, equals('vertical_item_3'));

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    });

    testWidgets('CodeAutocompleteView renders SmartPrompt with long type without ellipsis and allows horizontal scrolling', (tester) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: '',
          prompts: [
            SmartPrompt(
              word: 'veryLongAsyncMethodWithArguments',
              type: 'Future<Map<String, List<CustomModelDefinition>>>',
              kind: SmartPromptKind.function,
            ),
          ],
          index: 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 270.0,
                height: 100.0,
                child: CodeAutocompleteView(
                  notifier: notifier,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final horizontalFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      final SingleChildScrollView hView = tester.widget(horizontalFinder);
      expect(hView.controller!.offset, equals(0.0));

      // Scroll to the right
      await tester.drag(find.byType(CodeAutocompleteView), const Offset(-200.0, 0.0));
      await tester.pumpAndSettle();

      expect(hView.controller!.offset, greaterThan(0.0));

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    });

    testWidgets('CodeAutocompleteView places typeText immediately adjacent to word without pushing to far right', (tester) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: '',
          prompts: [
            SmartPrompt(
              word: 'foo',
              type: 'int',
              kind: SmartPromptKind.field,
            ),
            SmartPrompt(
              word: 'extremelyLongMethodNameThatExpandsTheMenuWidthSignificantly(...)',
              type: 'void',
              kind: SmartPromptKind.function,
            ),
          ],
          index: 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 270.0,
                height: 100.0,
                child: CodeAutocompleteView(
                  notifier: notifier,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final fooFinder = find.text('foo');
      final intFinder = find.text('int');
      expect(fooFinder, findsOneWidget);
      expect(intFinder, findsOneWidget);

      final fooTopRight = tester.getTopRight(fooFinder);
      final intTopLeft = tester.getTopLeft(intFinder);

      // The gap between 'foo' and 'int' should be exactly 8.0 (adjacent), not pushed hundreds of pixels away
      final gap = intTopLeft.dx - fooTopRight.dx;
      expect(gap, closeTo(8.0, 1.0));

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    });
  });
}
