import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'avatar_mark.dart';
import 'tokens.dart';

/// One conversation turn rendered as an opaque bubble.
///
/// Her messages sit on the left with the fish avatar and an optional name label;
/// the owner's messages sit on the right. Both surfaces are opaque so body text
/// keeps its contrast no matter what is behind the chat.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.content,
    required this.mine,
    this.showName = false,
    this.name,
    this.image,
    this.typing = false,
    this.trailing,
    this.maxWidth = 560,
    this.avatarBase64,
  });

  final String content;
  final bool mine;
  final bool showName;
  final String? name;
  final Widget? image;
  final bool typing;
  final Widget? trailing;
  final double maxWidth;
  final String? avatarBase64;

  Widget _bubble(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth * .80;
        final double limit = math.min(available, maxWidth);
        final Color border = mine
            ? AppPalette.primary.withValues(alpha: .28)
            : AppPalette.line;
        final BorderRadius radius = mine
            ? BorderRadius.only(
                topLeft: const Radius.circular(AppRadii.bubble),
                topRight: const Radius.circular(AppRadii.bubbleTail),
                bottomLeft: const Radius.circular(AppRadii.bubble),
                bottomRight: const Radius.circular(AppRadii.bubble),
              )
            : BorderRadius.only(
                topLeft: const Radius.circular(AppRadii.bubbleTail),
                topRight: const Radius.circular(AppRadii.bubble),
                bottomLeft: const Radius.circular(AppRadii.bubble),
                bottomRight: const Radius.circular(AppRadii.bubble),
              );

        return Container(
          constraints: BoxConstraints(maxWidth: limit),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: mine ? AppPalette.bubbleMine : AppPalette.bubbleSurface,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              if (image != null) ...<Widget>[
                Semantics(
                  label: '图片消息',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.bubbleImage),
                    child: image!,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (typing)
                const TypingDots()
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Flexible(
                      child: mine
                          ? SelectableText(
                              content,
                              textAlign: TextAlign.right,
                              style: AppType.bodySmall.copyWith(
                                color: AppPalette.text1,
                                fontSize: 15,
                              ),
                            )
                          : SelectableText(
                              content,
                              style: AppType.body.copyWith(
                                color: AppPalette.text1,
                              ),
                            ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[Flexible(child: _bubble(context))],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AvatarMark(size: 26, ring: false, imageBase64: avatarBase64),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    name ?? '大肥鱼',
                    style: AppType.label.copyWith(color: AppPalette.primary),
                  ),
                ),
              _bubble(context),
            ],
          ),
        ),
      ],
    );
  }
}

/// A thin blinking warm bar that follows the text while she is streaming.
class StreamingCaret extends StatefulWidget {
  const StreamingCaret({super.key});

  @override
  State<StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: .2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 3),
        child: Container(
          key: const Key('streaming-caret'),
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: AppPalette.warm,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

/// Three slowly pulsing dots that signal "she is typing".
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.count = 3,
    this.color = AppPalette.warm,
  });

  final int count;
  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.count, (int i) {
            final double phase = (t + i * .2) % 1.0;
            final double opacity =
                .25 + .75 * (phase < .5 ? phase * 2 : (1 - phase) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                  alpha: opacity.clamp(.25, 1.0),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
