import 'package:flutter/material.dart';

import '../voice/call_flow.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// Slim pill shown above the composer while a hands-free call is active.
class CallBanner extends StatelessWidget {
  const CallBanner({super.key, required this.phase, this.message});

  final CallPhase phase;

  /// Overrides the default error copy (e.g. browser lacks speech support).
  final String? message;

  static String labelFor(CallPhase phase, {String? message}) {
    switch (phase) {
      case CallPhase.listening:
        return '听你说…';
      case CallPhase.thinking:
        return '她在想…';
      case CallPhase.speaking:
        return '她在说…';
      case CallPhase.error:
        return message?.isNotEmpty == true
            ? message!
            : '通话出错了，点挂断重来';
      case CallPhase.off:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (phase == CallPhase.off) return const SizedBox.shrink();
    final bool isError = phase == CallPhase.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            color: AppPalette.surfaceHi,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: isError
                  ? AppPalette.danger.withValues(alpha: .30)
                  : AppPalette.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatusDot(
                color: isError ? AppPalette.danger : AppPalette.primary,
                glow: !isError,
              ),
              const SizedBox(width: AppSpacing.s),
              Flexible(
                child: Text(
                  labelFor(phase, message: message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(
                    color: isError ? AppPalette.danger : AppPalette.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
