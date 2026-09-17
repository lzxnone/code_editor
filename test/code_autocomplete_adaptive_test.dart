import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/widgets/code_autocomplete_view.dart';
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
  });
}
