import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';

/// A themed avatar badge used throughout the app chrome.
///
/// With no [imageBase64] it renders the bundled vector badge
/// (`assets/avatar/default_avatar.svg`). With a user-supplied base64 image it
/// renders that image instead, always cropped to a circle.
class AvatarMark extends StatelessWidget {
  const AvatarMark({
    super.key,
    this.size = 34,
    this.ring = true,
    this.glow = false,
    this.imageBase64,
  });

  /// Edge length of the square mark in logical pixels.
  final double size;

  /// Whether to draw the 1px gold rim.
  final bool ring;

  /// Whether to wrap the mark in the soft primary glow.
  final bool glow;

  /// Optional base64-encoded user image (no `data:` prefix).
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    final Widget content = _AvatarImage(base64: imageBase64, size: size);

    final Widget framed = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.ink,
        border: ring
            ? Border.all(color: AppPalette.primary.withValues(alpha: .35))
            : null,
      ),
      child: ClipOval(child: content),
    );

    final Widget sized = SizedBox(
      width: size,
      height: size,
      child: glow
          ? DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow,
              ),
              child: framed,
            )
          : framed,
    );

    return Semantics(
      image: true,
      label: '大肥鱼',
      child: ExcludeSemantics(child: sized),
    );
  }
}

Widget _defaultSvg(double size) {
  return SvgPicture.asset(
    'assets/avatar/default_avatar.svg',
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
}

/// Decodes [base64] exactly once per payload, not on every rebuild.
class _AvatarImage extends StatefulWidget {
  const _AvatarImage({required this.base64, required this.size});

  final String? base64;
  final double size;

  @override
  State<_AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<_AvatarImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) {
      _decode();
    }
  }

  void _decode() {
    final String? raw = widget.base64;
    if (raw == null || raw.isEmpty) {
      _bytes = null;
      return;
    }
    try {
      _bytes = base64Decode(raw);
    } on FormatException {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    if (bytes == null) {
      return _defaultSvg(widget.size);
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _defaultSvg(widget.size),
    );
  }
}
