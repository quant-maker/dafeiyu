import 'package:feiyu/memory/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('day keys', () {
    test('dayKey pads and parseDayKey round-trips', () {
      final d = DateTime(2026, 3, 7, 15, 30);
      expect(dayKey(d), '2026-03-07');
      expect(parseDayKey('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('parseDayKey rejects junk and impossible dates', () {
      expect(parseDayKey('2026-3-7'), isNull);
      expect(parseDayKey('2026-13-01'), isNull);
      expect(parseDayKey('2026-02-30'), isNull);
      expect(parseDayKey(''), isNull);
    });

    test('dayStart strips the clock', () {
      expect(dayStart(DateTime(2026, 11, 25, 23, 59, 59)), DateTime(2026, 11, 25));
      expect(dayEnd(DateTime(2026, 11, 25, 1)), DateTime(2026, 11, 26));
    });
  });

  group('week keys', () {
    test('Monday starts the week', () {
      // 2026-11-25 是周三，所在周的周一是 11-23。
      expect(weekStart(DateTime(2026, 11, 25)), DateTime(2026, 11, 23));
      expect(weekStart(DateTime(2026, 11, 23)), DateTime(2026, 11, 23));
      expect(weekStart(DateTime(2026, 11, 29)), DateTime(2026, 11, 23));
    });

    test('weekKey uses the ISO year of that week', () {
      expect(weekKey(DateTime(2026, 11, 25)), '2026-W48');
      // 2027-01-01 是周五，属于 2026 年第 53 周。
      expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
      expect(weekKey(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('weekLabel points at the Monday', () {
      expect(weekLabel('2026-W48'), '11月23日那周');
    });
  });

  group('month keys', () {
    test('monthKey and label', () {
      expect(monthKey(DateTime(2026, 11, 25)), '2026-11');
      expect(monthLabel('2026-11'), '2026年11月');
    });
  });

  group('completeness', () {
    final now = DateTime(2026, 11, 25, 14, 0);

    test('yesterday is complete, today is not yet', () {
      expect(isDayComplete(DateTime(2026, 11, 24), now), isTrue);
      expect(isDayComplete(DateTime(2026, 11, 25), now), isFalse);
      expect(isDayComplete(DateTime(2026, 11, 25), DateTime(2026, 11, 25, 23, 5)), isTrue);
      expect(isDayComplete(DateTime(2026, 11, 26), now), isFalse);
    });

    test('week is complete once next Monday arrives', () {
      final monday = DateTime(2026, 11, 23);
      expect(isWeekComplete(monday, now), isFalse);
      expect(isWeekComplete(monday, DateTime(2026, 11, 30, 0, 1)), isTrue);
    });

    test('month is complete once next month arrives', () {
      expect(isMonthComplete(DateTime(2026, 11, 5), now), isFalse);
      expect(isMonthComplete(DateTime(2026, 11, 5), DateTime(2026, 12, 1)), isTrue);
    });
  });
}
