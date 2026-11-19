import 'package:feiyu/main.dart' show Message;
import 'package:feiyu/ui/bubble.dart';
import 'package:feiyu/ui/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required List<Message> messages,
  required bool busy,
  required bool waitingFirstToken,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MessageList(
        messages: messages,
        busy: busy,
        waitingFirstToken: waitingFirstToken,
        onOpenImage: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('newest bubble fades in and shows the streaming caret', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<Message> messages = <Message>[
      Message('user', '嗨'),
      Message('assistant', '你好呀'),
    ];

    await tester.pumpWidget(
      _host(messages: messages, busy: true, waitingFirstToken: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('streaming-caret')), findsOneWidget);

    final Finder fade = find
        .descendant(
          of: find.byKey(ValueKey<Message>(messages.last)),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(fade).opacity, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caret is hidden while waiting for the first token', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<Message> messages = <Message>[
      Message('user', '嗨'),
      Message('assistant', ''),
    ];

    await tester.pumpWidget(
      _host(messages: messages, busy: true, waitingFirstToken: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StreamingCaret), findsNothing);
    expect(find.byKey(const Key('streaming-caret')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
