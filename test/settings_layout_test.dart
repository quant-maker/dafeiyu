import 'package:feiyu/main.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The settings page used to be one endless column of bare text buttons.
/// These tests lock in the new rule: entries that fit share a row on wide
/// screens, and everything still stacks on a phone-sized surface.
void main() {
  Future<void> pumpSettings(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: Settings(baseUrl: '', apiKey: '', model: '', persona: ''),
          memory: null,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('memory entries share a row on a wide surface', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, const Size(1280, 8000));

    final Rect galaxy = tester.getRect(
      find.byKey(const ValueKey('settings-open-galaxy')),
    );
    final Rect health = tester.getRect(
      find.byKey(const ValueKey('settings-open-health')),
    );

    expect(galaxy.top, health.top);
    expect(galaxy.right, lessThan(health.left));
    expect(galaxy.width, moreOrLessEquals(health.width, epsilon: 1));
  });

  testWidgets('memory entries stack on a phone surface', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, const Size(390, 4000));

    final Rect galaxy = tester.getRect(
      find.byKey(const ValueKey('settings-open-galaxy')),
    );
    final Rect health = tester.getRect(
      find.byKey(const ValueKey('settings-open-health')),
    );

    expect(health.top, greaterThan(galaxy.bottom));
    expect(galaxy.left, health.left);
  });

  testWidgets('opening settings from the drawing page lands on ComfyUI', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: Settings(baseUrl: '', apiKey: '', model: '', persona: ''),
          memory: null,
          focusComfy: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder comfy = find.widgetWithText(SectionCard, 'ComfyUI');
    expect(comfy, findsOneWidget);
    // ComfyUI sits seven cards down the list; without the jump it would be
    // thousands of pixels below the fold.
    expect(tester.getTopLeft(comfy).dy, lessThan(300));
  });
}
