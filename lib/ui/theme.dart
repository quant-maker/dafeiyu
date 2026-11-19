import 'package:flutter/material.dart';

import 'tokens.dart';

/// The single app-wide [ThemeData] built entirely from design tokens.
///
/// Every colour, radius, spacing and type style comes from [AppTokens] /
/// [AppPalette] / [AppType] — no literal colour values live here.
abstract final class AppTheme {
  static ThemeData dark() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primaryDeep,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppPalette.primary,
      surface: AppPalette.surface,
      error: AppPalette.danger,
    );

    final TextTheme textTheme = const TextTheme(
      displayLarge: AppType.display,
      displayMedium: AppType.display,
      displaySmall: AppType.display,
      headlineLarge: AppType.title,
      headlineMedium: AppType.title,
      headlineSmall: AppType.title,
      titleLarge: AppType.title,
      titleMedium: AppType.title,
      titleSmall: AppType.subtitle,
      bodyLarge: AppType.body,
      bodyMedium: AppType.body,
      bodySmall: AppType.bodySmall,
      labelLarge: AppType.subtitle,
      labelMedium: AppType.caption,
      labelSmall: AppType.label,
    ).apply(
      bodyColor: AppPalette.text1,
      displayColor: AppPalette.text1,
    );

    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: AppPalette.line),
      borderRadius: BorderRadius.circular(AppRadii.l),
    );
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderSide: BorderSide(
        color: AppPalette.primary.withValues(alpha: .55),
      ),
      borderRadius: BorderRadius.circular(AppRadii.l),
    );
    final RoundedRectangleBorder pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.m),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.ink,
      extensions: <ThemeExtension<dynamic>>[AppTokens.standard()],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppType.title.copyWith(color: AppPalette.text1),
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppPalette.text2, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .05),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
        contentPadding: const EdgeInsets.all(14),
        hintStyle: AppType.bodySmall.copyWith(color: AppPalette.text3),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.primaryInk,
          textStyle: AppType.subtitle,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: pillShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.primary,
          textStyle: AppType.subtitle,
          minimumSize: const Size(0, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.text1,
          textStyle: AppType.subtitle,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: const BorderSide(color: AppPalette.lineStrong),
          shape: pillShape,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppPalette.primary
              : AppPalette.text3;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppPalette.primary.withValues(alpha: .28)
              : AppPalette.lineStrong;
        }),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 5,
        activeTrackColor: AppPalette.primary,
        inactiveTrackColor: AppPalette.lineStrong,
        thumbColor: AppPalette.primary,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.surfaceHi,
        contentTextStyle: AppType.bodySmall.copyWith(color: AppPalette.text1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.line,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: AppPalette.text1,
        iconColor: AppPalette.text2,
        subtitleTextStyle: AppType.bodySmall.copyWith(
          color: AppPalette.text2,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppType.bodySmall.copyWith(color: AppPalette.text1),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            AppPalette.surfaceHi,
          ),
          shape: WidgetStatePropertyAll(pillShape),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.primary,
        linearTrackColor: AppPalette.lineStrong,
        circularTrackColor: AppPalette.lineStrong,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppPalette.surfaceHi,
          borderRadius: BorderRadius.circular(AppRadii.s),
        ),
        textStyle: AppType.caption.copyWith(color: AppPalette.text1),
      ),
    );
  }
}
