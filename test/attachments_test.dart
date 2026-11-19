import 'dart:convert';
import 'dart:typed_data';

import 'package:feiyu/ui/attachments.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A real 1x1 transparent PNG.
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('PendingImageBar shows the image and removes on tap', (
    WidgetTester tester,
  ) async {
    _setPhoneViewport(tester);

    final Uint8List bytes = base64Decode(_onePixelPng);
    bool removed = false;

    await tester.pumpWidget(
      _host(
        PendingImageBar(bytes: bytes, onRemove: () => removed = true),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('图片已就绪'), findsOneWidget);
    expect(find.byTooltip('移除图片'), findsOneWidget);

    await tester.tap(find.byTooltip('移除图片'));
    await tester.pump();
    expect(removed, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ListeningBar keeps a long hint on a single line', (
    WidgetTester tester,
  ) async {
    _setPhoneViewport(tester);

    await tester.pumpWidget(
      _host(ListeningBar(hint: '正' * 120)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final Text text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ListeningBar),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
