import 'package:feiyu/main.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings page renders eight stable section cards', (tester) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: Settings(
            baseUrl: 'https://x/v1',
            apiKey: '',
            model: 'm',
            persona: 'p',
          ),
          memory: Memory(),
        ),
      ),
    );

    // initState kicks off LocalTtsImpl.create(); in the test harness it can
    // throw a caught MissingPluginException. Give pending futures a beat but
    // avoid pumpAndSettle because animations may run indefinitely.
    await tester.pump(const Duration(milliseconds: 100));

    const keys = <String>[
      'settings-section-model',
      'settings-section-avatar',
      'settings-section-persona',
      'settings-section-voice',
      'settings-section-memory',
      'settings-section-scene',
      'settings-section-comfy',
      'settings-section-about',
    ];

    expect(find.byType(SectionCard), findsNWidgets(8));

    for (final key in keys) {
      expect(
        find.byKey(ValueKey(key)),
        findsOneWidget,
        reason: 'expected exactly one card with key $key',
      );
    }
  });
}
