import 'package:feiyu/ui/avatar_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid 1x1 transparent PNG, enough for [Image.memory] to decode.
const String _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Widget _host(Widget mark) {
  return MaterialApp(home: Scaffold(body: Center(child: mark)));
}

void main() {
  testWidgets('default renders the SVG badge at the requested size',
      (tester) async {
    await tester.pumpWidget(_host(const AvatarMark(size: 34)));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getSize(find.byType(AvatarMark)), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scales to 96', (tester) async {
    await tester.pumpWidget(_host(const AvatarMark(size: 96)));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getSize(find.byType(AvatarMark)), const Size(96, 96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom image replaces the badge', (tester) async {
    await tester.pumpWidget(
      _host(const AvatarMark(size: 34, imageBase64: _onePixelPngBase64)),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(AvatarMark)), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid base64 does not crash', (tester) async {
    await tester.pumpWidget(
      _host(const AvatarMark(size: 34, imageBase64: 'not-base64!!')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not render an emoji', (tester) async {
    await tester.pumpWidget(_host(const AvatarMark(size: 34)));

    expect(find.text('🐟'), findsNothing);
  });
}
