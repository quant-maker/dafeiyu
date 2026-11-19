import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// A preview of the image queued for the next message, with a remove action.
///
/// Width is owned by the surrounding chat shell, so this widget must not add a
/// [ContentFrame] of its own.
class PendingImageBar extends StatelessWidget {
  const PendingImageBar({
    super.key,
    required this.bytes,
    required this.onRemove,
  });

  /// Raw bytes of the pending image.
  final Uint8List bytes;

  /// Called when the user taps the remove button.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(
            color: AppPalette.primary.withValues(alpha: .28),
          ),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.m),
              child: Image.memory(
                bytes,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                semanticLabel: '待发送图片',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '图片已就绪',
                style: AppType.caption.copyWith(color: AppPalette.text2),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: '移除图片',
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                color: AppPalette.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A live "listening" indicator: three phased bars next to a single-line hint.
///
/// The animation is owned internally so callers never have to thread an
/// [Animation] through. It must be driven with `pump(Duration(...))` in tests,
/// never `pumpAndSettle`, because it repeats forever.
class ListeningBar extends StatefulWidget {
  const ListeningBar({super.key, required this.hint});

  /// Text shown beside the bars (usually the current voice status).
  final String hint;

  @override
  State<ListeningBar> createState() => _ListeningBarState();
}

class _ListeningBarState extends State<ListeningBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double phase) {
    final double wave = (math.sin(phase) + 1) / 2;
    final double height = 6 + 8 * wave;
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double phase = _controller.value * 2 * math.pi;
          return Row(
            children: <Widget>[
              _bar(phase),
              const SizedBox(width: 2),
              _bar(phase + 0.9),
              const SizedBox(width: 2),
              _bar(phase + 1.8),
              const SizedBox(width: 8),
              Expanded(child: child!),
            ],
          );
        },
        child: Text(
          widget.hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(color: AppPalette.text3),
        ),
      ),
    );
  }
}
