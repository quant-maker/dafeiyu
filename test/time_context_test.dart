import 'package:feiyu/time_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dayPart speaks the way people do', () {
    expect(dayPart(DateTime(2026, 11, 27, 3)), '深夜');
    expect(dayPart(DateTime(2026, 11, 27, 6)), '清晨');
    expect(dayPart(DateTime(2026, 11, 27, 9)), '上午');
    expect(dayPart(DateTime(2026, 11, 27, 12)), '中午');
    expect(dayPart(DateTime(2026, 11, 27, 15)), '下午');
    expect(dayPart(DateTime(2026, 11, 27, 20)), '晚上');
    expect(dayPart(DateTime(2026, 11, 27, 23)), '深夜');
  });

  test('humanGap keeps the largest sensible unit', () {
    expect(humanGap(const Duration(seconds: 20)), '刚刚');
    expect(humanGap(const Duration(minutes: 40)), '40 分钟前');
    expect(humanGap(const Duration(hours: 5)), '5 小时前');
    expect(humanGap(const Duration(days: 3, hours: 4)), '3 天前');
    expect(humanGap(const Duration(days: 75)), '2 个月前');
    expect(humanGap(const Duration(days: 800)), '2 年前');
  });

  test('relativeDay names the day instead of counting from now', () {
    final DateTime now = DateTime(2026, 11, 27, 10, 23);
    expect(relativeDay(DateTime(2026, 11, 27, 1), now), '今天');
    expect(relativeDay(DateTime(2026, 11, 26, 22), now), '昨天');
    expect(relativeDay(DateTime(2026, 11, 25, 22), now), '前天');
    expect(relativeDay(DateTime(2026, 11, 22, 22), now), '5 天前');
    expect(relativeDay(DateTime(2026, 9, 1), now), '2 个月前');
  });

  test('clockLine carries the weekday and the time of day', () {
    expect(clockLine(DateTime(2026, 11, 27, 10, 5)), '2026年11月27日 周五 10:05（上午）');
  });

  test('shortStamp pads the clock', () {
    expect(shortStamp(DateTime(2026, 11, 6, 9, 7)), '11月6日 09:07');
  });

  test('the prompt block matches the clock, the gap and the last turns', () {
    final DateTime now = DateTime(2026, 11, 27, 10, 23);
    final String block = timeContextLine(
      now: now,
      previous: DateTime(2026, 11, 26, 22, 3),
      recent: <RecentTurn>[
        RecentTurn(DateTime(2026, 11, 26, 22, 0), mine: false, text: '我先睡啦'),
        RecentTurn(DateTime(2026, 11, 26, 22, 3), mine: true, text: '晚安'),
        RecentTurn(now, mine: false, text: '早'),
      ],
    );
    expect(block, startsWith('现在是 2026年11月27日 周五 10:23（上午）。'));
    expect(block, contains('上次说话是昨天晚上（11月26日 22:03，12 小时前）。'));
    expect(block, contains('最近几条消息的时间：11月26日 22:00 对方：我先睡啦；'
        '11月26日 22:03 你：晚安；11月27日 10:23 对方：早。'));
    expect(block, contains('别在深夜说「早上好」'));
  });

  test('with no history the block only states the clock', () {
    final String block = timeContextLine(now: DateTime(2026, 11, 27, 10, 23));
    expect(block, startsWith('现在是 2026年11月27日 周五 10:23（上午）。'));
    expect(block, isNot(contains('上次说话')));
    expect(block, isNot(contains('最近几条消息')));
  });
}
