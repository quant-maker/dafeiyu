import 'package:feiyu/main.dart' show Message;
import 'package:feiyu/ui/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('time header shows at index 0 and after a 5 minute gap', (
    WidgetTester tester,
  ) async {
    final DateTime t0 = DateTime.now();
    final List<Message> messages = <Message>[
      Message('assistant', '第一条', at: t0),
      Message('assistant', '一分钟后', at: t0.add(const Duration(minutes: 1))),
      Message('user', '七分钟后', at: t0.add(const Duration(minutes: 7))),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: MessageList(
            messages: messages,
            busy: false,
            waitingFirstToken: false,
            onOpenImage: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final Finder headers = find.byWidgetPredicate(
      (Widget w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('time-'),
    );
    expect(headers, findsNWidgets(2));

    final List<Text> labels = tester.widgetList<Text>(headers).toList();
    expect(labels.length, 2);
    for (final Text label in labels) {
      expect(label.data, isNotNull);
      expect(label.data!.isNotEmpty, isTrue);
    }

    final Set<String> keys = labels
        .map((Text t) => (t.key! as ValueKey<String>).value)
        .toSet();
    expect(keys, <String>{'time-0', 'time-2'});

    expect(tester.takeException(), isNull);
  });
}
