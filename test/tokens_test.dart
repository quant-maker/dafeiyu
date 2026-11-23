import 'package:feiyu/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard tokens expose canonical palette and bubble radius', () {
    expect(AppTokens.standard().palette.primary, AppPalette.primary);
    expect(AppTokens.standard().radii.bubble, 18);
  });

  test('lerp blends a changed palette color', () {
    final AppTokens a = AppTokens.standard();
    final AppTokens b = a.copyWith(
      palette: const AppPalette(primary: Color(0xFFFF0000)),
    );

    final Color mid = a.lerp(b, 0.5).palette.primary;

    expect(mid, isNot(a.palette.primary));
    expect(mid, isNot(b.palette.primary));
  });
}
