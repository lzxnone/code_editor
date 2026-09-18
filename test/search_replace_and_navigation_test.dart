import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/utils/case_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaseUtils.applyPreserveCase Tests', () {
    test('ALL UPPERCASE preserves to uppercase', () {
      expect(
        CaseUtils.applyPreserveCase(original: 'HELLO', replacement: 'world'),
        'WORLD',
      );
      expect(
        CaseUtils.applyPreserveCase(original: 'A', replacement: 'b'),
        'B',
      );
    });

    test('all lowercase preserves to lowercase', () {
      expect(
        CaseUtils.applyPreserveCase(original: 'hello', replacement: 'WORLD'),
        'world',
      );
      expect(
        CaseUtils.applyPreserveCase(original: 'a', replacement: 'B'),
        'b',
      );
    });

    test('Title Case / Capitalized preserves to Capitalized', () {
      expect(
        CaseUtils.applyPreserveCase(original: 'Hello', replacement: 'world'),
        'World',
      );
      expect(
        CaseUtils.applyPreserveCase(original: 'Hello', replacement: 'WORLD'),
        'World',
      );
      expect(
        CaseUtils.applyPreserveCase(original: 'H', replacement: 'w'),
        'W',
      );
    });

    test('Mixed or empty cases fallback appropriately', () {
      expect(
        CaseUtils.applyPreserveCase(original: 'hElLo', replacement: 'world'),
        'world',
      );
      expect(
        CaseUtils.applyPreserveCase(original: '', replacement: 'world'),
        'world',
      );
      expect(
        CaseUtils.applyPreserveCase(original: 'hello', replacement: ''),
        '',
      );
    });
  });

  group('SearchProvider preserveCase Tests', () {
    test('togglePreserveCase updates options properly', () {
      final provider = SearchProvider();
      expect(provider.preserveCase, isFalse);

      provider.togglePreserveCase();
      expect(provider.preserveCase, isTrue);

      provider.setPreserveCase(false);
      expect(provider.preserveCase, isFalse);
    });
  });

  group('TabProvider Search Handlers Registration Tests', () {
    test('registerSearchHandlers and callbacks execution', () {
      final tabProvider = TabProvider();
      int nextCount = 0;
      int prevCount = 0;
      int replaceCount = 0;

      tabProvider.registerSearchHandlers(
        findNext: () => nextCount++,
        findPrevious: () => prevCount++,
        replace: () => replaceCount++,
      );

      tabProvider.findNext();
      expect(nextCount, 1);

      tabProvider.findPrevious();
      expect(prevCount, 1);

      tabProvider.replaceCurrent();
      expect(replaceCount, 1);

      // Unregister
      tabProvider.registerSearchHandlers();
      tabProvider.findNext();
      tabProvider.findPrevious();
      tabProvider.replaceCurrent();

      expect(nextCount, 1);
      expect(prevCount, 1);
      expect(replaceCount, 1);
    });
  });
}
