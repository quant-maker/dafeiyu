import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'tokens.dart';

/// Chat input bar: a single frosted-glass layer holding the image, text,
/// microphone, and send/stop controls.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.busy,
    required this.listening,
    required this.onImage,
    required this.onMic,
    required this.onSend,
    required this.onStop,
    required this.onSubmitted,
    this.hint = '和大肥鱼说点什么…',
  });

  final TextEditingController controller;
  final bool busy;
  final bool listening;
  final VoidCallback onImage;
  final VoidCallback onMic;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.composerSurface,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: AppPalette.lineStrong.withValues(alpha: .10),
                ),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: <Widget>[
                  GhostIconButton(
                    icon: Icons.add_photo_alternate_outlined,
                    tooltip: '发图片',
                    onPressed: busy ? null : onImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: onSubmitted,
                      style: AppType.body.copyWith(
                        color: AppPalette.text1,
                        fontSize: 14.5,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: AppType.caption.copyWith(
                          color: AppPalette.text3,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  GhostIconButton(
                    icon: listening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none,
                    tooltip: listening ? '停止' : '说话',
                    color: listening ? AppPalette.primary : null,
                    onPressed: busy ? null : onMic,
                  ),
                  busy
                      ? GhostIconButton(
                          icon: Icons.stop_circle,
                          tooltip: '停止生成',
                          color: AppPalette.danger,
                          onPressed: onStop,
                        )
                      : _PressableSend(onSend: onSend),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 42px outlined send button with a subtle press-in feedback.
class _PressableSend extends StatefulWidget {
  const _PressableSend({required this.onSend});

  final VoidCallback onSend;

  @override
  State<_PressableSend> createState() => _PressableSendState();
}

class _PressableSendState extends State<_PressableSend> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onSend,
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 120),
        child: Tooltip(
          message: '发送',
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.ink,
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: .55),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.send_outlined,
              size: 19,
              color: AppPalette.primary,
            ),
          ),
        ),
      ),
    );
  }
}
