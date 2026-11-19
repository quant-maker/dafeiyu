import 'dart:math' as math;

import 'package:feiyu/ui/scrim.dart';
import 'package:feiyu/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(int c) {
  final s = c / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _lin((c.r * 255.0).round()) +
    0.7152 * _lin((c.g * 255.0).round()) +
    0.0722 * _lin((c.b * 255.0).round());

double contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg);
  final a = _lum(f), b = _lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group('WCAG contrast on opaque surfaces', () {
    test('text1 passes 7:1', () {
      expect(
        contrast(AppPalette.text1, AppPalette.bubbleSurface),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrast(AppPalette.text1, AppPalette.bubbleMine),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrast(AppPalette.text1, AppPalette.surfaceAlt),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrast(AppPalette.text1, AppPalette.ink),
        greaterThanOrEqualTo(7),
      );
    });

    test('text2 passes 4.5:1', () {
      expect(
        contrast(AppPalette.text2, AppPalette.surfaceAlt),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppPalette.text2, AppPalette.ink),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('text3 passes 4.5:1', () {
      expect(
        contrast(AppPalette.text3, AppPalette.ink),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppPalette.text3, AppPalette.surfaceAlt),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  testWidgets('ReadabilityScrim paints two fixed-alpha gradients', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReadabilityScrim())),
    );

    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>()
        .toList();

    expect(gradients, hasLength(2));

    final top = gradients[0].colors;
    final bottom = gradients[1].colors;

    expect((top.first.a * 255).round(), closeTo(0xB8, 1));
    expect((top.last.a * 255).round(), closeTo(0x00, 1));
    expect((bottom.first.a * 255).round(), closeTo(0x00, 1));
    expect((bottom.last.a * 255).round(), closeTo(0xC7, 1));
  });
}
