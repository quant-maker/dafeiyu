import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('danger notice dismisses on a 320 wide page', (
    WidgetTester tester,
  ) async {
    bool dismissed = false;
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: InlineNotice(
            tone: NoticeTone.danger,
            message: 'x',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('关闭'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();

    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
