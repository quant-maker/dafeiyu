import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Shows [bytes] in a full-screen black image viewer.
///
/// The image can be pinched/zoomed via [InteractiveViewer], the close button
/// sits in the top-right corner (44x44 tap target), and tapping the barrier
/// dismisses the dialog. [extraActions] are rendered in a bottom bar, e.g. a
/// "保存" button supplied by the caller.
Future<void> showImageViewer(
  BuildContext context,
  Uint8List bytes, {
  List<Widget> extraActions = const <Widget>[],
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                semanticLabel: '图片',
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ),
          ),
          if (extraActions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: extraActions,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
