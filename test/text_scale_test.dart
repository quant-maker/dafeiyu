import 'package:feiyu/main.dart' show Message;
import 'package:feiyu/ui/composer.dart';
import 'package:feiyu/ui/message_list.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _smallScreen = Size(320, 640);

/// Hosts [child] under a 1.3x text scale on a 320x640 canvas.
Widget _scaled(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(
      textScaler: TextScaler.linear(1.3),
      size: _smallScreen,
    ),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('MessageList survives 1.3x text on a 320px screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<Message> messages = <Message>[
      Message('assistant', '今晚也在的，想聊点什么都可以。'),
      Message('user', '给我讲一个很长很长的故事，最好能一直讲下去。'),
      Message('assistant', '好呀，那我们慢慢说，从一条胖胖的小鲸鱼开始。'),
    ];

    await tester.pumpWidget(
      _scaled(
        MessageList(
          messages: messages,
          busy: false,
          waitingFirstToken: false,
          onOpenImage: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Composer survives 1.3x text on a 320px screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _scaled(
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

    expect(tester.takeException(), isNull);
  });

  testWidgets('SectionCard survives 1.3x text on a 320px screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _scaled(
        SectionCard(
          title: '说明',
          children: <Widget>[
            Text('很长的中文说明文字' * 6),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
