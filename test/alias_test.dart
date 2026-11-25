import 'package:feiyu/memory/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aliases', () {
    test('splits, trims and drops empties', () {
      expect(splitAliases('王总|老王'), <String>['王总', '老王']);
      expect(splitAliases(' 王总 | 老王 |'), <String>['王总', '老王']);
      expect(splitAliases(''), isEmpty);
      expect(splitAliases(null), isEmpty);
    });

    test('dedupes by normalized text', () {
      expect(splitAliases('老王|老 王'), <String>['老王']);
    });

    test('joins back without duplicates', () {
      expect(joinAliases(<String>['王总', '王总', '老王']), '王总|老王');
      expect(joinAliases(const <String>[]), '');
    });

    test('round-trips', () {
      const raw = '王总|老王';
      expect(joinAliases(splitAliases(raw)), raw);
    });
  });

  group('looksSameEntity', () {
    test('identical names after trimming count as the same', () {
      expect(looksSameEntity('老王', ' 老 王 '), isTrue);
    });

    test('a short name inside a longer one within two chars counts', () {
      expect(looksSameEntity('老王', '老王头'), isTrue);
      expect(looksSameEntity('quant', 'quant-labs'), isFalse);
    });

    test('refuses to merge when the gap is too big', () {
      expect(looksSameEntity('王', '王总工程师'), isFalse);
      expect(looksSameEntity('ai', 'ai infra team lead'), isFalse);
    });

    test('refuses empty or single-character overlap', () {
      expect(looksSameEntity('', '老王'), isFalse);
      expect(looksSameEntity('a', 'ab'), isFalse);
    });

    test('unrelated names stay apart', () {
      expect(looksSameEntity('老王', '小李'), isFalse);
    });
  });
}
