import 'package:feiyu/ui/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('mine without an avatar shows the neutral owner placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(const MessageBubble(content: '我的消息', mine: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mine with a valid png avatar renders the image', (
    WidgetTester tester,
  ) async {
    const String png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    await tester.pumpWidget(
      _harness(
        const MessageBubble(
          content: '我的消息',
          mine: true,
          userAvatarBase64: png,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
