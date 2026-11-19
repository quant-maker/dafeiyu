import 'package:flutter/material.dart';

import 'avatar_mark.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// The first-run / cleared-chat screen: a large drawn mark, a question, a hint
/// and a few tappable sample prompts.
///
/// Width is owned by the surrounding [ContentFrame], so this widget must not
/// add one of its own.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.samples,
    required this.onSample,
    this.buildTag,
  });

  /// Sample prompts rendered as tappable pills.
  final List<String> samples;

  /// Called with the tapped sample text.
  final ValueChanged<String> onSample;

  /// Optional build tag appended to the hint line.
  final String? buildTag;

  @override
  Widget build(BuildContext context) {
    final bool hasTag = buildTag != null && buildTag!.isNotEmpty;
    final String hint = hasTag
        ? '可以按麦克风说话，也可以发一张图给它看。  ·  $buildTag'
        : '可以按麦克风说话，也可以发一张图给它看。';
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AvatarMark(size: 96, glow: true),
            const SizedBox(height: 20),
            Text(
              '今天想聊点什么？',
              style: AppType.title.copyWith(color: AppPalette.text1),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppPalette.text3),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: samples
                  .map(
                    (String s) => Pill(label: s, onTap: () => onSample(s)),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
