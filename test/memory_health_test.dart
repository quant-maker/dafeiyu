import 'package:feiyu/memory/db.dart';
import 'package:feiyu/memory/store.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryHealth _health({
  int episodes = 0,
  int facts = 0,
  int entities = 0,
  int oldestAt = 0,
  int newestAt = 0,
}) {
  return MemoryHealth(
    episodes: episodes,
    facts: facts,
    entities: entities,
    edges: 0,
    dayCards: 0,
    weekCards: 0,
    monthCards: 0,
    localOnly: 0,
    oldestAt: oldestAt,
    newestAt: newestAt,
    conflicts: const <FactConflict>[],
    staleStars: const <Entity>[],
    generatedAt: 0,
  );
}

void main() {
  group('memory health', () {
    test('an empty memory has no fullness and no span', () {
      final h = _health();
      expect(h.fullness, 0);
      expect(h.spanDays, 0);
    });

    test('fullness rises with episodes, facts and stars', () {
      final onlyEpisodes = _health(episodes: 30);
      final all = _health(episodes: 30, facts: 15, entities: 20);
      expect(onlyEpisodes.fullness, closeTo(0.5, 0.001));
      expect(all.fullness, closeTo(1.0, 0.001));
      expect(all.fullness, greaterThan(onlyEpisodes.fullness));
    });

    test('fullness saturates instead of overflowing', () {
      final h = _health(episodes: 999, facts: 999, entities: 999);
      expect(h.fullness, 1.0);
    });

    test('span counts both ends inclusively', () {
      final day = 24 * 60 * 60 * 1000;
      final start = DateTime(2026, 11, 1).millisecondsSinceEpoch;
      final h = _health(oldestAt: start, newestAt: start + 4 * day);
      expect(h.spanDays, 5);
    });

    test('a single episode spans one day', () {
      final t = DateTime(2026, 11, 25, 9).millisecondsSinceEpoch;
      final h = _health(oldestAt: t, newestAt: t);
      expect(h.spanDays, 0);
    });
  });
}
