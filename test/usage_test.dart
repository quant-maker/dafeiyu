import 'package:flutter_test/flutter_test.dart';

import 'package:feiyu/companion/usage.dart';

void main() {
  group('UsageMeter', () {
    test('记账累加今天与累计', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: 120, output: 80);
      m.add(input: 30, output: 20);
      expect(m.inToday, 150);
      expect(m.outToday, 100);
      expect(m.todayTokens, 250);
      expect(m.totalTokens, 250);
      expect(m.requestsToday, 2);
      expect(m.requestsTotal, 2);
    });

    test('跨天只清今天，累计保留', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: 100, output: 50, at: DateTime(2026, 11, 27, 23, 50));
      m.add(input: 10, output: 5, at: DateTime(2026, 11, 28, 0, 10));
      expect(m.todayTokens, 15);
      expect(m.totalTokens, 165);
      expect(m.requestsToday, 1);
      expect(m.requestsTotal, 2);
    });

    test('负数和 0 不会被记成负数', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: -5, output: 0);
      expect(m.inToday, 0);
      expect(m.totalTokens, 0);
      expect(m.requestsToday, 1);
    });

    test('没测到任何东西时不瞎报', () {
      final m = UsageMeter();
      expect(m.promptLine, isEmpty);
      expect(m.settingsLine, contains('还没有记录'));
    });

    test('提示里带今天的数与累计数', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: 1200, output: 800);
      final line = m.promptLine;
      expect(line, contains('今天 1 次调用'));
      expect(line, contains('2000'));
      expect(line, contains('累计'));
      expect(line, contains('别自己编'));
    });

    test('万级数字压缩成 k，百万级压成 M', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: 12000, output: 3000);
      expect(m.settingsLine, contains('15k'));
      m.add(input: 2500000, output: 0);
      expect(m.settingsLine, contains('2.5M'));
    });

    test('JSON 往返与坏数据', () {
      final m = UsageMeter(day: DateTime(2026, 11, 27));
      m.add(input: 7, output: 3);
      final back = UsageMeter.fromJson(m.toJson());
      expect(back.totalTokens, 10);
      expect(back.requestsTotal, 1);

      final broken = UsageMeter.fromJson(<String, dynamic>{'inToday': 'oops'});
      expect(broken.totalTokens, 0);
      expect(UsageMeter.fromJson('nonsense').totalTokens, 0);
    });
  });
}
