import 'package:code_editor/services/code_completion/fuzzy_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuzzyMatcher Tests', () {
    test('Exact match gives highest score', () {
      final res = FuzzyMatcher.match('print', 'print');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThanOrEqualTo(2000));
    });

    test('Case-sensitive prefix match', () {
      final res = FuzzyMatcher.match('pri', 'print');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThanOrEqualTo(1500));
    });

    test('Case-insensitive prefix match', () {
      final res = FuzzyMatcher.match('pri', 'PrintStream');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThanOrEqualTo(1000));
    });

    test('CamelCase match (e.g. fb -> FloatingActionButton)', () {
      final res = FuzzyMatcher.match('fab', 'FloatingActionButton');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThanOrEqualTo(500));
      expect(res.matchedIndices, equals([0, 8, 14]));
    });

    test('Snake_case match (e.g. tf -> text_field)', () {
      final res = FuzzyMatcher.match('tf', 'text_field');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThanOrEqualTo(500));
      expect(res.matchedIndices, equals([0, 5]));
    });

    test('Subsequence match', () {
      final res = FuzzyMatcher.match('pnt', 'print');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThan(400));
    });

    test('Typo tolerance / error correction (e.g. prnt -> print)', () {
      final res = FuzzyMatcher.match('prnt', 'print');
      expect(res.isMatch, isTrue);
    });

    test('Typo tolerance with 1 char mistake (e.g. prib -> print)', () {
      final res = FuzzyMatcher.match('prib', 'print');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThan(100));
    });

    test('Typo tolerance for length mistake (e.g. lenght -> length)', () {
      final res = FuzzyMatcher.match('lenght', 'length');
      expect(res.isMatch, isTrue);
      expect(res.score, greaterThan(100));
    });

    test('Completely unrelated word does not match', () {
      final res = FuzzyMatcher.match('xyz', 'print');
      expect(res.isMatch, isFalse);
    });
  });
}
