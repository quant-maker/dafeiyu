import 'package:flutter/material.dart';

import 'tokens.dart';

/// The single cross-page layout primitive of the app.
///
/// Constrains its content to [maxWidth], keeps [padding] inside that width and
/// centres the framed block horizontally whenever the parent is wider than
/// [maxWidth]. On narrow screens it simply fills the available width minus
/// [padding].
///
/// Deliberately a [StatelessWidget] with no fixed heights and no clipping, so it
/// stays cheap and safe under a large `textScaler`.
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.l),
    required this.child,
  });

  /// Maximum width of the framed block, including [padding].
  final double maxWidth;

  /// Inner padding applied inside the framed block.
  final EdgeInsets padding;

  /// Content placed inside the frame.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        final double side = available.isFinite && available > maxWidth
            ? (available - maxWidth) / 2
            : 0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
