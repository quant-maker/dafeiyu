import 'package:flutter/material.dart';

import 'tokens.dart';

/// Fixed-alpha readability layer painted above the scene photo and below the
/// scrimmable content.
///
/// It is purely decorative and never participates in hit testing, so the
/// reading surface keeps a predictable contrast without depending on the
/// photo behind it.
class ReadabilityScrim extends StatelessWidget {
  const ReadabilityScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppGradients.scrimTop.colors,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppGradients.scrimBottom.colors,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
