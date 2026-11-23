import 'package:feiyu/main.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('comfy card shows connection button and workflow fields', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
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

    final comfyCard = find.byKey(const ValueKey('settings-section-comfy'));
    await tester.scrollUntilVisible(
      comfyCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(comfyCard, findsOneWidget);
    expect(
      find.descendant(of: comfyCard, matching: find.text('测试连接')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comfyCard,
        matching: find.text('文生图工作流（她调用 draw 时用）'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comfyCard,
        matching: find.text('去背景工作流（调用 remove_bg 时用）'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comfyCard,
        matching: find.text('图片编辑工作流（调用 edit_image 时用）'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comfyCard,
        matching: find.text('填入示例（SD-Turbo）'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comfyCard,
        matching: find.text('填入示例（SD-Turbo img2img）'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
