import 'package:feiyu/companion/initiative_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rollTo zeroes the counters on a new day and keeps them otherwise', () {
    final InitiativeBudget b = InitiativeBudget(
      day: DateTime(2026, 11, 23),
      sent: 3,
      opportunities: 6,
      ignoredStreak: 2,
    );

    expect(
      b.rollTo(DateTime(2026, 11, 23, 23, 59)),
      isFalse,
      reason: 'same day must not reset',
    );
    expect(b.sent, 3);

    expect(b.rollTo(DateTime(2026, 11, 24, 0, 1)), isTrue);
    expect(b.sent, 0);
    expect(b.opportunities, 0);
    expect(b.ignoredStreak, 0);
    expect(b.day, DateTime(2026, 11, 24));
  });

  test('fromJson survives junk and clamps negatives', () {
    final DateTime now = DateTime(2026, 11, 24, 9);
    final InitiativeBudget b = InitiativeBudget.fromJson(<String, dynamic>{
      'day': 'not a date',
      'sent': -4,
      'opportunities': 'x',
      'ignoredStreak': -1,
    }, now);

    expect(b.day, DateTime(2026, 11, 24));
    expect(b.sent, 0);
    expect(b.opportunities, 0);
    expect(b.ignoredStreak, 0);
  });

  test('round-trips through json', () {
    final InitiativeBudget b = InitiativeBudget(
      day: DateTime(2026, 11, 24),
      sent: 2,
      opportunities: 5,
      ignoredStreak: 1,
    );
    final InitiativeBudget again = InitiativeBudget.fromJson(
      b.toJson(),
      DateTime(2026, 12, 1),
    );
    expect(again.day, b.day);
    expect(again.sent, 2);
    expect(again.opportunities, 5);
    expect(again.ignoredStreak, 1);
  });
}
