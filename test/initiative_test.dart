import 'package:feiyu/companion/initiative.dart';
import 'package:flutter_test/flutter_test.dart';

InitiativeOpportunity? _pick(
  DateTime now, {
  DateTime? lastInteractionAt,
  DateTime? lastProactiveAt,
  int sentToday = 0,
  int ignoredStreak = 0,
  bool hadAfterthoughtForLastTurn = true,
  bool dayAnchorDone = true,
  bool longSilenceDone = true,
}) =>
    pickOpportunity(
      now: now,
      lastInteractionAt: lastInteractionAt,
      lastProactiveAt: lastProactiveAt,
      sentToday: sentToday,
      ignoredStreak: ignoredStreak,
      hadAfterthoughtForLastTurn: hadAfterthoughtForLastTurn,
      dayAnchorDone: dayAnchorDone,
      longSilenceDone: longSilenceDone,
    );

void main() {
  group('quiet hours', () {
    test('inQuietHours covers 00:00–07:29', () {
      expect(inQuietHours(DateTime(2026, 11, 20, 0)), isTrue);
      expect(inQuietHours(DateTime(2026, 11, 20, 3, 15)), isTrue);
      expect(inQuietHours(DateTime(2026, 11, 20, 7, 29)), isTrue);
      expect(inQuietHours(DateTime(2026, 11, 20, 7, 30)), isFalse);
      expect(inQuietHours(DateTime(2026, 11, 20, 12)), isFalse);
    });

    test('no opportunity during quiet hours', () {
      final now = DateTime(2026, 11, 20, 3);
      expect(
        _pick(
          now,
          lastInteractionAt: now.subtract(const Duration(hours: 2)),
          lastProactiveAt: now.subtract(const Duration(hours: 12)),
          dayAnchorDone: false,
          hadAfterthoughtForLastTurn: false,
          longSilenceDone: false,
        ),
        isNull,
      );
    });
  });

  test('daily sent cap blocks every opportunity', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(
      _pick(
        now,
        lastInteractionAt: now.subtract(const Duration(hours: 2)),
        lastProactiveAt: now.subtract(const Duration(hours: 12)),
        sentToday: 3,
        dayAnchorDone: false,
        hadAfterthoughtForLastTurn: false,
        longSilenceDone: false,
      ),
      isNull,
    );
  });

  test('three ignored proactive nudges block everything', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(
      _pick(
        now,
        lastInteractionAt: now.subtract(const Duration(hours: 2)),
        ignoredStreak: 3,
        dayAnchorDone: false,
        hadAfterthoughtForLastTurn: false,
        longSilenceDone: false,
      ),
      isNull,
    );
  });

  group('reopen boundary', () {
    test('39 minutes away is not a reopen', () {
      final now = DateTime(2026, 11, 20, 12);
      final last = now.subtract(const Duration(minutes: 39));
      expect(
        _pick(
          now,
          lastInteractionAt: last,
          lastProactiveAt: now.subtract(const Duration(hours: 1)),
        )?.trigger,
        isNot(InitiativeTrigger.reopen),
      );
    });

    test('40 minutes away is a reopen', () {
      final now = DateTime(2026, 11, 20, 12);
      final last = now.subtract(const Duration(minutes: 40));
      final o = _pick(
        now,
        lastInteractionAt: last,
        lastProactiveAt: now.subtract(const Duration(hours: 1)),
      );
      expect(o?.trigger, InitiativeTrigger.reopen);
      expect(o?.reason.trim(), isNotEmpty);
    });

    test('longer away is still a reopen', () {
      final now = DateTime(2026, 11, 20, 12);
      final last = now.subtract(const Duration(hours: 3));
      expect(
        _pick(
          now,
          lastInteractionAt: last,
          lastProactiveAt: now.subtract(const Duration(minutes: 5)),
        )?.trigger,
        InitiativeTrigger.reopen,
      );
    });
  });

  test('longSilence after six hours without a proactive message', () {
    final now = DateTime(2026, 11, 20, 12);
    final o = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 5)),
      lastProactiveAt: now.subtract(const Duration(hours: 6)),
      dayAnchorDone: false,
      longSilenceDone: false,
    );
    expect(o?.trigger, InitiativeTrigger.longSilence);
    expect(o?.reason.trim(), isNotEmpty);
  });

  test('longSilence fires at most once per day', () {
    final now = DateTime(2026, 11, 20, 12);
    final o = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 5)),
      lastProactiveAt: now.subtract(const Duration(hours: 7)),
      longSilenceDone: true,
    );
    expect(o, isNull);
  });

  test('dayAnchor on the first activity of the day', () {
    final now = DateTime(2026, 11, 20, 9);
    final o = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 1)),
      lastProactiveAt: now.subtract(const Duration(minutes: 30)),
      dayAnchorDone: false,
    );
    expect(o?.trigger, InitiativeTrigger.dayAnchor);
    expect(o?.reason.trim(), isNotEmpty);
  });

  test('dayAnchor fires at most once per day', () {
    final now = DateTime(2026, 11, 20, 9);
    final o = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 1)),
      lastProactiveAt: now.subtract(const Duration(minutes: 30)),
      dayAnchorDone: true,
    );
    expect(o, isNull);
  });

  test('afterthought is offered at most once per assistant turn', () {
    final now = DateTime(2026, 11, 20, 9);
    final offered = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 1)),
      lastProactiveAt: now.subtract(const Duration(minutes: 30)),
      hadAfterthoughtForLastTurn: false,
    );
    expect(offered?.trigger, InitiativeTrigger.afterthought);

    final used = _pick(
      now,
      lastInteractionAt: now.subtract(const Duration(minutes: 1)),
      lastProactiveAt: now.subtract(const Duration(minutes: 30)),
      hadAfterthoughtForLastTurn: true,
    );
    expect(used, isNull);
  });

  group('promiseLike', () {
    test('detects future-tense promises', () {
      for (final phrase in <String>[
        '我下午要开会',
        '晚点聊',
        '等下回来找你',
        '待会再说',
        '回头说',
        '明天见',
        '我先去睡觉了',
        '先忙一会',
        '出门一趟',
        '上班呢',
        '下班再说',
        '吃饭去了再聊',
      ]) {
        expect(promiseLike(phrase), isTrue, reason: phrase);
      }
    });

    test('does not flag ordinary chatter', () {
      for (final phrase in <String>[
        '今天天气不错',
        '你好呀',
        '我正在看你发的图',
        '这个颜色好看吗',
        '我有点累了',
        '哈哈哈',
      ]) {
        expect(promiseLike(phrase), isFalse, reason: phrase);
      }
    });
  });

  test('nothing applies -> null', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(
      _pick(
        now,
        lastInteractionAt: now.subtract(const Duration(minutes: 2)),
        lastProactiveAt: now.subtract(const Duration(minutes: 30)),
      ),
      isNull,
    );
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
