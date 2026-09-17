import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

class _MockLspCompletionProvider implements CompletionProvider {
  final List<SmartPrompt> mockPrompts;
  _MockLspCompletionProvider(this.mockPrompts);

  @override
  String get id => 'mock_lsp';

  @override
  bool get isAsync => true;

  @override
  Future<List<SmartPrompt>> provideCompletions(CompletionContext context) async {
    return mockPrompts;
  }

  @override
  void dispose() {}
}

void main() {
  group('SmartCodeAutocompletePromptsBuilder LSP Tests', () {
    testWidgets('SmartCodeAutocompletePromptsBuilder requests LSP asynchronously and applies fuzzy filter', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      final provider = _MockLspCompletionProvider([
        SmartPrompt(word: 'print', kind: SmartPromptKind.function),
        SmartPrompt(word: 'printf', kind: SmartPromptKind.function, type: 'int printf(const char *format, ...)'),
        SmartPrompt(word: 'length', kind: SmartPromptKind.field),
        SmartPrompt(word: 'FloatingActionButton', kind: SmartPromptKind.type),
      ]);

      final builder = SmartCodeAutocompletePromptsBuilder(
        customProviders: [provider],
      );

      // 1. Normal prefix 'pri'
      final res1Future = builder.build(
        testContext,
        const CodeLine('pri'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 3, extentIndex: 0, extentOffset: 3),
      );
      expect(res1Future, isA<Future<CodeAutocompleteEditingValue?>>());
      final res1 = await (res1Future as Future<CodeAutocompleteEditingValue?>);
      expect(res1, isNotNull);
      expect(res1!.prompts.map((p) => p.word), containsAll(['print', 'printf']));

      // 2. Typo correction: 'prnt' -> matches 'print'
      final res2 = await (builder.build(
        testContext,
        const CodeLine('prnt'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 4, extentIndex: 0, extentOffset: 4),
      ) as Future<CodeAutocompleteEditingValue?>);
      expect(res2, isNotNull);
      expect(res2!.prompts.map((p) => p.word), contains('print'));

      // 3. Typo correction: 'lenght' -> matches 'length'
      final res3 = await (builder.build(
        testContext,
        const CodeLine('lenght'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 6, extentIndex: 0, extentOffset: 6),
      ) as Future<CodeAutocompleteEditingValue?>);
      expect(res3, isNotNull);
      expect(res3!.prompts.map((p) => p.word), contains('length'));

      // 4. CamelCase: 'fab' -> matches 'FloatingActionButton'
      final res4 = await (builder.build(
        testContext,
        const CodeLine('fab'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 3, extentIndex: 0, extentOffset: 3),
      ) as Future<CodeAutocompleteEditingValue?>);
      expect(res4, isNotNull);
      expect(res4!.prompts.first.word, equals('FloatingActionButton'));
    });

    testWidgets('字符串字面量内部不触发补全', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      final provider = _MockLspCompletionProvider([
        SmartPrompt(word: 'printf', kind: SmartPromptKind.function),
      ]);

      final builder = SmartCodeAutocompletePromptsBuilder(
        customProviders: [provider],
      );

      // 光标处于 "hello pri" 内部
      final res = builder.build(
        testContext,
        const CodeLine('"hello pri"'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 10, extentIndex: 0, extentOffset: 10),
      );
      expect(res, isNull);
    });

    testWidgets('输入点 . 触发符能正确触发异步补全', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      final provider = _MockLspCompletionProvider([
        SmartPrompt(word: 'size', kind: SmartPromptKind.field),
        SmartPrompt(word: 'clear', kind: SmartPromptKind.function),
      ]);

      final builder = SmartCodeAutocompletePromptsBuilder(
        customProviders: [provider],
      );

      final res = await (builder.build(
        testContext,
        const CodeLine('list.'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 5, extentIndex: 0, extentOffset: 5),
      ) as Future<CodeAutocompleteEditingValue?>);

      expect(res, isNotNull);
      expect(res!.prompts.map((p) => p.word), containsAll(['size', 'clear']));
    });

    testWidgets('当禁用 LSP 补全时直接返回 null 不打扰输入', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      final builder = SmartCodeAutocompletePromptsBuilder(
        enableLspCompletion: false,
      );

      final res = builder.build(
        testContext,
        const CodeLine('pri'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 3, extentIndex: 0, extentOffset: 3),
      );

      // 未装配任何 provider，直接返回 null
      expect(res, isNull);
    });
  });
}
