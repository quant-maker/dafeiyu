import 'dart:convert';

import 'package:flutter/material.dart';

import '../main.dart' show Message;
import 'bubble.dart';
import 'tokens.dart';

/// Formats [at] as `HH:mm`, prefixed with `M月d日 ` when it is not today.
/// Hand-rolled to avoid a dependency on `intl`.
String _timeLabel(DateTime at) {
  final DateTime now = DateTime.now();
  final bool today =
      at.year == now.year && at.month == now.month && at.day == now.day;
  final String hh = at.hour.toString().padLeft(2, '0');
  final String mm = at.minute.toString().padLeft(2, '0');
  return today ? '$hh:$mm' : '${at.month}月${at.day}日 $hh:$mm';
}

/// Scrollable chat history rendered as a list of [MessageBubble]s.
///
/// The list owns no state: the owning page supplies the messages, streaming
/// flags and the image-open callback.
class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.busy,
    required this.waitingFirstToken,
    required this.onOpenImage,
    this.padding,
    this.controller,
  });

  final List<Message> messages;
  final bool busy;
  final bool waitingFirstToken;
  final void Function(String) onOpenImage;
  final EdgeInsets? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets effectivePadding =
        padding ??
        EdgeInsets.fromLTRB(
          0,
          MediaQuery.of(context).padding.top,
          0,
          20,
        );

    return ListView.builder(
      controller: controller,
      padding: effectivePadding,
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int i) {
        final Message m = messages[i];
        final bool mine = m.role == 'user';
        final bool typing =
            !mine && busy && waitingFirstToken && m.content.isEmpty;
        final bool showName =
            !mine && (i == 0 || messages[i - 1].role != 'assistant');
        final bool showTime =
            i == 0 ||
            m.at.difference(messages[i - 1].at).inMinutes >= 5;
        final double gap;
        if (i == 0) {
          gap = 0;
        } else if (messages[i - 1].role == m.role) {
          gap = 4;
        } else {
          gap = 14;
        }

        final String? b64 = m.imageBase64;
        final Widget? image = b64 == null
            ? null
            : GestureDetector(
                onTap: () => onOpenImage(b64),
                child: Image.memory(
                  base64Decode(b64),
                  width: mine ? 170 : 260,
                  fit: BoxFit.contain,
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showTime)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    _timeLabel(m.at),
                    key: ValueKey<String>('time-$i'),
                    style: AppType.caption.copyWith(color: AppPalette.text3),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: gap),
              child: MessageBubble(
                content: m.content,
                mine: mine,
                showName: showName,
                image: image,
                typing: typing,
              ),
            ),
          ],
        );
      },
    );
  }
}
