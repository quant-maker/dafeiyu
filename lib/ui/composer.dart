import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    this.focusNode,
    this.hint = '和大肥鱼说点什么…',
    this.inCall = false,
    this.onCall,
    this.onHangup,
  });

  final TextEditingController controller;

  /// Owned by the page so focus survives rebuilds (and can be handed back
  /// after a send — submitting a `send`-action TextField drops focus).
  final FocusNode? focusNode;
  final bool busy;
  final bool listening;
  final VoidCallback onImage;
  final VoidCallback onMic;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  /// True while the hands-free call loop is running.
  final bool inCall;
  final VoidCallback? onCall;
  final VoidCallback? onHangup;

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
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (String value) {
                        final bool keepFocus = focusNode?.hasFocus ?? false;
                        onSubmitted?.call(value);
                        // 回车发送后 Flutter 会把输入框的焦点收走，下一句就得
                        // 先点一下。发送前有焦点，就在这里还回去。
                        if (keepFocus && focusNode != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (focusNode!.context != null) {
                              focusNode!.requestFocus();
                            }
                          });
                        }
                      },
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
                  if (!inCall)
                    GhostIconButton(
                      icon: Icons.call_outlined,
                      tooltip: '打电话',
                      size: 36,
                      onPressed: busy ? null : onCall,
                    ),
                  GhostIconButton(
                    icon: listening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none,
                    tooltip: listening ? '停止' : '说话',
                    color: listening ? AppPalette.primary : null,
                    onPressed: busy ? null : onMic,
                  ),
                  if (inCall)
                    _HangupButton(onHangup: onHangup)
                  else if (busy)
                    GhostIconButton(
                      icon: Icons.stop_circle,
                      tooltip: '停止生成',
                      color: AppPalette.danger,
                      onPressed: onStop,
                    )
                  else
                    _PressableSend(onSend: onSend),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 42px red hang-up button shown while in a call.
class _HangupButton extends StatelessWidget {
  const _HangupButton({required this.onHangup});

  final VoidCallback? onHangup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        tooltip: '挂断',
        onPressed: onHangup,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          minimumSize: const Size(42, 42),
          backgroundColor: AppPalette.danger,
          hoverColor: AppPalette.danger.withValues(alpha: .88),
          highlightColor: AppPalette.danger.withValues(alpha: .78),
          shape: const CircleBorder(),
        ),
        icon: const Icon(
          Icons.call_end_rounded,
          size: 20,
          color: Colors.white,
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.ink,
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: .35),
                width: 1,
              ),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: SvgPicture.asset(
                'assets/icons/send.svg',
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  AppPalette.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
