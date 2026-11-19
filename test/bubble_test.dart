import 'package:feiyu/ui/avatar_mark.dart';
import 'package:feiyu/ui/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Finder _bubbleOf(String text) {
  return find
      .ancestor(
        of: find.text(text),
        matching: find.byType(Container),
      )
      .first;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('mine bubble sits on the right half', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(const MessageBubble(content: '我的消息', mine: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final double screenWidth = tester.view.physicalSize.width;
    expect(tester.getCenter(_bubbleOf('我的消息')).dx, greaterThan(screenWidth / 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('her bubble sits on the left with the avatar mark', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(const MessageBubble(content: '她的消息', mine: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AvatarMark), findsOneWidget);
    final double screenWidth = tester.view.physicalSize.width;
    expect(
      tester.getCenter(_bubbleOf('她的消息')).dx,
      lessThan(screenWidth / 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing shows dots and hides the content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(const MessageBubble(content: '你好', mine: false, typing: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TypingDots), findsOneWidget);
    expect(find.text('你好'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long Chinese message is capped near 80% of the width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final String longText = '这是一条很长的消息，' * 20;
    await tester.pumpWidget(
      _harness(MessageBubble(content: longText, mine: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final double width = tester.getSize(_bubbleOf(longText)).width;
    expect(width, lessThanOrEqualTo(390 * .80 + 40));
    expect(tester.takeException(), isNull);
  });
}
