# Task 2 — AppTheme + component themes (evidence)

Date: 2026-11-19
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Plan: `.omo/plans/companion-ui-redesign.md` (Todo 2)

## Toolchain

`flutter` is not on PATH; used `..\tools\flutter\bin\flutter.bat` (3.35.1, Dart 3.9.0).
Commands ran with `APPDATA`/`LOCALAPPDATA`/`HOME`/`TEMP` pointed at
`C:\Users\xqli\Documents\deepseek-harness\default-workspace\.tools-tmp\*`,
`PUB_CACHE` at `..\tools\pub-cache`, and `FLUTTER_SUPPRESS_ANALYTICS=true`.

## `flutter analyze` — raw last 25 lines

```
Analyzing dafeiyu...
No issues found! (ran in 10.2s)
ANALYZE_EXIT=0
```

## `flutter test` — raw last 25 lines

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/theme_test.dart
00:00 +0: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/theme_test.dart: primary colour comes from AppPalette
00:00 +1: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/theme_test.dart: AppTokens theme extension is registered
00:00 +2: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/theme_test.dart: app bar background is transparent
00:00 +3: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/tokens_test.dart: standard tokens expose canonical palette and bubble radius
00:00 +4: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/tokens_test.dart: lerp blends a changed palette color
00:00 +5: All tests passed!
TEST_EXIT=0
```

## `git diff --stat` — raw last 25 lines (tracked changes; new files are untracked at this point)

```
 .flutter-plugins-dependencies | 2 +-
 lib/main.dart                 | 8 ++------
 2 files changed, 3 insertions(+), 7 deletions(-)
```

Untracked new files added by this task (committed separately):

```
?? lib/ui/theme.dart
?? test/theme_test.dart
```

## Acceptance checks

- `AppTheme.dark()` appears exactly once in `lib/main.dart` (line 383); `ColorScheme.fromSeed` no longer appears there.
  - `383:theme: AppTheme.dark(),`
- Zero `Color(0x...)` literals in `lib/ui/theme.dart` (`Select-String ... -Pattern "Color\(0x"` count = 0).
- `ThemeData.dialogTheme` uses `DialogThemeData` (Flutter 3.35 type); `bottomSheetTheme`/`snackBarTheme`/`iconTheme`/`inputDecorationTheme` use their Flutter 3.35 data types.
- `theme: AppTheme.dark()` replaces the inline `ThemeData`; `title`, `debugShowCheckedModeBanner`, `home` unchanged.

## Three test assertions (`test/theme_test.dart`)

1. `AppTheme.dark().colorScheme.primary == AppPalette.primary`
2. `AppTheme.dark().extension<AppTokens>() != null`
3. `AppTheme.dark().appBarTheme.backgroundColor == Colors.transparent`

All three pass (see `flutter test` output above).
