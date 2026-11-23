import 'package:feiyu/scene/scene_stage.dart';
import 'package:feiyu/ui/chat_app_bar.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({String status = '模型 · key✓ · host'}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      appBar: ChatAppBar(
        title: '大肥鱼',
        status: status,
        mood: SceneMood.idle,
        onFootprints: () {},
        onComfy: () {},
        onNewChat: () {},
        onSettings: () {},
      ),
      body: const SizedBox(),
    ),
  );
}

void main() {
  testWidgets('renders all four action tooltips and the avatar mark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness());

    expect(find.byTooltip('她的足迹'), findsOneWidget);
    expect(find.byTooltip('画画（ComfyUI）'), findsOneWidget);
    expect(find.byTooltip('新会话'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('🐟'), findsNothing);
  });

  testWidgets('content height is 68', (WidgetTester tester) async {
    expect(ChatAppBar.height, 68);
  });

  testWidgets('long status does not overflow at 390x844', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final String longStatus = 'x' * 120;
    await tester.pumpWidget(_harness(status: longStatus));

    expect(find.text(longStatus), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
