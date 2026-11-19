import 'package:flutter/material.dart';

import 'tokens.dart';

/// A themed fish mark that stands in for the old emoji avatar in app chrome.
///
/// The mark is drawn with a [CustomPaint] so it stays crisp and size-aware at
/// every place it appears (26 in bubbles, 34 in the app bar, 72/96 in the empty
/// state, 28 in the footprints card).
class AvatarMark extends StatelessWidget {
  const AvatarMark({
    super.key,
    this.size = 34,
    this.ring = true,
    this.glow = false,
  });

  /// Edge length of the square mark in logical pixels.
  final double size;

  /// Whether to draw the 1px rim and subtle inner backdrop.
  final bool ring;

  /// Whether to wrap the mark in the soft primary glow.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final Widget canvas = CustomPaint(
      size: Size.square(size),
      painter: _FishPainter(
        size: size,
        ring: ring,
        gradient: AppGradients.avatar,
        eye: AppPalette.primaryInk,
        rim: AppPalette.lineStrong,
        highlight: AppPalette.text1,
        backdrop: AppPalette.surfaceHi,
      ),
    );

    final Widget mark = glow
        ? DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.glow,
            ),
            child: canvas,
          )
        : canvas;

    return Semantics(
      image: true,
      label: '大肥鱼',
      child: ExcludeSemantics(child: mark),
    );
  }
}

class _FishPainter extends CustomPainter {
  _FishPainter({
    required this.size,
    required this.ring,
    required this.gradient,
    required this.eye,
    required this.rim,
    required this.highlight,
    required this.backdrop,
  });

  final double size;
  final bool ring;
  final LinearGradient gradient;
  final Color eye;
  final Color rim;
  final Color highlight;
  final Color backdrop;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double s = size;
    final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final double radius = s / 2;

    if (ring) {
      canvas.drawCircle(
        center,
        radius - 0.5,
        Paint()..color = backdrop.withValues(alpha: 0.55),
      );
    }

    final Paint bodyPaint = Paint()
      ..shader = gradient.createShader(Offset.zero & canvasSize);

    // Tail.
    final Path tail = Path()
      ..moveTo(s * 0.70, s * 0.52)
      ..lineTo(s * 0.90, s * 0.33)
      ..lineTo(s * 0.90, s * 0.71)
      ..close();
    canvas.drawPath(tail, bodyPaint);

    // Top fin.
    final Path fin = Path()
      ..moveTo(s * 0.38, s * 0.36)
      ..lineTo(s * 0.47, s * 0.20)
      ..lineTo(s * 0.56, s * 0.37)
      ..close();
    canvas.drawPath(fin, bodyPaint);

    // Body.
    final Rect bodyRect = Rect.fromCenter(
      center: Offset(s * 0.45, s * 0.52),
      width: s * 0.58,
      height: s * 0.40,
    );
    canvas.drawOval(bodyRect, bodyPaint);

    // Specular highlights.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.36, s * 0.42),
        width: s * 0.16,
        height: s * 0.09,
      ),
      Paint()..color = highlight.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.40, s * 0.58),
        width: s * 0.10,
        height: s * 0.06,
      ),
      Paint()..color = highlight.withValues(alpha: 0.45),
    );

    // Eye.
    canvas.drawCircle(
      Offset(s * 0.60, s * 0.45),
      s * 0.045,
      Paint()..color = eye,
    );

    if (ring) {
      canvas.drawCircle(
        center,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = rim,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FishPainter oldDelegate) {
    return oldDelegate.size != size ||
        oldDelegate.ring != ring ||
        oldDelegate.gradient != gradient ||
        oldDelegate.eye != eye ||
        oldDelegate.rim != rim ||
        oldDelegate.highlight != highlight ||
        oldDelegate.backdrop != backdrop;
  }
}
