import 'package:feiyu/ui/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _contentKey = ValueKey<String>('content');

Widget _app() {
  return const MaterialApp(
    home: Scaffold(
      body: ContentFrame(child: SizedBox.expand(key: _contentKey)),
    ),
  );
}

void main() {
  testWidgets('wide viewport keeps the framed block within 720 and centred', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());

    final Size content = tester.getSize(find.byKey(_contentKey));
    final Offset topLeft = tester.getTopLeft(find.byKey(_contentKey));

    expect(content.width, lessThanOrEqualTo(720));
    // 720 frame minus 16 padding on each side.
    expect(content.width, 688);
    // 280 side margin + 16 inner padding = 296 from the left edge.
    expect(topLeft.dx, 296);
    // Symmetric: the right outer margin equals the left outer margin.
    expect(1280 - topLeft.dx - content.width - 16, topLeft.dx - 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow viewport uses 16 side padding and no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());

    final Size content = tester.getSize(find.byKey(_contentKey));
    final Offset topLeft = tester.getTopLeft(find.byKey(_contentKey));

    expect(content.width, 328);
    expect(topLeft.dx, 16);
    expect(360 - topLeft.dx - content.width, 16);
    expect(find.byType(OverflowBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no OverflowBox is introduced and no render exception is thrown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());

    expect(find.byType(OverflowBox), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
