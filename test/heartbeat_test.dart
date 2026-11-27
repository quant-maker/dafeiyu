import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:feiyu/companion/heartbeat.dart';

void main() {
  group('nextBeatDelay', () {
    test('白天 3..8 分钟', () {
      for (var seed = 0; seed < 200; seed++) {
        final d = nextBeatDelay(Random(seed));
        expect(d.inMinutes, inInclusiveRange(3, 8));
      }
    });

    test('抓取失败时退到 10..18 分钟', () {
      for (var seed = 0; seed < 200; seed++) {
        final d = nextBeatDelay(Random(seed), afterFailure: true);
        expect(d.inMinutes, inInclusiveRange(10, 18));
      }
    });
  });

  group('moodLine', () {
    final now = DateTime(2026, 11, 27, 15, 0);

    test('没人接的时候会自己收着', () {
      final line = moodLine(
        unanswered: 4,
        night: false,
        lastReplyAt: now.subtract(const Duration(hours: 2)),
        now: now,
      );
      expect(line, contains('讪讪'));
      expect(line, contains('收着'));
    });

    test('刚说完一句是在等，不是被无视', () {
      expect(
        moodLine(
          unanswered: 1,
          night: false,
          lastReplyAt: now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
        contains('等他回'),
      );
    });

    test('聊得顺的时候话更多', () {
      expect(
        moodLine(
          unanswered: 0,
          night: false,
          lastReplyAt: now.subtract(const Duration(seconds: 20)),
          now: now,
        ),
        contains('聊得正热'),
      );
    });

    test('安静久了会想他，夜里会困', () {
      expect(
        moodLine(
          unanswered: 0,
          night: false,
          lastReplyAt: now.subtract(const Duration(days: 2)),
          now: now,
        ),
        contains('很久没来'),
      );
      expect(
        moodLine(
          unanswered: 0,
          night: true,
          lastReplyAt: now.subtract(const Duration(hours: 15)),
          now: now,
        ),
        contains('困'),
      );
    });

    test('没有历史也不装熟', () {
      expect(
        moodLine(unanswered: 0, night: false, lastReplyAt: null, now: now),
        contains('不太知道'),
      );
    });
  });

  group('activityAt', () {
    test('同一刻永远说同一件事', () {
      final t = DateTime(2026, 11, 27, 15, 32);
      expect(activityAt(t), activityAt(t));
    });

    test('按钟点换场景', () {
      final morning = activityAt(DateTime(2026, 11, 27, 8, 0));
      final afternoon = activityAt(DateTime(2026, 11, 27, 16, 0));
      final night = activityAt(DateTime(2026, 11, 27, 23, 30));
      expect(morning, isNot(afternoon));
      expect(afternoon, isNot(night));
      expect(night, isNotEmpty);
    });

    test('同一刻钟里不会来回横跳', () {
      final a = activityAt(DateTime(2026, 11, 27, 9, 1));
      final b = activityAt(DateTime(2026, 11, 27, 9, 40));
      expect(a, b);
    });
  });

  group('HeartbeatState', () {
    test('夜里 22 点到次日 7 点', () {
      expect(HeartbeatState.isNight(DateTime(2026, 11, 27, 22)), isTrue);
      expect(HeartbeatState.isNight(DateTime(2026, 11, 27, 2)), isTrue);
      expect(HeartbeatState.isNight(DateTime(2026, 11, 27, 6, 59)), isTrue);
      expect(HeartbeatState.isNight(DateTime(2026, 11, 27, 7)), isFalse);
      expect(HeartbeatState.isNight(DateTime(2026, 11, 27, 21, 59)), isFalse);
    });

    test('心跳计数与跨天重置', () {
      final s = HeartbeatState(day: DateTime(2026, 11, 27));
      s.beat(DateTime(2026, 11, 27, 15, 0));
      s.beat(DateTime(2026, 11, 27, 15, 6));
      expect(s.beatsToday, 2);
      expect(s.lastBeatAt, DateTime(2026, 11, 27, 15, 6));

      s.sharesToday = 5;
      s.sharesTonight = 0;
      s.beat(DateTime(2026, 11, 28, 0, 10));
      expect(s.beatsToday, 1);
      expect(s.sharesToday, 0);
      expect(s.sharesTonight, 0);
      expect(s.day, DateTime(2026, 11, 28));
    });

    test('同一个名字见两次才算眼熟', () {
      final s = HeartbeatState();
      final t = DateTime(2026, 11, 27, 15);
      s.seeVoice('HN', 'pgs', t);
      expect(s.familiar, isEmpty);
      s.seeVoice('HN', 'pgs', t.add(const Duration(minutes: 5)));
      expect(s.familiar, hasLength(1));
      expect(s.familiar.single.name, 'pgs');
      expect(s.familiar.single.count, 2);
      // 不同来源是同名不同人，别混在一起。
      s.seeVoice('V2EX', 'pgs', t);
      expect(s.voices, hasLength(2));
    });

    test('名字表有上限，先丢最早见到的', () {
      final s = HeartbeatState();
      final base = DateTime(2026, 11, 27, 12);
      for (var i = 0; i <= HeartbeatState.maxVoices; i++) {
        s.seeVoice('HN', 'user$i', base.add(Duration(minutes: i)));
      }
      expect(s.voices.length, HeartbeatState.maxVoices);
      expect(s.voices.containsKey('HN:user0'), isFalse);
      expect(s.voices.containsKey('HN:user${HeartbeatState.maxVoices}'), isTrue);
    });

    test('JSON 往返保留状态', () {
      final s = HeartbeatState(day: DateTime(2026, 11, 27));
      final t = DateTime(2026, 11, 27, 15, 20);
      s.beat(t);
      s.lastShareAt = t;
      s.sharesToday = 2;
      s.sharesTonight = 1;
      s.lastNote = '在 HN 看到「A」';
      s.seeVoice('HN', 'pgs', t);
      s.seeVoice('HN', 'pgs', t);

      final back = HeartbeatState.fromJson(s.toJson());
      expect(back.lastBeatAt, t);
      expect(back.lastShareAt, t);
      expect(back.beatsToday, 1);
      expect(back.sharesToday, 2);
      expect(back.sharesTonight, 1);
      expect(back.lastNote, '在 HN 看到「A」');
      expect(back.familiar.single.name, 'pgs');
    });

    test('坏数据不会崩', () {
      final back = HeartbeatState.fromJson(<String, dynamic>{
        'beatsToday': 'x',
        'voices': <dynamic>['nope', 3, null],
      });
      expect(back.beatsToday, 0);
      expect(back.voices, isEmpty);
    });
  });
}
