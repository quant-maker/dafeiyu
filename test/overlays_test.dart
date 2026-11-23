import 'dart:convert';
import 'dart:typed_data';

import 'package:feiyu/ui/overlays.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A real 1x1 transparent PNG.
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  testWidgets('showImageViewer opens a dialog with a 44px close button', (
    WidgetTester tester,
  ) async {
    final Uint8List bytes = base64Decode(_onePixelPng);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => showImageViewer(context, bytes),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);

    final Size closeSize = tester.getSize(find.byTooltip('关闭'));
    expect(closeSize.width, greaterThanOrEqualTo(44));
    expect(closeSize.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsNothing);
  });
}
