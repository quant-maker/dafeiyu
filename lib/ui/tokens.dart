import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Canonical color palette. Values are the single source of truth for both
/// static access (`AppPalette.primary`) and token access
/// (`AppTokens.standard().palette.primary`).
@immutable
final class AppPalette {
  const AppPalette({
    Color ink = AppPalette.ink,
    Color surface = AppPalette.surface,
    Color surfaceAlt = AppPalette.surfaceAlt,
    Color surfaceHi = AppPalette.surfaceHi,
    Color primary = AppPalette.primary,
    Color primaryDeep = AppPalette.primaryDeep,
    Color primaryInk = AppPalette.primaryInk,
    Color warm = AppPalette.warm,
    Color warmDeep = AppPalette.warmDeep,
    Color mint = AppPalette.mint,
    Color danger = AppPalette.danger,
    Color text1 = AppPalette.text1,
    Color text2 = AppPalette.text2,
    Color text3 = AppPalette.text3,
    Color text4 = AppPalette.text4,
    Color line = AppPalette.line,
    Color lineStrong = AppPalette.lineStrong,
    Color bubbleSurface = AppPalette.bubbleSurface,
    Color bubbleMine = AppPalette.bubbleMine,
    Color composerSurface = AppPalette.composerSurface,
  }) : _ink = ink,
       _surface = surface,
       _surfaceAlt = surfaceAlt,
       _surfaceHi = surfaceHi,
       _primary = primary,
       _primaryDeep = primaryDeep,
       _primaryInk = primaryInk,
       _warm = warm,
       _warmDeep = warmDeep,
       _mint = mint,
       _danger = danger,
       _text1 = text1,
       _text2 = text2,
       _text3 = text3,
       _text4 = text4,
       _line = line,
       _lineStrong = lineStrong,
       _bubbleSurface = bubbleSurface,
       _bubbleMine = bubbleMine,
       _composerSurface = composerSurface;

  static const Color ink = Color(0xFF060A13);
  static const Color surface = Color(0xFF0D1524);
  static const Color surfaceAlt = Color(0xFF131F33);
  static const Color surfaceHi = Color(0xFF1A2740);
  static const Color primary = Color(0xFF7CC4FF);
  static const Color primaryDeep = Color(0xFF2F6FD0);
  static const Color primaryInk = Color(0xFF04101F);
  static const Color warm = Color(0xFFFFB27A);
  static const Color warmDeep = Color(0xFFE07A4A);
  static const Color mint = Color(0xFF6BD08B);
  static const Color danger = Color(0xFFFF8A8A);
  static const Color text1 = Color(0xFFEEF4FF);
  static const Color text2 = Color(0x9EFFFFFF);
  static const Color text3 = Color(0x80FFFFFF);
  static const Color text4 = Color(0x42FFFFFF);
  static const Color line = Color(0x14FFFFFF);
  static const Color lineStrong = Color(0x24FFFFFF);
  static const Color bubbleSurface = Color(0xFF141F31);
  static const Color bubbleMine = Color(0xFF152A45);
  static const Color composerSurface = Color(0xE60B1424);

  final Color _ink;
  final Color _surface;
  final Color _surfaceAlt;
  final Color _surfaceHi;
  final Color _primary;
  final Color _primaryDeep;
  final Color _primaryInk;
  final Color _warm;
  final Color _warmDeep;
  final Color _mint;
  final Color _danger;
  final Color _text1;
  final Color _text2;
  final Color _text3;
  final Color _text4;
  final Color _line;
  final Color _lineStrong;
  final Color _bubbleSurface;
  final Color _bubbleMine;
  final Color _composerSurface;

  static AppPalette lerp(AppPalette a, AppPalette b, double t) {
    return AppPalette(
      ink: Color.lerp(a.ink, b.ink, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceAlt: Color.lerp(a.surfaceAlt, b.surfaceAlt, t)!,
      surfaceHi: Color.lerp(a.surfaceHi, b.surfaceHi, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      primaryDeep: Color.lerp(a.primaryDeep, b.primaryDeep, t)!,
      primaryInk: Color.lerp(a.primaryInk, b.primaryInk, t)!,
      warm: Color.lerp(a.warm, b.warm, t)!,
      warmDeep: Color.lerp(a.warmDeep, b.warmDeep, t)!,
      mint: Color.lerp(a.mint, b.mint, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      text1: Color.lerp(a.text1, b.text1, t)!,
      text2: Color.lerp(a.text2, b.text2, t)!,
      text3: Color.lerp(a.text3, b.text3, t)!,
      text4: Color.lerp(a.text4, b.text4, t)!,
      line: Color.lerp(a.line, b.line, t)!,
      lineStrong: Color.lerp(a.lineStrong, b.lineStrong, t)!,
      bubbleSurface: Color.lerp(a.bubbleSurface, b.bubbleSurface, t)!,
      bubbleMine: Color.lerp(a.bubbleMine, b.bubbleMine, t)!,
      composerSurface: Color.lerp(a.composerSurface, b.composerSurface, t)!,
    );
  }
}

extension AppPaletteInstance on AppPalette {
  Color get ink => _ink;
  Color get surface => _surface;
  Color get surfaceAlt => _surfaceAlt;
  Color get surfaceHi => _surfaceHi;
  Color get primary => _primary;
  Color get primaryDeep => _primaryDeep;
  Color get primaryInk => _primaryInk;
  Color get warm => _warm;
  Color get warmDeep => _warmDeep;
  Color get mint => _mint;
  Color get danger => _danger;
  Color get text1 => _text1;
  Color get text2 => _text2;
  Color get text3 => _text3;
  Color get text4 => _text4;
  Color get line => _line;
  Color get lineStrong => _lineStrong;
  Color get bubbleSurface => _bubbleSurface;
  Color get bubbleMine => _bubbleMine;
  Color get composerSurface => _composerSurface;
}

/// Typography scale. System font: `fontFamily` is intentionally unset.
abstract final class AppType {
  static const TextStyle display = TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15.5,
    height: 1.68,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.5,
    height: 1.6,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
  static const TextStyle mono = TextStyle(
    fontSize: 11.5,
    height: 1.6,
    fontFamily: 'monospace',
  );
}

@immutable
final class AppSpacing {
  const AppSpacing({
    double xs = AppSpacing.xs,
    double s = AppSpacing.s,
    double m = AppSpacing.m,
    double l = AppSpacing.l,
    double xl = AppSpacing.xl,
    double xxl = AppSpacing.xxl,
    double xxxl = AppSpacing.xxxl,
  }) : _xs = xs,
       _s = s,
       _m = m,
       _l = l,
       _xl = xl,
       _xxl = xxl,
       _xxxl = xxxl;

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  final double _xs;
  final double _s;
  final double _m;
  final double _l;
  final double _xl;
  final double _xxl;
  final double _xxxl;

  static AppSpacing lerp(AppSpacing a, AppSpacing b, double t) {
    return AppSpacing(
      xs: lerpDouble(a.xs, b.xs, t)!,
      s: lerpDouble(a.s, b.s, t)!,
      m: lerpDouble(a.m, b.m, t)!,
      l: lerpDouble(a.l, b.l, t)!,
      xl: lerpDouble(a.xl, b.xl, t)!,
      xxl: lerpDouble(a.xxl, b.xxl, t)!,
      xxxl: lerpDouble(a.xxxl, b.xxxl, t)!,
    );
  }
}

extension AppSpacingInstance on AppSpacing {
  double get xs => _xs;
  double get s => _s;
  double get m => _m;
  double get l => _l;
  double get xl => _xl;
  double get xxl => _xxl;
  double get xxxl => _xxxl;
}

@immutable
final class AppRadii {
  const AppRadii({
    double s = AppRadii.s,
    double m = AppRadii.m,
    double l = AppRadii.l,
    double xl = AppRadii.xl,
    double pill = AppRadii.pill,
    double full = AppRadii.full,
    double bubble = AppRadii.bubble,
    double bubbleImage = AppRadii.bubbleImage,
    double bubbleTail = AppRadii.bubbleTail,
  }) : _s = s,
       _m = m,
       _l = l,
       _xl = xl,
       _pill = pill,
       _full = full,
       _bubble = bubble,
       _bubbleImage = bubbleImage,
       _bubbleTail = bubbleTail;

  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double pill = 26;
  static const double full = 999;
  static const double bubble = 18;
  static const double bubbleImage = 14;
  static const double bubbleTail = 6;

  final double _s;
  final double _m;
  final double _l;
  final double _xl;
  final double _pill;
  final double _full;
  final double _bubble;
  final double _bubbleImage;
  final double _bubbleTail;

  static AppRadii lerp(AppRadii a, AppRadii b, double t) {
    return AppRadii(
      s: lerpDouble(a.s, b.s, t)!,
      m: lerpDouble(a.m, b.m, t)!,
      l: lerpDouble(a.l, b.l, t)!,
      xl: lerpDouble(a.xl, b.xl, t)!,
      pill: lerpDouble(a.pill, b.pill, t)!,
      full: lerpDouble(a.full, b.full, t)!,
      bubble: lerpDouble(a.bubble, b.bubble, t)!,
      bubbleImage: lerpDouble(a.bubbleImage, b.bubbleImage, t)!,
      bubbleTail: lerpDouble(a.bubbleTail, b.bubbleTail, t)!,
    );
  }
}

extension AppRadiiInstance on AppRadii {
  double get s => _s;
  double get m => _m;
  double get l => _l;
  double get xl => _xl;
  double get pill => _pill;
  double get full => _full;
  double get bubble => _bubble;
  double get bubbleImage => _bubbleImage;
  double get bubbleTail => _bubbleTail;
}

@immutable
final class AppGradients {
  const AppGradients({
    LinearGradient send = AppGradients.send,
    LinearGradient avatar = AppGradients.avatar,
    LinearGradient scrimTop = AppGradients.scrimTop,
    LinearGradient scrimBottom = AppGradients.scrimBottom,
  }) : _send = send,
       _avatar = avatar,
       _scrimTop = scrimTop,
       _scrimBottom = scrimBottom;

  static const LinearGradient send = LinearGradient(
    colors: [Color(0xFF5AB0FF), Color(0xFF2F6FD0)],
  );
  static const LinearGradient avatar = LinearGradient(
    colors: [Color(0xFF8FD0FF), Color(0xFF2F6FD0)],
  );
  static const LinearGradient scrimTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xB8060A13), Color(0x00060A13)],
  );
  static const LinearGradient scrimBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00060A13), Color(0xC7060A13)],
  );

  final LinearGradient _send;
  final LinearGradient _avatar;
  final LinearGradient _scrimTop;
  final LinearGradient _scrimBottom;

  static AppGradients lerp(AppGradients a, AppGradients b, double t) {
    return AppGradients(
      send: LinearGradient.lerp(a.send, b.send, t)!,
      avatar: LinearGradient.lerp(a.avatar, b.avatar, t)!,
      scrimTop: LinearGradient.lerp(a.scrimTop, b.scrimTop, t)!,
      scrimBottom: LinearGradient.lerp(a.scrimBottom, b.scrimBottom, t)!,
    );
  }
}

extension AppGradientsInstance on AppGradients {
  LinearGradient get send => _send;
  LinearGradient get avatar => _avatar;
  LinearGradient get scrimTop => _scrimTop;
  LinearGradient get scrimBottom => _scrimBottom;
}

@immutable
final class AppShadows {
  const AppShadows({
    List<BoxShadow> soft = AppShadows.soft,
    List<BoxShadow> glow = AppShadows.glow,
  }) : _soft = soft,
       _glow = glow;

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x47000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x3D7CC4FF), blurRadius: 16),
  ];

  final List<BoxShadow> _soft;
  final List<BoxShadow> _glow;

  static AppShadows lerp(AppShadows a, AppShadows b, double t) {
    return AppShadows(
      soft: BoxShadow.lerpList(a.soft, b.soft, t) ?? const [],
      glow: BoxShadow.lerpList(a.glow, b.glow, t) ?? const [],
    );
  }
}

extension AppShadowsInstance on AppShadows {
  List<BoxShadow> get soft => _soft;
  List<BoxShadow> get glow => _glow;
}

@immutable
final class AppDurations {
  const AppDurations({
    Duration fast = AppDurations.fast,
    Duration base = AppDurations.base,
    Duration entrance = AppDurations.entrance,
    Duration breathe = AppDurations.breathe,
  }) : _fast = fast,
       _base = base,
       _entrance = entrance,
       _breathe = breathe;

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration entrance = Duration(milliseconds: 200);
  static const Duration breathe = Duration(milliseconds: 1400);

  final Duration _fast;
  final Duration _base;
  final Duration _entrance;
  final Duration _breathe;

  static AppDurations lerp(AppDurations a, AppDurations b, double t) {
    return AppDurations(
      fast: Duration(
        milliseconds: lerpDouble(
          a.fast.inMilliseconds,
          b.fast.inMilliseconds,
          t,
        )!.round(),
      ),
      base: Duration(
        milliseconds: lerpDouble(
          a.base.inMilliseconds,
          b.base.inMilliseconds,
          t,
        )!.round(),
      ),
      entrance: Duration(
        milliseconds: lerpDouble(
          a.entrance.inMilliseconds,
          b.entrance.inMilliseconds,
          t,
        )!.round(),
      ),
      breathe: Duration(
        milliseconds: lerpDouble(
          a.breathe.inMilliseconds,
          b.breathe.inMilliseconds,
          t,
        )!.round(),
      ),
    );
  }
}

extension AppDurationsInstance on AppDurations {
  Duration get fast => _fast;
  Duration get base => _base;
  Duration get entrance => _entrance;
  Duration get breathe => _breathe;
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.palette,
    required this.spacing,
    required this.radii,
    required this.gradients,
    required this.shadows,
    required this.durations,
  });

  final AppPalette palette;
  final AppSpacing spacing;
  final AppRadii radii;
  final AppGradients gradients;
  final AppShadows shadows;
  final AppDurations durations;

  static const AppTokens _standard = AppTokens(
    palette: AppPalette(),
    spacing: AppSpacing(),
    radii: AppRadii(),
    gradients: AppGradients(),
    shadows: AppShadows(),
    durations: AppDurations(),
  );

  static AppTokens standard() => _standard;

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? _standard;

  @override
  AppTokens copyWith({
    AppPalette? palette,
    AppSpacing? spacing,
    AppRadii? radii,
    AppGradients? gradients,
    AppShadows? shadows,
    AppDurations? durations,
  }) {
    return AppTokens(
      palette: palette ?? this.palette,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      gradients: gradients ?? this.gradients,
      shadows: shadows ?? this.shadows,
      durations: durations ?? this.durations,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      palette: AppPalette.lerp(palette, other.palette, t),
      spacing: AppSpacing.lerp(spacing, other.spacing, t),
      radii: AppRadii.lerp(radii, other.radii, t),
      gradients: AppGradients.lerp(gradients, other.gradients, t),
      shadows: AppShadows.lerp(shadows, other.shadows, t),
      durations: AppDurations.lerp(durations, other.durations, t),
    );
  }
}
