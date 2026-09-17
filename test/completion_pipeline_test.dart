import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:code_editor/services/lsp/lsp_protocol.dart';
import 'package:code_editor/widgets/editor/editor_diagnostic_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAsyncProvider implements CompletionProvider {
  final List<SmartPrompt> results;
  _MockAsyncProvider(this.results);

  @override
  String get id => 'mock_async';

  @override
  bool get isAsync => true;

  @override
  Future<List<SmartPrompt>> provideCompletions(CompletionContext context) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return results;
  }

  @override
  void dispose() {}
}

void main() {
  group('Completion Pipeline Architecture Tests', () {
    test('LspCompletionProvider.fromLspItem maps kinds and details correctly', () {
      final lspItem = LspCompletionItem(
        label: 'printf',
        kind: 3, // Function
        detail: 'int printf(const char *format, ...)',
        insertText: 'printf',
      );

      final prompt = LspCompletionProvider.fromLspItem(lspItem);
      expect(prompt.word, equals('printf'));
      expect(prompt.kind, equals(SmartPromptKind.function));
      expect(prompt.type, equals('int printf(const char *format, ...)'));
    });

    test('CompletionEngine.requestCompletionsAsync directly resolves LSP completions with fuzzy score & sorting', () async {
      final asyncLsp = _MockAsyncProvider([
        SmartPrompt(
          word: 'printf',
          kind: SmartPromptKind.function,
          type: 'int printf(const char *format, ...)',
          sortText: '0001',
        ),
        SmartPrompt(
          word: 'print_custom',
          kind: SmartPromptKind.function,
          sortText: '0002',
        ),
      ]);

      final engine = CompletionEngine(providers: [asyncLsp]);

      final ctx = CompletionContext(
        input: 'pri',
        lineIndex: 0,
        characterOffset: 3,
        codeLine: const CodeLine('pri'),
        selection: const CodeLineSelection(baseIndex: 0, baseOffset: 3, extentIndex: 0, extentOffset: 3),
      );

      final result = await engine.requestCompletionsAsync(ctx);
      expect(result, isNotNull);
      expect(result!.prompts, isNotEmpty);
      expect(result.prompts.first.word, equals('printf'));
      expect((result.prompts.first as SmartPrompt).type, equals('int printf(const char *format, ...)'));
      expect(result.prompts.map((p) => p.word), contains('print_custom'));
    });

    test('CompletionEngine drops stale request when new request is initiated', () async {
      final asyncLsp = _MockAsyncProvider([
        SmartPrompt(
          word: 'printf',
          kind: SmartPromptKind.function,
        ),
      ]);

      final engine = CompletionEngine(providers: [asyncLsp]);

      final ctx1 = CompletionContext(
        input: 'p',
        lineIndex: 0,
        characterOffset: 1,
        codeLine: const CodeLine('p'),
        selection: const CodeLineSelection(baseIndex: 0, baseOffset: 1, extentIndex: 0, extentOffset: 1),
      );

      final ctx2 = CompletionContext(
        input: 'pr',
        lineIndex: 0,
        characterOffset: 2,
        codeLine: const CodeLine('pr'),
        selection: const CodeLineSelection(baseIndex: 0, baseOffset: 2, extentIndex: 0, extentOffset: 2),
      );

      // 发起两次连续请求，前一次会被后一次作为陈旧请求丢弃
      final future1 = engine.requestCompletionsAsync(ctx1);
      final future2 = engine.requestCompletionsAsync(ctx2);

      final res1 = await future1;
      final res2 = await future2;

      expect(res1, isNull); // 过期响应返回 null
      expect(res2, isNotNull); // 最新响应正常返回
    });
  });

  group('EditorDiagnosticController Tests', () {
    testWidgets('EditorDiagnosticController returns base span when no diagnostics exist', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      const controller = EditorDiagnosticController();
      const baseSpan = TextSpan(text: 'int main() {}');
      final result = controller.buildDiagnosticSpans(
        context: ctx,
        filePath: 'test.c',
        index: 0,
        codeLine: const CodeLine('int main() {}'),
        textSpan: baseSpan,
        style: const TextStyle(),
      );

      expect(result.text, equals('int main() {}'));
    });
  });

  group('Completion Switch & Isolation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsProvider lsp completion flag persists properly', () async {
      final provider = SettingsProvider();
      await provider.init();

      expect(provider.enableLspCompletion, isTrue);

      await provider.setEnableLspCompletion(false);
      expect(provider.enableLspCompletion, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('enable_lsp_completion'), isFalse);

      // 重新实例化验证从持久化中正确恢复
      final restoredProvider = SettingsProvider();
      await restoredProvider.init();
      expect(restoredProvider.enableLspCompletion, isFalse);
    });

    test('SmartCodeAutocompletePromptsBuilder provider filtering by flag', () {
      // 1. 默认开启：仅 1 个 LspCompletionProvider
      final builderDefault = SmartCodeAutocompletePromptsBuilder();
      expect(builderDefault.engine.providers.length, equals(1));
      expect(builderDefault.engine.providers.first, isA<LspCompletionProvider>());

      // 2. 关闭 LSP：providers 为空
      final builderDisabled = SmartCodeAutocompletePromptsBuilder(
        enableLspCompletion: false,
      );
      expect(builderDisabled.engine.providers.isEmpty, isTrue);
    });

    test('Pure Backend Mode: SmartCodeAutocompletePromptsBuilder.build returns Future that resolves LSP completions', () async {
      final asyncLsp = _MockAsyncProvider([
        SmartPrompt(
          word: 'printf',
          kind: SmartPromptKind.function,
          type: 'int printf(const char *format, ...)',
        ),
      ]);

      final builder = SmartCodeAutocompletePromptsBuilder(
        customProviders: [asyncLsp],
      );

      final result = builder.build(
        _FakeBuildContext(),
        const CodeLine('pri'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 3, extentIndex: 0, extentOffset: 3),
      );

      expect(result, isA<Future<CodeAutocompleteEditingValue?>>());
      final resolved = await (result as Future<CodeAutocompleteEditingValue?>);
      expect(resolved, isNotNull);
      expect(resolved!.prompts.length, equals(1));
      final prompt = resolved.prompts.first as SmartPrompt;
      expect(prompt.word, equals('printf'));
      expect(prompt.type, equals('int printf(const char *format, ...)'));
    });
  });
}

class _FakeBuildContext extends Fake implements BuildContext {}
