import 'package:feiyu/main.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scene dropdown and dim slider hide when disabled', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 100));

    final sceneCard = find.byKey(const ValueKey('settings-section-scene'));
    expect(sceneCard, findsOneWidget);
    expect(
      find.descendant(of: sceneCard, matching: find.byType(Slider)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: sceneCard, matching: find.byType(Switch)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: sceneCard,
        matching: find.byType(DropdownButtonFormField<String>),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: sceneCard, matching: find.byType(Slider)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
