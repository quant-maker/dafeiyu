import 'dart:convert';

import 'package:feiyu/main.dart' show Message;
import 'package:feiyu/scene/scene_stage.dart';
import 'package:feiyu/ui/bubble.dart';
import 'package:feiyu/ui/chat_app_bar.dart';
import 'package:feiyu/ui/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default top padding equals status bar plus app bar height', (
    WidgetTester tester,
  ) async {
    final List<Message> messages = <Message>[
      Message('assistant', '你好呀'),
      Message('user', '嗨'),
      Message('assistant', '在的'),
    ];
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
          ),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: ChatAppBar(
            title: '大肥鱼',
            status: 's',
            mood: SceneMood.idle,
            onFootprints: () {},
            onComfy: () {},
            onNewChat: () {},
            onSettings: () {},
          ),
          body: MessageList(
            messages: messages,
            busy: false,
            waitingFirstToken: false,
            onOpenImage: (_) {},
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final ListView list = tester.widget<ListView>(find.byType(ListView));
    final EdgeInsets padding = list.padding! as EdgeInsets;
    expect(padding.top, 92);
    expect(list.controller, controller);
    expect(controller.hasClients, isTrue);
    expect(find.byType(MessageBubble), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('message image re-decodes when its payload changes', (
    WidgetTester tester,
  ) async {
    const String redPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    const String bluePng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    final Message message = Message(
      'user',
      '图',
      imageBase64: redPng,
    );
    final List<Message> messages = <Message>[message];
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    Widget buildList() => MaterialApp(
      home: Scaffold(
        body: MessageList(
          messages: messages,
          busy: false,
          waitingFirstToken: false,
          onOpenImage: (_) {},
          controller: controller,
        ),
      ),
    );

    await tester.pumpWidget(buildList());
    await tester.pump(const Duration(milliseconds: 100));

    final MemoryImage red =
        tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(red.bytes, base64Decode(redPng));

    // Replace the payload in place; the list rebuilds with the same object.
    message.imageBase64 = bluePng;
    await tester.pumpWidget(buildList());
    await tester.pump(const Duration(milliseconds: 100));

    final MemoryImage blue =
        tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(blue.bytes, base64Decode(bluePng));
    expect(identical(red.bytes, blue.bytes), isFalse);
    expect(tester.takeException(), isNull);
  });
}
