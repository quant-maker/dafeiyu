import 'package:feiyu/comfy/comfy_page.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drawing page must not dead-end on "go to Settings": it carries its own
/// shortcut (the header gear is always there, and the empty state has a button).
void main() {
  Future<void> pumpPage(WidgetTester tester, {required String workflow}) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ComfyPage(
          baseUrl: 'http://127.0.0.1:8188',
          workflowJson: workflow,
          onEditConfig: () async => null,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty workflow shows a direct settings shortcut', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, workflow: '');

    expect(find.text('还没有配置工作流'), findsOneWidget);
    expect(find.byKey(const ValueKey('comfy-open-settings')), findsOneWidget);
  });

  testWidgets('a configured workflow hides the setup card', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      workflow: '{"1":{"class_type":"KSampler","inputs":{"seed":1}}}',
    );

    expect(find.text('还没有配置工作流'), findsNothing);
    expect(find.byKey(const ValueKey('comfy-open-settings')), findsNothing);
  });
}
