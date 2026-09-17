import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:code_editor/widgets/code_autocomplete_view.dart';
import 'package:code_editor/widgets/editor/editor_overlay_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('Editor Overlay Hierarchy Tests', () {
    testWidgets('CodeAutocomplete uses local EditorOverlayScope instead of root overlay', (tester) async {
      final controller = CodeLineEditingController.fromText('pri');
      final promptsBuilder = SmartCodeAutocompletePromptsBuilder(
        controller: controller,
        directPrompts: [
          CodeKeywordPrompt(word: 'printf'),
        ],
      );

      bool tappedBottomButton = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: EditorOverlayScope(
                    child: CodeAutocomplete(
                      viewBuilder: (context, notifier, onSelected) {
                        promptsBuilder.activeNotifier = notifier;
                        return CodeAutocompleteView(
                          notifier: notifier,
                          onSelected: onSelected,
                        );
                      },
                      promptsBuilder: promptsBuilder,
                      child: CodeEditor(
                        autofocus: false,
                        controller: controller,
                      ),
                    ),
                  ),
                ),
                // 模拟小键盘（在 Column 中位于 Editor 下方）
                GestureDetector(
                  key: const ValueKey('virtual_keyboard_btn'),
                  onTap: () {
                    tappedBottomButton = true;
                  },
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    color: Colors.blue,
                    child: const Text('Virtual Key ;'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 获取当前所有的 Overlay
      final overlays = tester.widgetList<Overlay>(find.byType(Overlay)).toList();
      // 至少应该有 2 个 Overlay：1 个是 MaterialApp/Navigator 的 root overlay，1 个是 EditorOverlayScope 的 local overlay
      expect(overlays.length, greaterThanOrEqualTo(2));

      // 验证底部的模拟小键盘正常渲染
      expect(find.byKey(const ValueKey('virtual_keyboard_btn')), findsOneWidget);

      // 点击虚拟小键盘，验证点击事件正常响应且不受干扰
      await tester.tap(find.byKey(const ValueKey('virtual_keyboard_btn')));
      expect(tappedBottomButton, isTrue);

      // 清理测试组件树
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
