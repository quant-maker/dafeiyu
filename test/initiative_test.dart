import 'dart:math';

import 'package:feiyu/companion/initiative.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('presenceDelayMinutes', () {
    test('stays in 25..70 minutes inclusive', () {
      final rng = Random(2026);
      for (var i = 0; i < 500; i++) {
        final m = presenceDelayMinutes(rng);
        expect(m, inInclusiveRange(25, 70));
      }
    });

    test('is deterministic for a seeded Random', () {
      final a = Random(42);
      final b = Random(42);
      for (var i = 0; i < 100; i++) {
        expect(presenceDelayMinutes(a), presenceDelayMinutes(b));
      }
    });
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

  group('followUpWorthTrying', () {
    final now = DateTime(2026, 11, 27, 16, 0);
    final armedAt = now.subtract(const Duration(minutes: 1));

    test('他刚说过话、还没到两分钟，可以补一句', () {
      expect(
        followUpWorthTrying(
          armedAt: armedAt,
          lastReplyAt: now.subtract(const Duration(minutes: 4)),
          unanswered: 1,
          now: now,
        ),
        isTrue,
      );
    });

    test('他已经回了就不插话', () {
      expect(
        followUpWorthTrying(
          armedAt: armedAt,
          lastReplyAt: now,
          unanswered: 0,
          now: now,
        ),
        isFalse,
      );
    });

    test('连着两句没人接就收着', () {
      expect(
        followUpWorthTrying(
          armedAt: armedAt,
          lastReplyAt: now.subtract(const Duration(minutes: 5)),
          unanswered: 2,
          now: now,
        ),
        isFalse,
      );
    });

    test('超过窗口就当聊天散了', () {
      expect(
        followUpWorthTrying(
          armedAt: armedAt,
          lastReplyAt: now.subtract(const Duration(minutes: 20)),
          unanswered: 0,
          now: now,
        ),
        isFalse,
      );
    });

    test('没有他说过话的记录就不追', () {
      expect(
        followUpWorthTrying(
          armedAt: armedAt,
          lastReplyAt: null,
          unanswered: 0,
          now: now,
        ),
        isFalse,
      );
    });
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
