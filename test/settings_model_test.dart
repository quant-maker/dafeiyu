import 'package:feiyu/main.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switching provider updates the base url field', (tester) async {
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

    // DeepSeek is the default provider; open its dropdown.
    await tester.tap(find.textContaining('DeepSeek'));
    await tester.pump(const Duration(milliseconds: 300));

    // Pick 通义千问, whose preset base url is the dashscope one.
    await tester.tap(find.textContaining('通义千问').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final String expected = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == expected,
      ),
      findsOneWidget,
      reason: 'base url field should follow the selected provider preset',
    );
  });
}
