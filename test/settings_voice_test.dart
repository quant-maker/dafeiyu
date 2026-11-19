import 'package:feiyu/main.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tts controls appear only when enabled and engine is local', (tester) async {
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

    // TTS is off by default: no engine row.
    expect(find.text('发音引擎'), findsNothing);

    // First Switch on the page is the 语音朗读 toggle.
    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('发音引擎'), findsOneWidget);
    expect(find.text('音色'), findsNothing);

    // Switch the engine from system to local.
    await tester.tap(find.text('系统语音（免费、机械）'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('本机 Kokoro（自然、离线）').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('音色'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });
}
