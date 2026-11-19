import 'package:feiyu/ui/avatar_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder paintUnder(AvatarMark mark) => find.descendant(
        of: find.byWidget(mark),
        matching: find.byType(CustomPaint),
      );

  testWidgets('renders a square mark at the requested size', (tester) async {
    const AvatarMark mark = AvatarMark(size: 34);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: mark)),
      ),
    );

    final Finder paint = paintUnder(mark);
    expect(paint, findsOneWidget);
    expect(tester.getSize(paint), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scales to large sizes', (tester) async {
    const AvatarMark mark = AvatarMark(size: 96);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: mark)),
      ),
    );

    final Finder paint = paintUnder(mark);
    expect(paint, findsOneWidget);
    expect(tester.getSize(paint), const Size(96, 96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not render an emoji', (tester) async {
    const AvatarMark mark = AvatarMark(size: 34);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: mark)),
      ),
    );

    expect(find.text('🐟'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
