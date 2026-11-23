import 'dart:convert';
import 'dart:typed_data';

import 'package:feiyu/scene/scene_stage.dart';
import 'package:feiyu/ui/bubble.dart';
import 'package:feiyu/ui/chat_app_bar.dart';
import 'package:feiyu/ui/composer.dart';
import 'package:feiyu/ui/empty_state.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid 1x1 transparent PNG, enough for [Image.memory] to decode.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

/// Every [IconButton] found must expose a non-empty tooltip.
void _expectEveryIconButtonHasTooltip(WidgetTester tester) {
  final Iterable<IconButton> buttons = tester.widgetList<IconButton>(
    find.byType(IconButton),
  );
  for (final IconButton button in buttons) {
    expect(button.tooltip, isNotNull);
    expect(
      button.tooltip!.isNotEmpty,
      isTrue,
      reason: 'IconButton ${button.icon} has an empty tooltip',
    );
  }
}

void main() {
  testWidgets('ChatAppBar icon buttons all carry tooltips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ChatAppBar(
          title: '大肥鱼',
          status: '在呢',
          mood: SceneMood.idle,
          onFootprints: () {},
          onComfy: () {},
          onNewChat: () {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IconButton), findsWidgets);
    _expectEveryIconButtonHasTooltip(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Composer icon buttons all carry tooltips', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        Composer(
          controller: controller,
          busy: false,
          listening: false,
          onImage: () {},
          onMic: () {},
          onSend: () {},
          onStop: () {},
          onSubmitted: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IconButton), findsWidgets);
    _expectEveryIconButtonHasTooltip(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState exposes no unlabelled icon buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EmptyState(
          samples: const <String>['你好', '陪我聊聊'],
          onSample: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final Iterable<IconButton> buttons = tester.widgetList<IconButton>(
      find.byType(IconButton),
    );
    for (final IconButton button in buttons) {
      expect(button.tooltip, isNotNull);
      expect(button.tooltip!.isNotEmpty, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('MessageBubble with an image carries image semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MessageBubble(
          content: '看这张图',
          mine: true,
          image: Image.memory(_onePixelPng, width: 80, height: 80),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    _expectEveryIconButtonHasTooltip(tester);
    // The bubble wraps its image in a labelled Semantics node.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == '图片消息',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectionCard exposes no unlabelled icon buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SectionCard(
          title: '说明',
          children: const <Widget>[Text('一段说明文字')],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final Iterable<IconButton> buttons = tester.widgetList<IconButton>(
      find.byType(IconButton),
    );
    for (final IconButton button in buttons) {
      expect(button.tooltip, isNotNull);
      expect(button.tooltip!.isNotEmpty, isTrue);
    }
    expect(tester.takeException(), isNull);
  });
}
