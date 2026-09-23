import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/models/lsp_language_config.dart';
import 'package:code_editor/services/code_completion/smart_prompts_builder.dart';
import 'package:code_editor/utils/file_icon_utils.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Minecraft (.mcfunction) Support Tests', () {
    test('SyntaxHighlightHelper maps .mcfunction to mcfunction language ID', () {
      expect(SyntaxHighlightHelper.getLanguageId('test.mcfunction'), equals('mcfunction'));
      expect(SyntaxHighlightHelper.getLanguageId('data/pack/functions/tick.mcfunction'), equals('mcfunction'));
      expect(SyntaxHighlightHelper.getLanguageId('TICK.MCFUNCTION'), equals('mcfunction'));
    });

    test('SyntaxHighlightHelper retrieves CodeHighlightThemeMode for mcfunction', () {
      final mode = SyntaxHighlightHelper.getMode('mcfunction');
      expect(mode, isNotNull);

      final fileModes = SyntaxHighlightHelper.getLanguagesForFile('main.mcfunction');
      expect(fileModes.containsKey('mcfunction'), isTrue);
      expect(fileModes['mcfunction'], equals(mode));

      final grammar = SyntaxHighlightHelper.getGrammarModeForFile('test.mcfunction');
      expect(grammar, isNotNull);
      expect(grammar!.name, equals('Minecraft Function'));
    });

    test('SyntaxHighlightHelper renders syntax highlighted TextSpan for mcfunction lines', () {
      const testCode = 'execute as @a[tag=admin] at @s run setblock ~ ~1 ~ minecraft:stone';
      final span = SyntaxHighlightHelper.highlightLine(
        code: testCode,
        filePath: 'test.mcfunction',
        baseStyle: const TextStyle(color: Colors.white),
        highlightTheme: {
          'keyword': const TextStyle(color: Colors.blue),
          'variable': const TextStyle(color: Colors.yellow),
          'symbol': const TextStyle(color: Colors.green),
          'built_in': const TextStyle(color: Colors.purple),
        },
      );

      expect(span.toPlainText(), equals(testCode));
      expect(span.children, isNotEmpty);
    });

    test('LspLanguageConfig has mcfunction (Spyglass) preset with correct parameters', () {
      final preset = LspLanguageConfig.findBuiltinByExtension('.mcfunction');
      expect(preset, isNotNull);
      expect(preset!.id, equals('mcfunction'));
      expect(preset.name, equals('Minecraft Function'));
      expect(preset.languageId, equals('mcfunction'));
      expect(preset.serverCommand, equals('spyglassmc'));
      expect(preset.serverArgs, equals(['--stdio']));
      expect(preset.package, equals('@spyglassmc/language-server'));
      expect(preset.fileExtensions, contains('.mcfunction'));
      expect(preset.installCommand, contains('@spyglassmc/language-server'));
    });

    test('FileIconUtils returns distinct icons for .mcfunction and pack.mcmeta', () {
      final mcfunctionIcon = FileIconUtils.getIcon(name: 'tick.mcfunction');
      expect(mcfunctionIcon, equals(Icons.integration_instructions_outlined));

      final packIcon = FileIconUtils.getIcon(name: 'pack.mcmeta');
      expect(packIcon, equals(Icons.inventory_2_outlined));
    });

    testWidgets('SmartCodeAutocompletePromptsBuilder correctly triggers completion on @ and \$ tokens', (tester) async {
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
        SmartPrompt(word: '@a', kind: SmartPromptKind.field),
        SmartPrompt(word: '@e', kind: SmartPromptKind.field),
        SmartPrompt(word: '\$macro_var', kind: SmartPromptKind.constant),
        SmartPrompt(word: 'execute', kind: SmartPromptKind.keyword),
      ]);

      final builder = SmartCodeAutocompletePromptsBuilder(
        customProviders: [provider],
      );

      // Test @ selector trigger
      final resFuture = builder.build(
        testContext,
        const CodeLine('execute as @'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 12, extentIndex: 0, extentOffset: 12),
      );
      expect(resFuture, isA<Future<CodeAutocompleteEditingValue?>>());
      final res = await (resFuture as Future<CodeAutocompleteEditingValue?>);
      expect(res, isNotNull);
      expect(res!.prompts.any((p) => p.word.startsWith('@')), isTrue);

      // Test $ macro trigger
      final macroResFuture = builder.build(
        testContext,
        const CodeLine('say \$'),
        const CodeLineSelection(baseIndex: 0, baseOffset: 5, extentIndex: 0, extentOffset: 5),
      );
      expect(macroResFuture, isA<Future<CodeAutocompleteEditingValue?>>());
      final macroRes = await (macroResFuture as Future<CodeAutocompleteEditingValue?>);
      expect(macroRes, isNotNull);
      expect(macroRes!.prompts.any((p) => p.word.startsWith('\$')), isTrue);
    });
  });
}
