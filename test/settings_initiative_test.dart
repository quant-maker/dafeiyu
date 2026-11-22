import 'package:feiyu/main.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Settings minimal({String persona = 'p'}) => Settings(
        baseUrl: 'https://x/v1',
        apiKey: '',
        model: 'm',
        persona: persona,
      );

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('tapping 现在试一次 renders the returned status', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: minimal(),
          memory: Memory(),
          onTryInitiative: () async => '12:34 · 她决定先不说话（SILENT）',
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('现在试一次'));
    await tester.tap(find.text('现在试一次'));
    await tester.pump();
    await tester.pump();

    expect(find.text('12:34 · 她决定先不说话（SILENT）'), findsOneWidget);
  });

  testWidgets('恢复默认人设 puts kPresetPersona into the persona field', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: minimal(persona: '一个完全自定义的人设'),
          memory: Memory(),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('恢复默认人设'));
    await tester.tap(find.text('恢复默认人设'));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('settings-persona-field')),
    );
    expect(field.controller!.text, kPresetPersona);
  });
}
