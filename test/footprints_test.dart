import 'package:feiyu/feeds/footprints.dart';
import 'package:feiyu/feeds/footprints_page.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Footprint _fake(String id, String title, String mood) {
  final now = DateTime.now();
  return Footprint(
    id: id,
    at: DateTime(now.year, now.month, now.day, 10, 30),
    title: title,
    body: '$title 的正文内容，用来占位。',
    mood: mood,
  );
}

Widget _app(List<Footprint> items) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: FootprintsPage(
      items: items,
      onDistill: () async => null,
    ),
  );
}

void main() {
  testWidgets('renders every footprint title and its mood pill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(<Footprint>[
        _fake('1', '海边散步', '开心'),
        _fake('2', '一起看晚霞', '温柔'),
        _fake('3', '深夜聊天', '满足'),
      ]),
    );
    await tester.pump();

    expect(find.text('海边散步'), findsOneWidget);
    expect(find.text('一起看晚霞'), findsOneWidget);
    expect(find.text('深夜聊天'), findsOneWidget);
    expect(find.byType(Pill), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the empty state copy when there are no items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const <Footprint>[]));
    await tester.pump();

    expect(
      find.text('还没有足迹。\n多聊几轮，她会自己挑一些瞬间留在这里。'),
      findsOneWidget,
    );
    expect(find.byType(Pill), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('footprintFromShare keeps the source as title and a 160-char body', () {
    final at = DateTime(2026, 11, 23, 9, 5, 4);
    final long = 'A' * 200;
    final fp = footprintFromShare(source: 'HN', text: long, at: at);

    expect(fp.title, 'HN');
    expect(fp.mood, '🌐');
    expect(fp.at, at);
    expect(fp.id, at.microsecondsSinceEpoch.toString());
    expect(fp.body, hasLength(160));
    expect(fp.body, 'A' * 160);
  });

  test('footprintFromShare falls back to 网页 and trims the text', () {
    final fp = footprintFromShare(
      source: '   ',
      text: '  she shared this  ',
      at: DateTime(2026, 11, 23),
    );

    expect(fp.title, '网页');
    expect(fp.body, 'she shared this');
  });
}
