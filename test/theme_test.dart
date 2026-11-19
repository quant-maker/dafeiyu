import 'package:feiyu/ui/theme.dart';
import 'package:feiyu/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary colour comes from AppPalette', () {
    expect(AppTheme.dark().colorScheme.primary, AppPalette.primary);
  });

  test('AppTokens theme extension is registered', () {
    expect(AppTheme.dark().extension<AppTokens>(), isNotNull);
  });

  test('app bar background is transparent', () {
    expect(AppTheme.dark().appBarTheme.backgroundColor, Colors.transparent);
  });
}
