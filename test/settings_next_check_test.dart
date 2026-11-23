import 'package:feiyu/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsPage renders the provided next-check label',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          initial: Settings(
            baseUrl: 'http://x/v1',
            apiKey: '',
            model: 'm',
            persona: 'p',
          ),
          memory: Memory(),
          initialNextCheck: '下次检查：约 21:40（presence）',
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-next-check')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('下次检查：约 21:40（presence）'), findsOneWidget);
  });

  testWidgets('SettingsPage falls back to 未安排 when no check is armed',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          initial: Settings(
            baseUrl: 'http://x/v1',
            apiKey: '',
            model: 'm',
            persona: 'p',
          ),
          memory: Memory(),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-next-check')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('下次检查：未安排'), findsOneWidget);
  });
}
