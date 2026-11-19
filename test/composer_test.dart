import 'package:feiyu/ui/composer.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required TextEditingController controller,
  required bool busy,
  required bool listening,
  required VoidCallback onImage,
  required VoidCallback onMic,
  required VoidCallback onSend,
  required VoidCallback onStop,
}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Composer(
        controller: controller,
        busy: busy,
        listening: listening,
        onImage: onImage,
        onMic: onMic,
        onSend: onSend,
        onStop: onStop,
        onSubmitted: (_) {},
      ),
    ),
  );
}

IconButton _iconFor(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ),
  );
}

void main() {
  testWidgets('idle composer sends and keeps image/mic enabled', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    int sends = 0;

    await tester.pumpWidget(
      _host(
        controller: controller,
        busy: false,
        listening: false,
        onImage: () {},
        onMic: () {},
        onSend: () => sends++,
        onStop: () {},
      ),
    );

    expect(find.byTooltip('发送'), findsOneWidget);
    expect(_iconFor(tester, '发图片').onPressed, isNotNull);
    expect(_iconFor(tester, '说话').onPressed, isNotNull);

    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    expect(sends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy composer shows stop and disables image', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        busy: true,
        listening: false,
        onImage: () {},
        onMic: () {},
        onSend: () {},
        onStop: () {},
      ),
    );

    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(find.byTooltip('发送'), findsNothing);
    expect(_iconFor(tester, '发图片').onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
