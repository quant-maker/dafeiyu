import 'dart:math';

import 'package:feiyu/companion/initiative.dart';
import 'package:flutter_test/flutter_test.dart';

/// All cases are deterministic: each policy owns an independent Random(42).
InitiativePolicy _policy() => InitiativePolicy(rng: Random(42));

InitiativeDecision _next(
  DateTime now, {
  DateTime? lastInteractionAt,
  DateTime? lastProactiveAt,
  int ignoredStreak = 0,
  int sentToday = 0,
  int meanMinutes = 8,
  bool shareEnabled = true,
}) =>
    _policy().next(
      now: now,
      lastInteractionAt: lastInteractionAt,
      lastProactiveAt: lastProactiveAt,
      ignoredStreak: ignoredStreak,
      sentToday: sentToday,
      meanMinutes: meanMinutes,
      shareEnabled: shareEnabled,
    );

void main() {
  test('quiet hours silence until 07:30 plus up to 40m of jitter', () {
    final now = DateTime(2026, 11, 20, 3);
    final d = _next(now);
    expect(d.kind, InitiativeKind.silence);
    // 03:00 -> 07:30 is 270 minutes, jitter is 0..40.
    expect(d.delay, greaterThanOrEqualTo(const Duration(minutes: 270)));
    expect(d.delay, lessThanOrEqualTo(const Duration(minutes: 310)));
    expect(d.reason, isNotEmpty);
  });

  test('daily cap of three silences until tomorrow morning', () {
    final now = DateTime(2026, 11, 20, 10);
    final d = _next(now, sentToday: 3);
    expect(d.kind, InitiativeKind.silence);
    // 10:00 -> next 07:30 is 21h30m.
    expect(d.delay, const Duration(hours: 21, minutes: 30));
    expect(d.reason, contains('cap'));
  });

  test('three ignored nudges rest until tomorrow morning', () {
    final now = DateTime(2026, 11, 20, 10);
    final d = _next(now, ignoredStreak: 3);
    expect(d.kind, InitiativeKind.silence);
    expect(d.delay, const Duration(hours: 21, minutes: 30));
    expect(d.reason, contains('ignored'));
  });

  test('sampled delay stays inside 0.5..3 times the mean', () {
    const mean = 60;
    final policy = _policy();
    final now = DateTime(2026, 11, 20, 10);
    for (var i = 0; i < 50; i++) {
      final d = policy.next(
        now: now,
        lastInteractionAt: null,
        lastProactiveAt: null,
        ignoredStreak: 0,
        sentToday: 0,
        meanMinutes: mean,
        shareEnabled: false,
      );
      expect(d.delay, greaterThanOrEqualTo(const Duration(minutes: 30)));
      expect(d.delay, lessThanOrEqualTo(const Duration(minutes: 180)));
    }
  });

  test('never sooner than 40 minutes after the last proactive message', () {
    final now = DateTime(2026, 11, 20, 10);
    final policy = _policy();
    for (var i = 0; i < 50; i++) {
      final d = policy.next(
        now: now,
        lastInteractionAt: null,
        lastProactiveAt: now.subtract(const Duration(minutes: 10)),
        ignoredStreak: 0,
        sentToday: 0,
        meanMinutes: 8,
        shareEnabled: false,
      );
      expect(d.delay, greaterThanOrEqualTo(const Duration(minutes: 30)));
    }
  });

  test('share is chosen only when enabled and the roll is below 0.45', () {
    final now = DateTime(2026, 11, 20, 10);
    final policy = _policy();
    var shares = 0;
    for (var i = 0; i < 100; i++) {
      final d = policy.next(
        now: now,
        lastInteractionAt: null,
        lastProactiveAt: null,
        ignoredStreak: 0,
        sentToday: 0,
        meanMinutes: 60,
        shareEnabled: true,
      );
      if (d.kind == InitiativeKind.share) shares++;
    }
    expect(shares, greaterThan(0));
    expect(shares, lessThan(100));

    final talkOnly = _policy();
    for (var i = 0; i < 50; i++) {
      final d = talkOnly.next(
        now: now,
        lastInteractionAt: null,
        lastProactiveAt: null,
        ignoredStreak: 0,
        sentToday: 0,
        meanMinutes: 60,
        shareEnabled: false,
      );
      expect(d.kind, InitiativeKind.chat);
    }
  });

  test('default mean (8m) still waits at least 10 minutes', () {
    final policy = _policy();
    final now = DateTime(2026, 11, 20, 10);
    for (var i = 0; i < 50; i++) {
      final d = policy.next(
        now: now,
        lastInteractionAt: null,
        lastProactiveAt: null,
        ignoredStreak: 0,
        sentToday: 0,
        meanMinutes: 8,
        shareEnabled: false,
      );
      expect(d.kind, isNot(InitiativeKind.silence));
      expect(d.delay, greaterThanOrEqualTo(const Duration(minutes: 10)));
    }
  });

  test('ignored streaks stretch the same random sample', () {
    final now = DateTime(2026, 11, 20, 10);
    final calm = _next(now, meanMinutes: 60);
    final ignored = _next(now, meanMinutes: 60, ignoredStreak: 2);
    expect(ignored.delay, calm.delay * 3);
  });

  test('every decision carries a non-empty reason', () {
    final now = DateTime(2026, 11, 20, 10);
    final chat = _next(now, meanMinutes: 60);
    final share = _next(now, meanMinutes: 60);
    final quiet = _next(DateTime(2026, 11, 20, 2));
    for (final d in <InitiativeDecision>[chat, share, quiet]) {
      expect(d.reason.trim(), isNotEmpty);
    }
  });

  test('SILENCE marker and fresh-link checks', () {
    expect(isSilenceReply('SILENCE'), isTrue);
    expect(isSilenceReply(' [silence] '), isTrue);
    expect(isSilenceReply('SILENCE 今天没什么好说的'), isFalse);
    expect(hasFreshLink('看这个 https://a.com/x', <String>{}), isTrue);
    expect(hasFreshLink('看这个 https://a.com/x', {'https://a.com/x'}), isFalse);
    expect(hasFreshLink('没有链接', <String>{}), isFalse);
  });
}
